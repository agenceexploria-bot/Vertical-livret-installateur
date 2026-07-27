import 'package:flutter/material.dart';

/// Enveloppe un tableau dense (colonnes en `Row`/`Expanded`) pour qu'il reste
/// lisible sur tablette : au-dessus de [minWidth] il occupe toute la largeur
/// disponible normalement, en-dessous il garde sa largeur minimale et devient
/// défilable horizontalement plutôt que d'écraser les colonnes.
class BoResponsiveTable extends StatelessWidget {
  final Widget child;
  final double minWidth;

  const BoResponsiveTable({super.key, required this.child, this.minWidth = 720});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}
