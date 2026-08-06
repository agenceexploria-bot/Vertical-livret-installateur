import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/vertical_logo.dart';

/// Écran affiché après l'envoi d'une demande d'accès interne (CA) — le
/// compte est créé mais inactif tant qu'un Admin ne l'a pas validé (voir
/// BoAccessRequestScreen._submit), donc pas de connexion automatique ici.
class BoAccessConfirmationScreen extends StatelessWidget {
  const BoAccessConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.blanc,
              border: Border.all(color: AppColors.lignes),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppColors.encre.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 12)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 60, child: VerticalLogo(height: 60)),
                const SizedBox(height: 32),
                const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.vert),
                const SizedBox(height: 24),
                Text('Demande envoyée', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text(
                  'Vos informations ont bien été enregistrées. Elles seront examinées par un administrateur. Vous pourrez vous connecter une fois votre compte validé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.acier),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/backoffice/login'),
                  child: const Text('Retour à la connexion'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
