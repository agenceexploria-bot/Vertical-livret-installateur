import 'dart:ui';
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
    final color = isOnline ? AppColors.vert : AppColors.orange;
    final icon = isOnline ? Icons.check_circle : Icons.cloud_off;
    final text = isOnline
        ? 'Synchronisé — session hors-ligne valable jusqu\'au $offlineUntil'
        : 'Hors-ligne — $pendingCount saisie(s) en attente';

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.18), width: 1)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
