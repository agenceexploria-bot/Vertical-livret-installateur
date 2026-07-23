import 'package:flutter/material.dart';
import '../theme.dart';

class SyncBanner extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;
  final String offlineUntil;

  const SyncBanner({
    super.key,
    required this.isOnline,
    this.pendingCount = 0,
    required this.offlineUntil,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: AppColors.vert.withValues(alpha: 0.1),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.vert, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Synchronisé — session hors-ligne valable jusqu\'au $offlineUntil',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.vert),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: AppColors.orange.withValues(alpha: 0.1),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: AppColors.orange, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hors-ligne — $pendingCount saisie(s) en attente',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.orange),
              ),
            ),
          ],
        ),
      );
    }
  }
}
