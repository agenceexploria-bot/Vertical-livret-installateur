import 'package:flutter/material.dart';
import '../theme.dart';
import 'app_card.dart';

/// Carte-indicateur pour une grille de tableau de bord (back-office) :
/// icône colorée, valeur en gros et libellé — [urgent] accentue la carte
/// (bordure + fond légèrement teintés) pour signaler une action requise, ex.
/// "3 inscriptions en attente".
class DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool urgent;
  final VoidCallback? onTap;

  const DashboardStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.urgent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.encre)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 13, color: AppColors.acier), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (urgent)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)],
              ),
            ),
        ],
      ),
    );
  }
}
