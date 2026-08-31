import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Zone de signature tactile générique — contrairement à
/// [lib/screens/client/signature_screen.dart] (qui capte un tracé superposé
/// à un PDF affiché, avec conversion de coordonnées document/écran), ce
/// pavé n'a rien en dessous : le tracé est capturé tel quel via
/// [RenderRepaintBoundary], sans transformation. Utilisé par le formulaire
/// PV interactif (voir pv_formulaire_screen.dart).
class SignaturePad extends StatefulWidget {
  final ValueChanged<bool>? onChanged;
  const SignaturePad({super.key, this.onChanged});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];
  final _boundaryKey = GlobalKey();

  bool get isEmpty => !_points.any((p) => p != null);

  void clear() {
    setState(() => _points.clear());
    widget.onChanged?.call(true);
  }

  void _addPoint(Offset? point) {
    setState(() => _points.add(point));
    widget.onChanged?.call(isEmpty);
  }

  /// Rasterise le tracé en PNG (fond transparent) — `null` si rien n'a été
  /// dessiné ou si le rendu n'est pas encore prêt.
  Future<Uint8List?> capturePng({double pixelRatio = 3}) async {
    if (isEmpty) return null;
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox == null) return;
          _addPoint(renderBox.globalToLocal(details.globalPosition));
        },
        onPanEnd: (_) => _addPoint(null),
        child: CustomPaint(painter: _SignaturePadPainter(_points), size: Size.infinite),
      ),
    );
  }
}

class _SignaturePadPainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePadPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    for (var i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePadPainter oldDelegate) => true;
}
