import 'package:flutter/material.dart';
import '../theme.dart';
import 'app_card.dart';

/// Carte-indicateur pour une grille de tableau de bord (back-office) :
/// icône colorée, valeur en gros et libellé — [urgent] accentue la carte
/// (bordure + fond légèrement teintés) pour signaler une action requise, ex.
/// "3 inscriptions en attente".
///
/// Se soulève au survol (ombre accentuée + léger décalage vertical) même
/// sans [onTap] — ces cartes sont avant tout des indicateurs à repérer d'un
/// coup d'œil, contrairement à [AppCard] qui ne réagit au survol que si elle
/// est cliquable.
class DashboardStatCard extends StatefulWidget {
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
  State<DashboardStatCard> createState() => _DashboardStatCardState();
}

class _DashboardStatCardState extends State<DashboardStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transformAlignment: Alignment.center,
        transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (_hovered) BoxShadow(color: AppColors.encre.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 14)),
          ],
        ),
        child: AppCard(
          onTap: widget.onTap,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.encre)),
                    const SizedBox(height: 2),
                    Text(widget.label, style: const TextStyle(fontSize: 13, color: AppColors.acier), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (widget.urgent)
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
        ),
      ),
    );
  }
}
