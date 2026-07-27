import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/user.dart';
import '../../state/auth_state.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';

class BoInstallateurDetailScreen extends StatelessWidget {
  const BoInstallateurDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = GoRouterState.of(context).pathParameters['id'] ?? '';
    final installateurs = context.watch<ComptesState>().installateurs;
    User? u;
    for (final candidate in installateurs) {
      if (candidate.id == id) u = candidate;
    }

    if (u == null) {
      return const BoShell(activeNav: 'comptes', child: Text('Installateur introuvable'));
    }
    final installateur = u;

    final chantiers = context.watch<ChantierState>().chantiers.where((c) => c.installateursRattaches.any((r) => r.id == id)).toList();

    final (compteLabel, compteType) = installateur.suspendu
        ? ('Suspendu', StatusType.attente)
        : !installateur.isActive
            ? ('En attente', StatusType.enCours)
            : ('Actif', StatusType.conforme);
    // Suppression définitive réservée à l'Admin (voir la refonte des rôles
    // back-office) — le CA n'a pas ce droit.
    final isAdmin = context.watch<AuthState>().currentUser?.role == UserRole.admin;

    return BoShell(
      activeNav: 'comptes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(installateur.fullName, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 10),
              StatusIndicator(label: compteLabel, type: compteType),
              const Spacer(),
              if (isAdmin)
                OutlinedButton(
                  onPressed: () => _confirmerSuppression(context, installateur),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    foregroundColor: AppColors.rouge,
                    side: const BorderSide(color: AppColors.rouge),
                  ),
                  child: const Text('Supprimer le compte', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final left = _buildInfos(installateur);
              final right = _buildHabilitationsEtChantiers(installateur, chantiers.map((c) => c.reference).toList());
              if (!isWide) return Column(children: [left, const SizedBox(height: 12), right]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: left), const SizedBox(width: 20), Expanded(child: right)],
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmerSuppression(BuildContext context, User installateur) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text(
          'Le compte de ${installateur.fullName} sera supprimé définitivement, avec ses habilitations et documents terrain. Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context.read<ComptesState>().supprimer(installateur);
              if (context.mounted) context.go('/backoffice/ca/comptes');
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfos(User u) {
    final statutLabel = u.status == UserStatus.sousTraitant ? 'Sous-traitant${u.societe != null ? ' · ${u.societe}' : ''}' : 'Salarié';
    return BoPanel(
      title: 'Informations',
      child: Column(
        children: [
          BoKv(label: 'Statut', value: Text(statutLabel, style: const TextStyle(fontSize: 11.5))),
          BoKv(label: 'Mobile', value: Text(u.mobile ?? '—', style: const TextStyle(fontSize: 11.5))),
          BoKv(label: 'Email', value: Text(u.email ?? '—', style: const TextStyle(fontSize: 11.5))),
        ],
      ),
    );
  }

  Widget _buildHabilitationsEtChantiers(User u, List<String> chantierRefs) {
    return Column(
      children: [
        BoPanel(
          title: 'Habilitations (${u.habilitations.length})',
          child: u.habilitations.isEmpty
              ? const Text('Aucune habilitation enregistrée.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
              : Column(children: [for (final h in u.habilitations) _habilitationRow(h)]),
        ),
        BoPanel(
          title: 'Chantiers rattachés (${chantierRefs.length})',
          child: chantierRefs.isEmpty
              ? const Text('Aucun chantier rattaché.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final ref in chantierRefs) Chip(label: Text(ref, style: const TextStyle(fontSize: 11)))],
                ),
        ),
      ],
    );
  }

  Widget _habilitationRow(Habilitation h) {
    final (label, type) = h.isExpired
        ? ('Expirée', StatusType.nonConforme)
        : h.expiresSoon
            ? ('Expire bientôt', StatusType.enCours)
            : ('À jour', StatusType.conforme);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${h.titre} · ${DateFormat('dd/MM/yyyy').format(h.dateExpiration)}',
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
          StatusIndicator(label: label, type: type),
          if (h.filePath != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => launchUrl(Uri.parse(h.filePath!)),
              style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Voir', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}
