import 'dart:math' as math;
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

/// Taille moyenne d'une maille (px) de la grille qui pilote la densité du
/// filigrane — chaque maille reçoit une icône, décalée aléatoirement en son
/// sein (voir [verticalPatternJitter]), donc l'espacement RÉEL entre icônes
/// varie mais reste centré sur cette valeur. Public/testable pour vérifier
/// que le motif reste dense (voir vertical_pattern_background_test.dart).
const verticalPatternSpacing = 45.0;

/// Icônes Material existantes plutôt que des tracés vectoriels maison —
/// même rendu net à toute taille/résolution, zéro maintenance de path, et
/// déjà embarquées dans le binaire (police MaterialIcons), donc aucun poids
/// d'asset supplémentaire. Exclusivement liées au chantier/monte-charge —
/// aucune icône hors-thème (ex: ancre, retirée après retour terrain).
/// Public/testable (voir vertical_pattern_background_test.dart).
const verticalPatternIcons = [
  Icons.elevator_outlined, // cabine de monte-charge
  Icons.swap_vert, // flèches montée/descente
  Icons.engineering_outlined, // casque de chantier
  Icons.build_outlined, // clé à molette
  Icons.construction, // panneau de chantier
  Icons.settings_outlined, // engrenage
  Icons.hardware_outlined, // vis / écrou
  Icons.handyman_outlined, // tournevis + clé
  Icons.carpenter_outlined, // marteau
  Icons.precision_manufacturing_outlined, // grue / bras mécanique
  Icons.build_circle_outlined, // perceuse / visseuse
  Icons.foundation_outlined, // échafaudage / fondation
  Icons.stairs_outlined, // échelle
  Icons.straighten_outlined, // mètre ruban
  Icons.square_foot_outlined, // équerre / niveau
  Icons.warning_amber_outlined, // panneau de sécurité
];

/// Bruit pseudo-aléatoire déterministe : la même position (rangee, colonne)
/// et le même canal (salt — un par propriété tirée : décalage X, décalage Y,
/// rotation, taille, choix d'icône) renvoient TOUJOURS la même valeur dans
/// [0, 1). Aucun état, aucune graine mutable, aucun `Random` — juste une
/// fonction pure (technique classique de bruit par hash trigonométrique,
/// utilisée en shader) : le motif ne "flicke" jamais et rend à l'identique à
/// chaque peinture et chaque ouverture de l'app. Basée uniquement sur des
/// `double` (IEEE754), donc strictement identique entre le rendu natif et le
/// rendu web (pas de dépendance à la largeur des entiers de la plateforme).
double verticalPatternJitter(int rangee, int colonne, int salt) {
  final n = rangee * 12.9898 + colonne * 78.233 + salt * 37.719 + 91.345;
  final s = math.sin(n) * 43758.5453;
  return s - s.floorToDouble();
}

/// Fond à motif dense et dispersé (façon WhatsApp) pour les écrans mobiles
/// (installateur ET CT) — uniquement des icônes liées aux chantiers/
/// monte-charges (voir [verticalPatternIcons]), disposées de façon
/// pseudo-aléatoire (décalage, rotation ±15°, taille variable) plutôt qu'en
/// grille régulière, pour un rendu organique. Dessiné en CustomPainter
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
  static const _tailleMin = 24.0;
  static const _tailleMax = 36.0;
  static const _rotationMaxDeg = 15.0;
  // Le décalage dans la maille reste sous sa moitié pour éviter qu'une icône
  // ne déborde trop loin sur la maille voisine (chevauchement excessif).
  static const _decalageMax = verticalPatternSpacing * 0.35;

  const _VerticalPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = verticalPatternBackgroundColor);

    final colonnes = (size.width / verticalPatternSpacing).ceil() + 2;
    final rangees = (size.height / verticalPatternSpacing).ceil() + 2;

    for (var rangee = -1; rangee < rangees; rangee++) {
      for (var colonne = -1; colonne < colonnes; colonne++) {
        final decalageX = (verticalPatternJitter(rangee, colonne, 1) - 0.5) * 2 * _decalageMax;
        final decalageY = (verticalPatternJitter(rangee, colonne, 2) - 0.5) * 2 * _decalageMax;
        final angleDeg = (verticalPatternJitter(rangee, colonne, 3) - 0.5) * 2 * _rotationMaxDeg;
        final taille = _tailleMin + verticalPatternJitter(rangee, colonne, 4) * (_tailleMax - _tailleMin);
        final indiceIcone = (verticalPatternJitter(rangee, colonne, 5) * verticalPatternIcons.length)
            .floor()
            .clamp(0, verticalPatternIcons.length - 1);
        final icone = verticalPatternIcons[indiceIcone];

        final painter = TextPainter(textDirection: TextDirection.ltr)
          ..text = TextSpan(
            text: String.fromCharCode(icone.codePoint),
            style: TextStyle(
              fontSize: taille,
              fontFamily: icone.fontFamily,
              package: icone.fontPackage,
              color: verticalPatternIconColor,
            ),
          )
          ..layout();

        final centre = Offset(
          colonne * verticalPatternSpacing + verticalPatternSpacing / 2 + decalageX,
          rangee * verticalPatternSpacing + verticalPatternSpacing / 2 + decalageY,
        );

        canvas.save();
        canvas.translate(centre.dx, centre.dy);
        canvas.rotate(angleDeg * math.pi / 180);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      }
    }
  }

  // Motif entièrement statique (mêmes icônes, mêmes positions) — ne dépend
  // que de [size] (le bruit est une fonction pure de la position de maille,
  // jamais d'un état externe), et [size] ne change qu'à un nouveau layout
  // (rotation, redimensionnement de fenêtre).
  @override
  bool shouldRepaint(covariant _VerticalPatternPainter oldDelegate) => false;
}
