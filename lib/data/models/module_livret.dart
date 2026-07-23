import 'package:flutter/material.dart';

class ModuleLivret {
  final int index;
  final String titre;
  final String sousTitre;
  final IconData icon;
  final bool isLocked;
  final double progression;

  ModuleLivret({
    required this.index,
    required this.titre,
    required this.sousTitre,
    required this.icon,
    this.isLocked = false,
    this.progression = 0.0,
  });
}
