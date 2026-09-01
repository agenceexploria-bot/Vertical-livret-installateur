import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Zone de signature tactile générique — contrairement à
/// [lib/screens/client/signature_screen.dart] (qui capte un tracé superposé
/// à un PDF affiché, avec conversion de coordonnées document/écran), ce
/// pavé n'a rien en dessous : le tracé est capturé tel quel, sans
/// transformation. Utilisé par le formulaire PV interactif (voir
/// pv_formulaire_screen.dart).
///
/// Le TRACÉ lui-même (la liste de [points]) est détenu par l'appelant,
/// jamais durablement par ce widget — une précédente version le gardait
/// dans son propre State, détruit (donc le tracé perdu) chaque fois que ce
/// widget était démonté, par exemple une section d'accordéon repliée dans
/// pv_formulaire_screen.dart, provoquant un faux "signature manquante" à la
/// validation même après une signature valide. [renderSignaturePng]
/// ci-dessous rend l'image directement depuis [points], indépendamment de
/// tout widget monté — donc plus jamais `null` après un démontage.
///
/// Ce widget garde malgré tout un State local (`_points`), initialisé
/// depuis [points] à chaque montage : PAS pour stocker durablement le
/// tracé (voir ci-dessus), mais parce qu'un glissé tactile déclenche
/// plusieurs `onPanUpdate` de suite AVANT que Flutter ne reconstruise ce
/// widget avec le [points] mis à jour par l'appelant (`setState` ne
/// reconstruit qu'à la frame suivante) — accumuler directement sur
/// `widget.points` capturé au dernier `build` perdrait alors les points
/// intermédiaires du même geste. `_points` (champ muté en place, comme dans
/// l'ancienne implémentation) encaisse ces événements rapprochés sans
/// perte, et reste synchronisé avec [points] à chaque changement externe
/// (ex. "Effacer la signature", ou un remontage qui restaure le tracé
/// persisté par le parent).
class SignaturePad extends StatefulWidget {
  final List<Offset?> points;

  /// Appelé à chaque mise à jour du tracé, avec la taille du cadre au
  /// moment du tracé (les points sont en coordonnées locales à ce cadre —
  /// voir [renderSignaturePng], qui en a besoin pour rasteriser
  /// correctement même une fois ce widget démonté).
  final void Function(List<Offset?> points, Size boxSize) onPointsChanged;

  const SignaturePad({super.key, required this.points, required this.onPointsChanged});

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  late List<Offset?> _points = widget.points;

  @override
  void didUpdateWidget(covariant SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ne resynchronise QUE si le parent a remplacé la liste de l'extérieur
    // (identité différente) — sans cette garde, la resynchronisation
    // écraserait aussi les points accumulés localement pendant un geste en
    // cours (voir la doc de la classe), puisque le parent nous renvoie de
    // toute façon la même liste après chaque `onPointsChanged`.
    if (!identical(widget.points, _points)) {
      _points = widget.points;
    }
  }

  void _addPoint(Offset? point, Size boxSize) {
    setState(() => _points = [..._points, point]);
    widget.onPointsChanged(_points, boxSize);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        _addPoint(renderBox.globalToLocal(details.globalPosition), renderBox.size);
      },
      onPanEnd: (_) {
        final renderBox = context.findRenderObject() as RenderBox?;
        _addPoint(null, renderBox?.size ?? Size.zero);
      },
      child: CustomPaint(painter: _SignaturePadPainter(_points), size: Size.infinite),
    );
  }
}

/// `true` si aucun trait n'a été dessiné dans [points].
bool signaturePointsEmpty(List<Offset?> points) => !points.any((p) => p != null);

/// Rasterise un tracé de signature en PNG (fond transparent) à partir de
/// [points] seul, via `PictureRecorder` — contrairement à l'ancienne
/// implémentation qui passait par `RenderRepaintBoundary.toImage()` (donc
/// systématiquement `null` dès que le pavé n'était plus dans l'arbre), cette
/// fonction ne dépend d'aucun widget monté : elle fonctionne même si
/// [SignaturePad] a été démonté entre-temps (section d'accordéon repliée).
/// [size] doit être la taille du cadre au moment où [points] a été dessiné
/// (voir [SignaturePad.onPointsChanged]) — les coordonnées de [points] lui
/// sont relatives. `null` si rien n'a été dessiné ou si [size] est invalide.
Future<Uint8List?> renderSignaturePng(List<Offset?> points, Size size, {double pixelRatio = 3}) async {
  if (signaturePointsEmpty(points) || size.isEmpty) return null;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width * pixelRatio, size.height * pixelRatio));
  canvas.scale(pixelRatio);
  _SignaturePadPainter(points).paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage((size.width * pixelRatio).round(), (size.height * pixelRatio).round());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}

// TODO(2026-08-31) : duplique lib/screens/client/signature_screen.dart's
// _SignaturePainter (même logique de tracé point-à-point) — à factoriser en
// un seul CustomPainter partagé au prochain tour de nettoyage.
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
