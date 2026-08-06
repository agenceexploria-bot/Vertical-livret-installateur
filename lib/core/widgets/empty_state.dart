import 'package:flutter/material.dart';
import '../theme.dart';

/// État vide générique (liste/tableau sans résultat) : icône, message et
/// bouton d'action optionnel, centrés — remplace un simple "Aucun résultat."
/// perdu dans un tableau vide. Utilisé dans tout le back-office (listes de
/// chantiers, comptes...) pour une expérience cohérente.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.fond, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: AppColors.acierClair),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.acier),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 20)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
