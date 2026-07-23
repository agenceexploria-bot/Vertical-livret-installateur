import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_indicator.dart';

class DocsAdminScreen extends StatelessWidget {
  const DocsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final docs = [
      {'title': 'PPSPS', 'version': 'v2'},
      {'title': 'Plan de prévention', 'version': '20/07/2026'},
      {'title': 'Autorisation d\'accès', 'version': 'v1'},
      {'title': 'Habilitations requises', 'version': 'v3'},
      {'title': 'Analyse de risques', 'version': 'v2'},
      {'title': 'Consignes environnement', 'version': 'v1'},
    ];

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('Documents & Sécurité'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final doc = docs[index];
          return AppCard(
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: AppColors.rouge, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('PDF · ${doc['version']}', style: const TextStyle(fontSize: 11, color: AppColors.acierClair)),
                    ],
                  ),
                ),
                const StatusIndicator(label: 'Hors-ligne', type: StatusType.conforme),
              ],
            ),
          );
        },
      ),
    );
  }
}
