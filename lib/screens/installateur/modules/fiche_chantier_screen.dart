import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/coming_soon.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../state/chantier_state.dart';

class FicheChantierScreen extends StatelessWidget {
  const FicheChantierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier;

    if (chantier == null) return const Scaffold();

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Fiche chantier'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau de sécurité orange non escamotable
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.orange, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Consignes de sécurité',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.orange,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...chantier.consignes.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(c, style: const TextStyle(color: AppColors.orange, fontSize: 13))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection(context, 'Informations client', [
              _buildRow('Client', chantier.client),
              _buildRow('Adresse', chantier.adresse),
              _buildRow('Ville', chantier.ville),
              _buildRow('Horaires', chantier.horaires),
            ]),
            
            const SizedBox(height: 16),
            
            _buildSection(context, 'Contact sur place', [
              _buildRow('Nom', chantier.contactNom),
              _buildRow('Téléphone', chantier.contactTel),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showComingSoon(context),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Appeler'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showComingSoon(context),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('GPS'),
                    ),
                  ),
                ],
              ),
            ]),
            
            const SizedBox(height: 16),
            
            _buildSection(context, 'Détails techniques', [
              _buildRow('Type', chantier.typeMonteCharge),
              _buildRow('Capacité', chantier.capacite),
              _buildRow('Niveaux', '${chantier.niveaux}'),
              _buildRow('Réf. Affaire', chantier.referenceAffaire),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.lignes),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.acierClair, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.encre, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
