import 'package:flutter/material.dart';

/// Fond de couleur du filigrane — blanc-gris-kaki très clair, légèrement
/// différent de [AppColors.fond] (utilisé ailleurs pour un fond uni sans
/// motif) pour que ce filigrane reste identifiable comme un habillage à
/// part, pas juste "le même gris habituel".
const verticalPatternBackgroundColor = Color(0xFFF2F2EC);

/// Couleur des icônes en filigrane — gris clair, juste assez visible pour
/// meubler les interstices entre les cartes sans jamais concurrencer leur
/// contenu (voir _VerticalPatternPainter.paint).
const verticalPatternIconColor = Color(0xFFDCDAD2);

/// Espacement (px) entre deux icônes du filigrane — public/testable pour
/// vérifier que le motif reste dense (voir vertical_pattern_background_test.dart).
const verticalPatternSpacing = 45.0;

/// Fond à motif répétitif dense (façon WhatsApp) pour les écrans mobiles
/// (installateur ET CT) — uniquement des icônes liées aux chantiers/
/// monte-charges : cabine, flèches de montée/descente, casque, clé,
/// engrenage, chantier/construction, en quinconce. Dessiné en CustomPainter
/// (glyphes de la police d'icônes Material, jamais d'asset image) plutôt
/// qu'une image répétée — poids nul, netteté à toute résolution. Statique
/// (voir [_VerticalPatternPainter.shouldRepaint]) : ne se redessine jamais
/// après le premier layout, sauf si la taille change (rotation,
/// redimensionnement de fenêtre).
///
/// Toujours utilisé en fond de [Stack] (voir [ResponsiveLayout]), sous le
/// contenu réel de l'écran — les cartes/tuiles, opaques, masquent
/// naturellement le motif sous elles ; il ne reste visible que dans les
/// interstices.
class VerticalPatternBackground extends StatelessWidget {
  const VerticalPatternBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: RepaintBoundary(
        child: CustomPaint(painter: _VerticalPatternPainter()),
      ),
    );
  }
}

class _VerticalPatternPainter extends CustomPainter {
  // Icônes Material existantes plutôt que des tracés vectoriels maison —
  // même rendu net à toute taille/résolution, zéro maintenance de path, et
  // déjà embarquées dans le binaire (police MaterialIcons), donc aucun
  // poids d'asset supplémentaire.
  static const _icones = [
    Icons.elevator_outlined, // cabine de monte-charge
    Icons.swap_vert, // flèches montée/descente
    Icons.engineering_outlined, // casque de chantier
    Icons.build_outlined, // clé à molette
    Icons.settings_outlined, // engrenage
    Icons.construction, // chantier
  ];
  static const _tailleIcone = 30.0;
  static const _espacement = verticalPatternSpacing;

  // Un seul TextPainter par icône, calculé une fois pour toute la durée de
  // l'app (static final) — jamais reconstruit à chaque paint ni à chaque
  // écran, malgré une nouvelle instance de painter à chaque build (voir
  // shouldRepaint, qui empêche de toute façon tout repaint après le premier).
  static final List<TextPainter> _painters = _icones.map((icone) {
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icone.codePoint),
        style: TextStyle(
          fontSize: _tailleIcone,
          fontFamily: icone.fontFamily,
          package: icone.fontPackage,
          color: verticalPatternIconColor,
        ),
      )
      ..layout();
    return painter;
  }).toList();

  const _VerticalPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = verticalPatternBackgroundColor);

    var indiceIcone = 0;
    var rangee = 0;
    for (double y = -_espacement; y < size.height + _espacement; y += _espacement) {
      // Quinconce : une rangée sur deux décalée d'une demi-largeur de maille.
      final decalageX = rangee.isOdd ? _espacement / 2 : 0.0;
      for (double x = -_espacement; x < size.width + _espacement; x += _espacement) {
        final painter = _painters[indiceIcone % _painters.length];
        painter.paint(canvas, Offset(x + decalageX - painter.width / 2, y - painter.height / 2));
        indiceIcone++;
      }
      rangee++;
    }
  }

  // Motif entièrement statique (mêmes icônes, mêmes positions relatives) —
  // ne dépend que de [size], qui ne change jamais entre deux instances tant
  // que l'écran n'a pas été redimensionné/tourné (CustomPaint appelle déjà
  // shouldRepaint uniquement sur un nouveau layout).
  @override
  bool shouldRepaint(covariant _VerticalPatternPainter oldDelegate) => false;
}
