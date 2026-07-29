import 'package:flutter/material.dart';
import '../theme.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  // Seules les cartes cliquables réagissent au survol — sinon l'effet
  // suggérerait à tort qu'une carte statique est interactive.
  bool get _reactive => widget.onTap != null;

  void _setHovered(bool value) {
    if (_reactive && _hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered && _reactive;
    return MouseRegion(
      cursor: _reactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transformAlignment: Alignment.center,
            transform: Matrix4.diagonal3Values(hovered ? 1.025 : 1.0, hovered ? 1.025 : 1.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, AppColors.fond],
              ),
              border: Border.all(color: hovered ? AppColors.orange.withValues(alpha: 0.3) : Colors.transparent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.encre.withValues(alpha: hovered ? 0.22 : 0.08),
                  blurRadius: hovered ? 42 : 30,
                  offset: Offset(0, hovered ? 18 : 12),
                ),
              ],
            ),
            padding: widget.padding ?? const EdgeInsets.all(16.0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
