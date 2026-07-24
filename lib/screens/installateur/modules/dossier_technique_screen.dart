import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/document_chantier.dart';
import '../../../state/chantier_state.dart';

class DossierTechniqueScreen extends StatelessWidget {
  const DossierTechniqueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier!;
    final docs = chantier.documentsChantier.where((d) => d.type == TypeDocumentChantier.technique).toList();

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('Dossier technique'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: docs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun document technique (plan, notice...) déposé pour ce chantier.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.acierClair),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return AppCard(
                  onTap: () => launchUrl(Uri.parse(doc.filePath)),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: AppColors.encre, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(doc.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.acierClair),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
