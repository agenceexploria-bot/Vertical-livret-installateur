import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Zone de dépôt de fichiers réutilisable, posée autour d'un bouton/zone
/// d'import existant — sur Flutter Web, glisser un ou plusieurs fichiers
/// dessus déclenche [onFilesDropped] (même logique que le sélecteur natif,
/// juste une autre façon de fournir les fichiers) et met la zone en
/// surbrillance pendant le survol. Sur mobile (natif), le glisser-déposer
/// n'a pas de sens — il n'y a pas de fichiers "OS" à faire glisser dans une
/// app — [child] est alors rendu tel quel, sans aucun comportement ajouté :
/// seul le bouton caméra/galerie habituel reste disponible.
class DropZone extends StatefulWidget {
  final Widget child;
  final ValueChanged<List<XFile>> onFilesDropped;
  final BorderRadius borderRadius;

  const DropZone({
    super.key,
    required this.child,
    required this.onFilesDropped,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        if (details.files.isNotEmpty) widget.onFilesDropped(details.files);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(color: _isDragging ? AppColors.encre : Colors.transparent, width: 1.5),
          color: _isDragging ? AppColors.encre.withValues(alpha: 0.05) : null,
        ),
        child: widget.child,
      ),
    );
  }
}
