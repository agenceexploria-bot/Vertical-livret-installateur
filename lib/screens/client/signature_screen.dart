import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
/// (lecture seule) le PDF déposé par le back-office, fait signer le client
/// directement sur l'écran, et renseigne son nom/sa fonction. La signature
/// tactile est capturée puis figée (l'installateur ne peut plus la modifier,
/// seuls nom/fonction restent éditables jusqu'à l'envoi), et envoyée seule au
/// backend qui la superpose sur le PDF gabarit original sans le rasteriser
/// (voir backend/src/lib/pvMerge.ts). Une fois le PV signé (pvSigne == true),
/// cet écran se verrouille totalement — voir le garde dans [build] — et ne
/// se déverrouille que si un CA/Admin supprime le PV depuis le back-office
/// (DELETE .../pv, qui repasse pvSigne à false).
class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final List<Offset?> _points = [];
  final _nomController = TextEditingController();
  final _fonctionController = TextEditingController();
  final _signatureKey = GlobalKey();

  Uint8List? _pdfBytes;
  bool _isLoadingPdf = true;
  String? _loadError;

  /// Image de la signature tactile une fois capturée — non nulle = la
  /// signature est figée (lecture seule), distincte du texte du signataire
  /// (nom/fonction) qui reste éditable jusqu'à l'envoi final.
  Uint8List? _signatureBytes;
  bool _isCapturingSignature = false;
  bool _isSubmitting = false;

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

  bool get _peutValiderSignature => _points.isNotEmpty && !_isCapturingSignature;

  bool get _peutValider =>
      !_isSubmitting && _signatureBytes != null && _nomController.text.trim().isNotEmpty && _fonctionController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier;

    // Verrou : un PV déjà signé ne se rouvre jamais en mode édition, même en
    // cas de navigation directe vers cette route (deep link, retour
    // arrière...) — la seule porte de sortie est qu'un CA/Admin supprime le
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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('PV à faire signer par le client (lecture seule)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(border: Border.all(color: AppColors.lignes), borderRadius: BorderRadius.circular(9)),
            clipBehavior: Clip.antiAlias,
            child: PdfViewer.data(_pdfBytes!, sourceName: 'pv-${chantier.reference}'),
          ),
        ),
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
                Text(
                  _signatureBytes == null ? 'Signature du client' : 'Signature du client (verrouillée)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SizedBox(height: 180, child: _buildSignatureZone()),
                const SizedBox(height: 8),
                _buildActionsRow(chantier),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Zone de signature : canevas tactile tant que rien n'est figé, sinon
  /// aperçu en lecture seule de l'image déjà capturée (voir [_validerSignature]).
  Widget _buildSignatureZone() {
    final signatureBytes = _signatureBytes;
    if (signatureBytes != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.fond,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.lignes),
        ),
        child: Image.memory(signatureBytes, fit: BoxFit.contain),
      );
    }
    return RepaintBoundary(
      key: _signatureKey,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.fond,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.lignes),
        ),
        child: GestureDetector(
          onPanUpdate: _handlePanUpdate,
          onPanEnd: (details) => setState(() => _points.add(null)),
          child: CustomPaint(painter: _SignaturePainter(points: _points)),
        ),
      ),
    );
  }

  /// Tant que la signature n'est pas figée : "Effacer" le tracé / "Valider la
  /// signature" (la capture et la verrouille). Une fois figée : "Refaire la
  /// signature" (déverrouille et efface) / "Valider le procès-verbal" (envoi
  /// final, utilise la signature figée + le nom/fonction courants).
  Widget _buildActionsRow(Chantier chantier) {
    if (_signatureBytes == null) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: _points.isEmpty ? null : () => setState(() => _points.clear()),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Effacer'),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _peutValiderSignature ? _validerSignature : null,
            child: _isCapturingSignature
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Valider la signature'),
          ),
        ],
      );
    }
    return Row(
      children: [
        TextButton.icon(
          onPressed: _isSubmitting ? null : _refaireSignature,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refaire la signature'),
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

  /// Coordonnées locales à la zone de dessin (RepaintBoundary [_signatureKey]),
  /// pas au contexte de l'écran entier — sans ça, globalToLocal calcule par
  /// rapport à la mauvaise origine et le tracé se décale par rapport au
  /// doigt. Les points hors du carré de signature sont ignorés (le tracé
  /// s'arrête net au bord) ; un point null "lève le stylo" pour ne pas relier
  /// le dernier point valide à celui où le doigt revient dans le cadre.
  void _handlePanUpdate(DragUpdateDetails details) {
    final renderBox = _signatureKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final local = renderBox.globalToLocal(details.globalPosition);
    final inBounds = (Offset.zero & renderBox.size).contains(local);

    setState(() {
      if (inBounds) {
        _points.add(local);
      } else if (_points.isNotEmpty && _points.last != null) {
        _points.add(null);
      }
    });
  }

  /// Capture le tracé et le fige : la zone de dessin devient un aperçu en
  /// lecture seule (voir [_buildSignatureZone]), seuls nom/fonction restent
  /// modifiables jusqu'à l'envoi final.
  Future<void> _validerSignature() async {
    setState(() => _isCapturingSignature = true);
    try {
      final bytes = await _capturerSignature();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de capturer la signature, réessayez.')),
        );
        return;
      }
      setState(() => _signatureBytes = bytes);
    } finally {
      if (mounted) setState(() => _isCapturingSignature = false);
    }
  }

  void _refaireSignature() {
    setState(() {
      _signatureBytes = null;
      _points.clear();
    });
  }

  /// Envoie la signature déjà figée (image PNG seule, jamais fusionnée
  /// localement — voir backend/src/lib/pvMerge.ts pour la fusion réelle avec
  /// le gabarit). Le bloc catch générique (en plus de celui dédié à
  /// [ApiException]) est essentiel : tout échec réseau non typé ne doit
  /// jamais remonter jusqu'à faire planter l'écran, seulement afficher un
  /// message et laisser l'installateur réessayer.
  Future<void> _valider(Chantier chantier) async {
    final signatureBytes = _signatureBytes;
    if (signatureBytes == null) return;

    setState(() => _isSubmitting = true);
    try {
      final dataUrl = 'data:image/png;base64,${base64Encode(signatureBytes)}';

      if (!mounted) return;
      await context.read<ChantierState>().signPv(
            chantier.reference,
            nomSignataire: _nomController.text.trim(),
            fonctionSignataire: _fonctionController.text.trim(),
            signatureImage: dataUrl,
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

  /// Capture le tracé de signature en PNG (bytes bruts, pas encore encodé)
  /// pour l'envoi au backend, qui le superpose sur le PDF gabarit.
  Future<Uint8List?> _capturerSignature() async {
    try {
      final boundary = _signatureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.encre
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
