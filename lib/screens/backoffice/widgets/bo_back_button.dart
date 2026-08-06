import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../data/models/user.dart';
import '../../../state/auth_state.dart';

/// Bouton "Retour" affiché en tête des pages de détail du back-office (fiche
/// chantier, fiche compte, nouveau chantier...) : ces pages n'ont pas
/// d'onglet de navigation propre dans [BoShell], seul un retour arrière
/// permet d'en sortir — sans ce bouton elles donnent une impression de
/// cul-de-sac.
///
/// Passe par [BuildContext.canPop] plutôt que d'appeler systématiquement
/// [GoRouter.pop] : un lien ouvert directement dans un nouvel onglet
/// (partagé, mis en favori, tapé à la main) n'a pas d'historique de
/// navigation à dépiler — dans ce cas on retombe sur la page d'accueil du
/// rôle de l'utilisateur plutôt que de planter.
class BoBackButton extends StatelessWidget {
  const BoBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextButton.icon(
        onPressed: () => _goBack(context),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('Retour'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.acier,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final role = context.read<AuthState>().currentUser?.role;
    context.go(role == UserRole.admin ? '/backoffice/admin' : '/backoffice/ca');
  }
}
