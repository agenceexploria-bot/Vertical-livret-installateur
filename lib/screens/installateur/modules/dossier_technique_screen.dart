import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/responsive_layout.dart';

class DossierTechniqueScreen extends StatelessWidget {
  const DossierTechniqueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: ResponsiveLayout(
        appBar: AppBar(
          title: const Text('Dossier technique'),
          backgroundColor: AppColors.encre,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.acierClair,
            indicatorColor: AppColors.orange,
            tabs: [
              Tab(text: 'Plans'),
              Tab(text: 'Notices'),
              Tab(text: 'Photos'),
            ],
          ),
        ),
        child: TabBarView(
          children: [
            _buildPlansTab(),
            const Center(child: Text('Notices de montage')),
            const Center(child: Text('Photos du site')),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            height: 400,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.fond,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.lignes),
            ),
            child: CustomPaint(
              painter: _GainePainter(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.zoom_in),
                  label: const Text('Zoomer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Plein écran'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GainePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.encre
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Dessin de la gaine
    final rect = Rect.fromLTWH(50, 50, size.width - 100, size.height - 150);
    canvas.drawRect(rect, paint);

    // Cuvette
    canvas.drawLine(Offset(50, size.height - 100), Offset(size.width - 50, size.height - 100), paint);

    // Cotes
    const textStyle = TextStyle(color: AppColors.encre, fontSize: 12, fontWeight: FontWeight.bold);
    _drawText(canvas, 'GAINE 1600 × 1980', Offset(size.width / 2 - 60, 20), textStyle);
    _drawText(canvas, 'CUVETTE 150 mm', Offset(size.width / 2 - 55, size.height - 80), textStyle);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
