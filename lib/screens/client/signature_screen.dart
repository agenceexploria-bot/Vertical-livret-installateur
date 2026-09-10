import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/document_download.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../state/chantier_state.dart';

/// L'installateur ne crée ni ne modifie jamais le contenu du PV : il consulte
/// le PDF déposé par le back-office et fait signer le client DIRECTEMENT sur
/// le rendu du document (calque de dessin transparent superposé au
/// visualiseur PDF, voir [_buildPdfAvecCalque]), à l'endroit exact prévu
/// pour la signature — il n'y a plus de zone de signature séparée. Le tracé
/// est capturé en coordonnées "document" (indépendantes du zoom/scroll, voir
/// [PdfViewerController.globalToDocument]), ce qui permet de calculer sa
/// position PDF exacte (page, x, y, largeur, hauteur en points) au moment de
/// l'envoi — voir [_calculerPlacementSignature]. Le backend superpose alors
/// l'image sur le PDF gabarit original sans le rasteriser (voir
/// backend/src/lib/pvMerge.ts). Une fois le PV signé (pvSigne == true), cet
/// écran se verrouille totalement — voir le garde dans [build] — et ne se
/// déverrouille que si un CT/Admin supprime le PV depuis le back-office
/// (DELETE .../pv, qui repasse pvSigne à false).
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  /// Tracé du client en coordonnées "document" du PDF (indépendantes du
  /// zoom/scroll courants) — un point `null` "lève le stylo" entre deux
  /// traits. C'est la seule source de vérité du tracé : l'affichage à
  /// l'écran (voir [_PdfSignatureOverlay]) et le placement final envoyé au
  /// backend en sont tous deux dérivés, jamais l'inverse.
  final List<Offset?> _pointsDocument = [];
  final _nomController = TextEditingController();
  final _fonctionController = TextEditingController();
  final _overlayKey = GlobalKey();
  final _pdfController = PdfViewerController();

  /// Mode Lecture (le doigt fait défiler/zoome le PDF) / Mode Signature (le
  /// doigt dessine sur le calque) — évite que le client dessine par
  /// accident en essayant de scroller jusqu'à sa case. Désactive aussi le
  /// pan/zoom du visualiseur pendant la signature (voir [_buildPdfAvecCalque]).
  bool _modeSignature = false;

  Uint8List? _pdfBytes;
  bool _isLoadingPdf = true;
  String? _loadError;
  bool _isSubmitting = false;

  static const double _epaisseurTraitPdf = 1.6; // en points PDF
  static const double _margeSignaturePdf = 4.0; // marge autour du tracé, en points PDF
  static const double _resolutionRasterisation = 4.0; // pixels PNG par point PDF

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerPdf());
    _nomController.addListener(() => setState(() {}));
    _fonctionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nomController.dispose();
    _fonctionController.dispose();
    super.dispose();
  }

  Future<void> _chargerPdf() async {
    final pdfPath = context.read<ChantierState>().currentChantier?.pvPdfPath;
    if (pdfPath == null) {
      setState(() => _isLoadingPdf = false);
      return;
    }
    try {
      final response = await http.get(Uri.parse(pdfPath));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      _pdfBytes = response.bodyBytes;
    } catch (_) {
      _loadError = 'Impossible de charger le PV déposé par le back-office.';
    } finally {
      if (mounted) setState(() => _isLoadingPdf = false);
    }
  }

  bool get _peutValider =>
      !_isSubmitting &&
      _pointsDocument.any((p) => p != null) &&
      _nomController.text.trim().isNotEmpty &&
      _fonctionController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier;

    // Verrou : un PV déjà signé ne se rouvre jamais en mode édition, même en
    // cas de navigation directe vers cette route (deep link, retour
    // arrière...) — la seule porte de sortie est qu'un CT/Admin supprime le
    // PV côté back-office, ce qui repasse pvSigne à false et débloque cet
    // écran automatiquement (rebuild réactif via context.watch).
    if (chantier != null && chantier.pvSigne) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/confirmation');
      });
      return const ResponsiveLayout(child: Center(child: CircularProgressIndicator()));
    }

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Signature du procès-verbal'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: chantier == null
          ? const Center(child: Text('Chantier introuvable'))
          : chantier.pvPdfPath == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Le back-office n\'a pas encore déposé le PV pour ce chantier.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.acier),
                    ),
                  ),
                )
              : _isLoadingPdf
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? Center(child: Text(_loadError!, style: const TextStyle(color: AppColors.rouge)))
                      : _buildContent(context, chantier),
    );
  }

  Widget _buildContent(BuildContext context, Chantier chantier) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Faites signer le client directement sur le document, à l\'endroit prévu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              _buildToggleMode(),
            ],
          ),
        ),
        Expanded(flex: 4, child: _buildPdfAvecCalque(chantier)),
        const Divider(height: 24),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nomController,
                  decoration: const InputDecoration(labelText: 'Nom du signataire'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fonctionController,
                  decoration: const InputDecoration(labelText: 'Fonction du signataire'),
                ),
                const SizedBox(height: 16),
                _buildActionsRow(chantier),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleMode() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, icon: Icon(Icons.pan_tool_outlined, size: 18), label: Text('Lecture')),
        ButtonSegment(value: true, icon: Icon(Icons.draw_outlined, size: 18), label: Text('Signature')),
      ],
      selected: {_modeSignature},
      onSelectionChanged: (selection) => setState(() => _modeSignature = selection.first),
    );
  }

  /// PDF en lecture seule (défilable/zoomable en Mode Lecture) avec, par
  /// dessus, un calque transparent qui capte le tracé de signature en Mode
  /// Signature seulement — voir [_modeSignature]. Le pan/zoom du visualiseur
  /// est désactivé pendant la signature ([PdfViewerParams.panEnabled]/
  /// [scaleEnabled]) pour qu'aucun geste ne soit ambigu entre défilement et
  /// dessin, en plus du calque qui absorbe déjà tous les gestes en mode
  /// signature.
  Widget _buildPdfAvecCalque(Chantier chantier) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(border: Border.all(color: AppColors.lignes), borderRadius: BorderRadius.circular(9)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PdfViewer.data(
            _pdfBytes!,
            sourceName: 'pv-${chantier.reference}',
            controller: _pdfController,
            params: PdfViewerParams(panEnabled: !_modeSignature, scaleEnabled: !_modeSignature),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_modeSignature,
              child: GestureDetector(
                key: _overlayKey,
                behavior: HitTestBehavior.opaque,
                onPanUpdate: _handlePanUpdate,
                onPanEnd: (_) => setState(() => _pointsDocument.add(null)),
                // Isole le calque de dessin dans sa propre couche de
                // composition : sans ça, chaque repaint du tracé (à chaque
                // mouvement du doigt) forcerait aussi le visualiseur PDF
                // sous-jacent à se re-rasteriser, coûteux sur un PDF haute
                // résolution.
                child: RepaintBoundary(
                  child: ListenableBuilder(
                    listenable: _pdfController,
                    builder: (context, _) => CustomPaint(painter: _SignaturePainter(points: _pointsEnEcran(), strokeWidth: _epaisseurEcran())),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(Chantier chantier) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: _isSubmitting || _pointsDocument.isEmpty ? null : () => setState(_pointsDocument.clear),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Effacer la signature'),
        ),
        const Spacer(),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _peutValider ? () => _valider(chantier) : null,
          child: _isSubmitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Valider le procès-verbal'),
        ),
      ],
    );
  }

  /// Coordonnées locales au calque ([_overlayKey]), pas au contexte de
  /// l'écran entier — sans ça, globalToLocal calcule par rapport à la
  /// mauvaise origine et le tracé se décale par rapport au doigt. Converti
  /// immédiatement en coordonnées "document" (via [PdfViewerController]),
  /// indépendantes du zoom/scroll courants, pour que le tracé reste
  /// visuellement attaché au document même si le client scrolle/zoome entre
  /// deux traits (voir [_pointsEnEcran], reconverti à chaque frame). Les
  /// points hors du calque sont ignorés (le tracé s'arrête net au bord) ; un
  /// point null "lève le stylo" pour ne pas relier le dernier point valide à
  /// celui où le doigt revient dans le cadre.
  void _handlePanUpdate(DragUpdateDetails details) {
    final renderBox = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final local = renderBox.globalToLocal(details.globalPosition);
    final inBounds = (Offset.zero & renderBox.size).contains(local);

    if (!inBounds) {
      if (_pointsDocument.isNotEmpty && _pointsDocument.last != null) {
        setState(() => _pointsDocument.add(null));
      }
      return;
    }
    final doc = _pdfController.globalToDocument(details.globalPosition);
    if (doc == null) return;
    setState(() => _pointsDocument.add(doc));
  }

  /// Reconvertit le tracé (stocké en coordonnées document) vers l'écran pour
  /// l'affichage courant — appelé à chaque frame ([ListenableBuilder] écoute
  /// [_pdfController]) pour que le tracé suive le PDF pendant un défilement
  /// ou un zoom en Mode Lecture. Avant que le visualiseur soit prêt (premier
  /// frame), renvoie une liste vide plutôt que de planter.
  List<Offset?> _pointsEnEcran() {
    final renderBox = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !_pdfController.isReady) return const [];
    return _pointsDocument.map((p) {
      if (p == null) return null;
      final global = _pdfController.documentToGlobal(p);
      if (global == null) return null;
      return renderBox.globalToLocal(global);
    }).toList(growable: false);
  }

  double _epaisseurEcran() => _epaisseurTraitPdf * (_pdfController.isReady ? _pdfController.currentZoom : 1.0);

  /// Calcule la page et les coordonnées PDF (points, origine BAS-GAUCHE —
  /// convention pdf-lib, voir backend/src/lib/pvMerge.ts) du tracé de
  /// signature, à partir de sa position en coordonnées "document" du
  /// visualiseur. Retourne `null` si le tracé est vide ou si le visualiseur
  /// n'a pas encore de mise en page (ne devrait pas arriver : le tracé
  /// suppose que l'utilisateur a déjà dessiné sur un PDF chargé).
  ({int pageNumber, double x, double y, double width, double height, Rect bboxDocument})? _calculerPlacementSignature() {
    if (!_pdfController.isReady) return null;

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in _pointsDocument) {
      if (p == null) continue;
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    if (minX == double.infinity) return null;
    final bbox = Rect.fromLTRB(minX, minY, maxX, maxY).inflate(_margeSignaturePdf);

    final pageLayouts = _pdfController.layout.pageLayouts;
    if (pageLayouts.isEmpty) return null;
    final center = bbox.center;
    var pageIndex = pageLayouts.indexWhere((r) => r.contains(center));
    if (pageIndex == -1) {
      // Le tracé déborde légèrement dans la marge entre deux pages : on
      // rattache à la page la plus proche verticalement plutôt que
      // d'échouer.
      var meilleureDistance = double.infinity;
      for (var i = 0; i < pageLayouts.length; i++) {
        final distance = (pageLayouts[i].center.dy - center.dy).abs();
        if (distance < meilleureDistance) {
          meilleureDistance = distance;
          pageIndex = i;
        }
      }
    }

    final pageRect = pageLayouts[pageIndex];
    return (
      pageNumber: pageIndex + 1,
      x: bbox.left - pageRect.left,
      y: pageRect.bottom - bbox.bottom,
      width: bbox.width,
      height: bbox.height,
      bboxDocument: bbox,
    );
  }

  /// Rasterise le tracé (coordonnées document) en PNG cadré sur [bboxDocument]
  /// seul — indépendant du zoom d'écran courant, pour une netteté constante
  /// quel que soit le niveau de zoom utilisé au moment de la validation.
  Future<Uint8List?> _rasteriserSignature(Rect bboxDocument) async {
    final width = (bboxDocument.width * _resolutionRasterisation).ceil();
    final height = (bboxDocument.height * _resolutionRasterisation).ceil();
    if (width <= 0 || height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_resolutionRasterisation);
    canvas.translate(-bboxDocument.left, -bboxDocument.top);
    _SignaturePainter(points: _pointsDocument, strokeWidth: _epaisseurTraitPdf).paint(canvas, bboxDocument.size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  /// Calcule le placement, rasterise le tracé puis envoie tout au backend
  /// (qui superpose la signature sur le PDF gabarit, voir pvMerge.ts). Le
  /// try-catch couvre aussi bien un échec de calcul de position (PDF pas
  /// encore prêt, tracé hors page...) qu'un échec réseau : dans tous les cas
  /// l'écran ne doit jamais planter, seulement afficher un message et
  /// laisser l'installateur réessayer.
  Future<void> _valider(Chantier chantier) async {
    if (!_peutValider) return;
    setState(() => _isSubmitting = true);
    try {
      final placement = _calculerPlacementSignature();
      if (placement == null) {
        throw Exception('Impossible de déterminer la position de la signature sur le document.');
      }
      final signatureBytes = await _rasteriserSignature(placement.bboxDocument);
      if (signatureBytes == null) {
        throw Exception('Impossible de générer l\'image de la signature.');
      }
      final dataUrl = 'data:image/png;base64,${base64Encode(signatureBytes)}';

      if (!mounted) return;
      await context.read<ChantierState>().signPv(
            chantier.reference,
            nomSignataire: _nomController.text.trim(),
            fonctionSignataire: _fonctionController.text.trim(),
            signatureImage: dataUrl,
            pageNumber: placement.pageNumber,
            x: placement.x,
            y: placement.y,
            width: placement.width,
            height: placement.height,
          );

      if (!mounted) return;
      await _afficherSucces();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, st) {
      debugPrint('SignatureScreen._valider: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une erreur est survenue lors de la validation du PV. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Dialogue de succès, avec accès immédiat au PDF final (fusionné côté
  /// serveur, déjà disponible via l'URL renvoyée dans le chantier mis à jour)
  /// avant de rejoindre l'écran de confirmation.
  Future<void> _afficherSucces() async {
    if (!mounted) return;
    final pdfUrl = context.read<ChantierState>().currentChantier?.pvSignatureImagePath;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.vert, size: 40),
        title: const Text('PV validé avec succès'),
        content: const Text('Le procès-verbal signé a bien été envoyé.'),
        actions: [
          if (pdfUrl != null)
            TextButton.icon(
              onPressed: () => _telechargerPdfSigne(pdfUrl),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Télécharger le PDF'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.go('/confirmation');
  }

  Future<void> _telechargerPdfSigne(String pdfUrl) async {
    try {
      final ok = await launchUrl(forceDownloadUri(pdfUrl), mode: LaunchMode.externalApplication);
      if (ok || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de télécharger le PDF.')),
      );
    } catch (e, st) {
      debugPrint('SignatureScreen._telechargerPdfSigne: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de télécharger le PDF.')),
      );
    }
  }
}

// TODO(2026-08-31) : duplique lib/core/widgets/signature_pad.dart's
// _SignaturePadPainter (même logique de tracé point-à-point) — à factoriser
// en un seul CustomPainter partagé au prochain tour de nettoyage.
class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final double strokeWidth;
  _SignaturePainter({required this.points, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.encre
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
