import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      appBar: AppBar(
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
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(9))),
              ),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _points.clear()),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Effacer'),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _points.isEmpty ? null : () async {
                    final chantierState = context.read<ChantierState>();
                    final reference = chantierState.currentChantier!.reference;
                    final signataire = _nameController.text.isEmpty ? 'Client' : _nameController.text;
                    final signatureImage = await _captureSignature();
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
