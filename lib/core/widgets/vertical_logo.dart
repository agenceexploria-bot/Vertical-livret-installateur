import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';

class VerticalLogo extends StatelessWidget {
  final double height;
  final bool onDarkBackground;

  /// Bulle blanche (fond strictement blanc, bords arrondis) autour du logo —
  /// garantit que les vraies couleurs du SVG ressortent quel que soit le fond
  /// de l'écran, sans avoir à forcer une couleur de filtre dessus.
  final bool bubble;

  const VerticalLogo({
    super.key,
    this.height = 40,
    this.onDarkBackground = false,
    this.bubble = false,
  });

  @override
  Widget build(BuildContext context) {
    final forceWhite = onDarkBackground && !bubble;

    final svg = SvgPicture.asset(
      'assets/images/Vertical.svg',
      height: height,
      fit: BoxFit.contain,
      // On compense l'espace vide interne du SVG par un transform ou un alignement
      alignment: Alignment.center,
      colorFilter: forceWhite ? const ColorFilter.mode(Colors.white, BlendMode.srcIn) : null,
      placeholderBuilder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        child: Text(
          'VERTICAL',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: forceWhite ? Colors.white : AppColors.orange,
            letterSpacing: 2,
            fontSize: height * 0.4,
          ),
        ),
      ),
    );

    if (!bubble) return svg;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: svg,
    );
  }
}
