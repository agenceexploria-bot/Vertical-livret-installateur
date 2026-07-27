import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';

class VerticalLogo extends StatelessWidget {
  final double height;
  final bool onDarkBackground;

  const VerticalLogo({
    super.key,
    this.height = 40,
    this.onDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/Vertical.svg',
      height: height,
      fit: BoxFit.contain,
      // On compense l'espace vide interne du SVG par un transform ou un alignement
      alignment: Alignment.center,
      colorFilter: onDarkBackground
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : null,
      placeholderBuilder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        child: Text(
          'VERTICAL',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: onDarkBackground ? Colors.white : AppColors.orange,
            letterSpacing: 2,
            fontSize: height * 0.4,
          ),
        ),
      ),
    );
  }
}
