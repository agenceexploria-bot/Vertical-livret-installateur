import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/user.dart';
import '../../state/auth_state.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_responsive_table.dart';
import 'widgets/bo_shell.dart';

class BoComptesScreen extends StatelessWidget {
  const BoComptesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final comptesState = context.watch<ComptesState>();
    final chantiers = context.watch<ChantierState>().chantiers;
    final isAdmin = context.watch<AuthState>().currentUser?.role == UserRole.admin;

    return BoShell(
      activeNav: 'comptes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Comptes installateurs', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BoResponsiveTable(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.blanc,
                border: Border.all(color: AppColors.lignes),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Column(
                children: [
                  _headerRow(),
                  for (final u in comptesState.installateurs) _dataRow(context, u, chantiers, comptesState, isAdmin),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMenuAction(BuildContext context, ComptesState comptesState, User u, String value) {
    switch (value) {
      case 'suspendre':
        comptesState.suspendre(u);
        break;
      case 'reinit':
        _openReinitDialog(context, comptesState, u);
        break;
      case 'supprimer':
        _confirmerSuppression(context, comptesState, u);
        break;
    }
  }

  void _openReinitDialog(BuildContext context, ComptesState comptesState, User u) {
    final controller = TextEditingController();
    bool isSubmitting = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Réinitialiser le mot de passe de ${u.fullName}'),
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: controller,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe', hintText: 'Au moins 6 caractères'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: controller.text.trim().length < 6 || isSubmitting
                  ? null
                  : () async {
                      setState(() => isSubmitting = true);
                      await comptesState.reinitialiserMotDePasse(u, controller.text.trim());
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: isSubmitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Réinitialiser'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmerSuppression(BuildContext context, ComptesState comptesState, User u) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text('Le compte de ${u.fullName} sera supprimé définitivement. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () {
              Navigator.pop(dialogContext);
              comptesState.supprimer(u);
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    const style = TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.acier, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFFEDF0F2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('INSTALLATEUR', style: style)),
          Expanded(flex: 3, child: Text('STATUT', style: style)),
          Expanded(flex: 2, child: Text('COMPTE', style: style)),
          Expanded(flex: 3, child: Text('HABILITATIONS', style: style)),
          Expanded(flex: 2, child: Text('CHANTIERS', style: style)),
          Expanded(flex: 2, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  Widget _dataRow(BuildContext context, User u, List chantiers, ComptesState comptesState, bool isAdmin) {
    final (compteLabel, compteType) = u.suspendu
        ? ('Suspendu', StatusType.attente)
        : !u.isActive
            ? ('En attente', StatusType.enCours)
            : ('Actif', StatusType.conforme);

    final expired = u.habilitations.where((h) => h.isExpired).toList();
    final expiringSoon = u.habilitations.where((h) => !h.isExpired && h.expiresSoon).toList();
    final (habLabel, habType) = u.habilitations.isEmpty
        ? ('—', StatusType.factuel)
        : expired.isNotEmpty || expiringSoon.isNotEmpty
            ? ('${expiringSoon.isNotEmpty ? expiringSoon.first.titre.split(' ').first : expired.first.titre.split(' ').first} — à surveiller', StatusType.nonConforme)
            : ('À jour', StatusType.conforme);

    final mesChantiers = chantiers.where((c) => c.installateursRattaches.any((r) => r.id == u.id)).map((c) => c.reference).join(', ');

    final statutLabel = u.status == UserStatus.sousTraitant ? 'Sous-traitant${u.societe != null ? ' · ${u.societe}' : ''}' : 'Salarié';

    Widget? primaryAction;
    if (!u.isActive) {
      primaryAction = ElevatedButton(
        onPressed: () => comptesState.valider(u),
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
        child: const Text('Valider', style: TextStyle(fontSize: 11)),
      );
    } else if (u.suspendu) {
      primaryAction = OutlinedButton(
        onPressed: () => comptesState.reactiver(u),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
        child: const Text('Réactiver', style: TextStyle(fontSize: 11)),
      );
    }

    final action = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?primaryAction,
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.acierClair),
          onSelected: (value) => _onMenuAction(context, comptesState, u, value),
          itemBuilder: (context) => [
            if (u.isActive && !u.suspendu) const PopupMenuItem(value: 'suspendre', child: Text('Suspendre')),
            const PopupMenuItem(value: 'reinit', child: Text('Réinitialiser le mot de passe')),
            if (isAdmin) const PopupMenuItem(value: 'supprimer', child: Text('Supprimer le compte')),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lignes))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => context.push('/backoffice/ca/comptes/${u.id}'),
              child: Text(
                u.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.underline),
              ),
            ),
          ),
          Expanded(flex: 3, child: Text(statutLabel, style: const TextStyle(fontSize: 11.5, color: AppColors.acier))),
          Expanded(flex: 2, child: StatusIndicator(label: compteLabel, type: compteType)),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: u.habilitations.any((h) => h.filePath != null)
                  ? () => launchUrl(Uri.parse(u.habilitations.firstWhere((h) => h.filePath != null).filePath!))
                  : null,
              child: StatusIndicator(label: habLabel, type: habType),
            ),
          ),
          Expanded(flex: 2, child: Text(mesChantiers.isEmpty ? '—' : mesChantiers, style: const TextStyle(fontSize: 11.5))),
          Expanded(flex: 2, child: action),
        ],
      ),
    );
  }
}
