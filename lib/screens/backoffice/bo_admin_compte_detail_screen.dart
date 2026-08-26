import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/user.dart';
import '../../state/admin_state.dart';
import 'widgets/bo_back_button.dart';
import 'widgets/bo_panel.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_table_row.dart';

/// Fiche détaillée d'un compte, consultable par l'Admin pour n'importe quel
/// rôle (Installateur, CT, Direction, Qualité) — contrairement à
/// BoInstallateurDetailScreen (utilisée par le CT), réservée aux
/// installateurs. Lecture seule : les actions de gestion (suspendre,
/// réinitialiser le mot de passe, supprimer...) restent dans la liste
/// "Gestion des comptes" (voir BoComptesScreen).
class BoAdminCompteDetailScreen extends StatelessWidget {
  const BoAdminCompteDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = GoRouterState.of(context).pathParameters['id'] ?? '';
    final adminState = context.watch<AdminState>();
    User? compte;
    for (final candidate in adminState.tousLesComptes) {
      if (candidate.id == id) {
        compte = candidate;
        break;
      }
    }

    if (compte == null) {
      if (!adminState.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<AdminState>().fetchCompte(id);
        });
      }
      return BoShell(
        activeNav: 'comptes',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BoBackButton(),
            if (adminState.isLoading) const Center(child: CircularProgressIndicator()) else const Text('Compte introuvable'),
          ],
        ),
      );
    }
    final u = compte;

    final (statutLabel, statutType) = u.suspendu
        ? ('Suspendu', StatusType.attente)
        : !u.isActive
            ? ('En attente', StatusType.enCours)
            : ('Actif', StatusType.conforme);

    return BoShell(
      activeNav: 'comptes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BoBackButton(),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(u.fullName, style: Theme.of(context).textTheme.titleMedium),
              StatusBadge(label: statutLabel, type: statutType),
            ],
          ),
          const SizedBox(height: 20),
          BoPanel(
            title: 'Informations',
            child: Column(
              children: [
                BoKv(label: 'Rôle', value: Text(_roleLabel(u.role), style: const TextStyle(fontSize: 12.5))),
                BoKv(
                  label: 'Statut d\'emploi',
                  value: Text(
                    u.status == UserStatus.sousTraitant ? 'Sous-traitant' : 'Salarié',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                BoKv(label: 'Email', value: Text(u.email ?? '—', style: const TextStyle(fontSize: 12.5))),
                BoKv(label: 'Mobile', value: Text(u.mobile ?? '—', style: const TextStyle(fontSize: 12.5))),
                BoKv(label: 'Société', value: Text(u.societe ?? '—', style: const TextStyle(fontSize: 12.5))),
              ],
            ),
          ),
          BoPanel(
            title: 'Habilitations (${u.habilitations.length})',
            child: u.habilitations.isEmpty
                ? const Text('Aucune habilitation enregistrée.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
                : Column(children: [for (final h in u.habilitations) _habilitationRow(h)]),
          ),
        ],
      ),
    );
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.installateur:
        return 'Installateur';
      case UserRole.coordinateurTravaux:
        return 'Coordinateur travaux';
      case UserRole.qualite:
        return 'Qualité';
      case UserRole.direction:
        return 'Direction';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Widget _habilitationRow(Habilitation h) {
    final (label, type) = h.isExpired
        ? ('Expirée', StatusType.nonConforme)
        : h.expiresSoon
            ? ('Expire bientôt', StatusType.enCours)
            : ('À jour', StatusType.conforme);

    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${h.titre} · ${DateFormat('dd/MM/yyyy').format(h.dateExpiration)}',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          StatusIndicator(label: label, type: type),
        ],
      ),
    );
  }
}
