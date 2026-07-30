import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/pv_template_config.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../state/chantier_state.dart';

/// L'installateur ne crée ni ne modifie jamais le contenu du PV : il consulte
/// (lecture seule) le PDF déposé par le back-office, fait signer le client
/// directement sur l'écran, et renseigne son nom/sa fonction. La signature
/// tactile est ensuite fusionnée dans le PDF, à l'emplacement fixe du gabarit
/// (voir PvTemplateConfig) — c'est cette soumission qui valide le PV.
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

  PdfController? _pdfController;
  Uint8List? _pdfBytes;
  bool _isLoadingPdf = true;
  String? _loadError;
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
    _pdfController?.dispose();
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
      _pdfController = PdfController(document: PdfDocument.openData(_pdfBytes!));
    } catch (_) {
      _loadError = 'Impossible de charger le PV déposé par le back-office.';
    } finally {
      if (mounted) setState(() => _isLoadingPdf = false);
    }
  }

  bool get _peutValider =>
      !_isSubmitting && _points.isNotEmpty && _nomController.text.trim().isNotEmpty && _fonctionController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier;

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
            child: PdfView(controller: _pdfController!, scrollDirection: Axis.vertical),
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
                const Text('Signature du client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: RepaintBoundary(
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
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _points.isEmpty ? null : () => setState(() => _points.clear()),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Effacer'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: _peutValider ? () => _valider(chantier) : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Valider le procès-verbal'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
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

  Future<void> _valider(Chantier chantier) async {
    setState(() => _isSubmitting = true);
    try {
      final signatureBytes = await _capturerSignature();
      if (signatureBytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de capturer la signature, réessayez.')),
        );
        return;
      }

      final pdfSigneBytes = await _fusionnerSignatureDansPdf(signatureBytes);
      final dataUrl = 'data:application/pdf;base64,${base64Encode(pdfSigneBytes)}';

      if (!mounted) return;
      await context.read<ChantierState>().signPv(
            chantier.reference,
            nomSignataire: _nomController.text.trim(),
            fonctionSignataire: _fonctionController.text.trim(),
            file: dataUrl,
          );
      if (!mounted) return;
      context.go('/confirmation');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Capture le tracé de signature en PNG (bytes bruts, pas encore encodé)
  /// pour l'insérer dans le PDF final.
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

  /// Reconstruit le PDF page par page : chaque page du gabarit est rendue en
  /// image puis réinsérée en fond de page (le package `pdf` ne sait
  /// qu'écrire des PDF, pas éditer un PDF existant), et l'image de la
  /// signature est superposée aux coordonnées fixes du gabarit (voir
  /// PvTemplateConfig) sur la page désignée.
  Future<Uint8List> _fusionnerSignatureDansPdf(Uint8List signatureBytes) async {
    final sourceDoc = await PdfDocument.openData(_pdfBytes!);
    final targetPageNumber = PvTemplateConfig.signaturePageNumber ?? sourceDoc.pagesCount;
    final signatureImage = pw.MemoryImage(signatureBytes);

    final outDoc = pw.Document();
    for (var pageNumber = 1; pageNumber <= sourceDoc.pagesCount; pageNumber++) {
      final page = await sourceDoc.getPage(pageNumber);
      final rendered = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      final pageWidth = page.width;
      final pageHeight = page.height;
      await page.close();
      if (rendered == null) continue;

      final pageBackground = pw.MemoryImage(rendered.bytes);
      final pageFormat = PdfPageFormat(pageWidth, pageHeight, marginAll: 0);

      outDoc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pdfContext) => pw.Stack(
            children: [
              pw.Positioned.fill(child: pw.Image(pageBackground, fit: pw.BoxFit.fill)),
              if (pageNumber == targetPageNumber)
                pw.Positioned(
                  left: PvTemplateConfig.signatureX,
                  top: pageHeight - PvTemplateConfig.signatureY - PvTemplateConfig.signatureHeight,
                  child: pw.SizedBox(
                    width: PvTemplateConfig.signatureWidth,
                    height: PvTemplateConfig.signatureHeight,
                    child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    await sourceDoc.close();
    return outDoc.save();
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
