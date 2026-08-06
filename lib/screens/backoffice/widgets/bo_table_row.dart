import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Ligne de tableau ou de liste réactive au survol (fondu de couleur de
/// fond), utilisée par tous les tableaux/listes du back-office pour un
/// retour visuel cohérent — y compris les lignes non cliquables, où le
/// survol reste purement indicatif.
///
/// Peint sa propre teinte via MouseRegion/AnimatedContainer plutôt que de
/// compter sur le calque d'encre d'un `InkWell` : dans un tableau, l'InkWell
/// enregistre son survol sur le `Material` ancêtre le plus proche (souvent
/// celui du Scaffold), qui peint AVANT le fond opaque du tableau — l'effet se
/// retrouvait donc masqué. Ici la teinte est peinte directement à la place
/// de la ligne, jamais recouverte.
class BoTableRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Border? border;

  /// Fond de la ligne au repos (avant survol) — utilisé pour le zébrage
  /// (une ligne sur deux légèrement teintée) dans les tableaux denses, plus
  /// lisibles qu'un fond uniforme sur une longue liste.
  final Color? backgroundColor;

  const BoTableRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    this.border,
    this.backgroundColor,
  });

  @override
  State<BoTableRow> createState() => _BoTableRowState();
}

class _BoTableRowState extends State<BoTableRow> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.acier.withValues(alpha: 0.07) : (widget.backgroundColor ?? Colors.transparent),
            border: widget.border,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
