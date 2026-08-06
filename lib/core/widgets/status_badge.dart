import 'package:flutter/material.dart';
import '../theme.dart';
import 'status_indicator.dart';

/// Pastille de statut pleine couleur (fond teinté + texte), pour les endroits
/// où le statut doit sauter aux yeux dans une grille de cartes ou l'en-tête
/// d'une fiche — plus visible que [StatusIndicator] (simple pastille + texte
/// gris), qui reste la version discrète utilisée dans les tableaux denses.
/// Réutilise le même [StatusType] pour rester cohérent avec le reste du
/// back-office.
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusBadge({super.key, required this.label, required this.type});

  Color get _color => switch (type) {
        StatusType.conforme => AppColors.vert,
        StatusType.nonConforme => AppColors.rouge,
        StatusType.enCours => AppColors.orange,
        StatusType.attente => AppColors.acierClair,
        StatusType.factuel => AppColors.acier,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
