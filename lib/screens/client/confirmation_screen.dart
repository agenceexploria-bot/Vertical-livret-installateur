import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/coming_soon.dart';
import '../../core/theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../state/chantier_state.dart';

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier;

    return ResponsiveLayout(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: AppColors.vert),
            const SizedBox(height: 32),
            const Text('PV signé et archivé', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (chantier != null)
              Text(
                'Signé par ${chantier.pvSigneur ?? 'le client'}'
                '${chantier.pvSigneAt != null ? ' le ${DateFormat('dd/MM/yyyy à HH:mm').format(chantier.pvSigneAt!)}' : ''}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.acier, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            const Text(
              'Le PDF a été envoyé par email au client. Le chargé d\'affaires a été notifié pour la facturation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.acier),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.fond,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.lignes),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: AppColors.rouge),
                  const SizedBox(width: 16),
                  Expanded(child: Text('PV_${chantier?.reference ?? ''}_Reception.pdf', style: const TextStyle(fontSize: 13))),
                  IconButton(onPressed: () => showComingSoon(context), icon: const Icon(Icons.download, size: 20)),
                ],
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Retour au livret'),
            ),
          ],
        ),
      ),
    );
  }
}
