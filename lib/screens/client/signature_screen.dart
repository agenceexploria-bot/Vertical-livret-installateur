import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/document_capture.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/api_client.dart';
import '../../state/chantier_state.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final List<Offset?> _points = [];
  final _nameController = TextEditingController();
  final _signatureKey = GlobalKey();
  String? _signedPdfDataUrl;
  String? _signedPdfName;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Signature du procès-verbal'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Récapitulatif de conformité', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('L\'installation est déclarée conforme et prête à l\'usage.', style: TextStyle(fontSize: 13, color: AppColors.acier)),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom et fonction du signataire',
              ),
            ),
            const SizedBox(height: 24),
            if (_signedPdfDataUrl == null) ...[
              const Text('Signature au doigt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Expanded(
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
                      onPanUpdate: (details) {
                        setState(() {
                          RenderBox renderBox = context.findRenderObject() as RenderBox;
                          _points.add(renderBox.globalToLocal(details.globalPosition));
                        });
                      },
                      onPanEnd: (details) => _points.add(null),
                      child: CustomPaint(
                        painter: _SignaturePainter(points: _points),
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.fond,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.lignes),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, color: AppColors.encre),
                      const SizedBox(width: 8),
                      Expanded(child: Text('PV signé importé : $_signedPdfName', style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_signedPdfDataUrl == null)
                  TextButton.icon(
                    onPressed: () => setState(() => _points.clear()),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Effacer'),
                  )
                else
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _signedPdfDataUrl = null;
                      _signedPdfName = null;
                    }),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Retirer le PDF'),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _importSignedPdf,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Importer un PDF signé'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: (_points.isEmpty && _signedPdfDataUrl == null) ? null : () async {
                    final chantierState = context.read<ChantierState>();
                    final reference = chantierState.currentChantier!.reference;
                    final signataire = _nameController.text.isEmpty ? 'Client' : _nameController.text;
                    final signatureImage = _signedPdfDataUrl ?? await _captureSignature();
                    try {
                      await chantierState.submitPv(reference, signataire, signatureImage: signatureImage);
                      if (!context.mounted) return;
                      context.go('/confirmation');
                    } on ApiException catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                  child: const Text('Valider le procès-verbal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Alternative à la signature au doigt : le client a déjà signé le PV sur
  /// papier (ou à distance) et l'installateur importe directement le PDF
  /// scanné/renvoyé, plutôt que de faire re-signer sur l'écran.
  Future<void> _importSignedPdf() async {
    final picked = await DocumentCapture.pickFile(allowedExtensions: ['pdf']);
    if (picked == null) return;
    setState(() {
      _signedPdfDataUrl = picked.dataUrl;
      _signedPdfName = picked.fileName;
    });
  }

  /// Capture le tracé de signature en PNG (base64) pour l'envoyer au serveur
  /// — encodé en data URL pour transiter tel quel dans le JSON de l'API et,
  /// hors-ligne, dans le payload de la file d'attente locale.
  Future<String?> _captureSignature() async {
    try {
      final boundary = _signatureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return 'data:image/png;base64,${base64Encode(byteData.buffer.asUint8List())}';
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
