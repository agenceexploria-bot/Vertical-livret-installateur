import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/coming_soon.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/user.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_shell.dart';

class BoComptesScreen extends StatelessWidget {
  const BoComptesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final comptesState = context.watch<ComptesState>();
    final chantiers = context.watch<ChantierState>().chantiers;

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
          Container(
            decoration: BoxDecoration(
              color: AppColors.blanc,
              border: Border.all(color: AppColors.lignes),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              children: [
                _headerRow(),
                for (final u in comptesState.installateurs) _dataRow(context, u, chantiers, comptesState),
              ],
            ),
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

  Widget _dataRow(BuildContext context, User u, List chantiers, ComptesState comptesState) {
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

    Widget action;
    if (!u.isActive) {
      action = ElevatedButton(
        onPressed: () => comptesState.valider(u),
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
        child: const Text('Valider', style: TextStyle(fontSize: 11)),
      );
    } else if (u.suspendu) {
      action = OutlinedButton(
        onPressed: () => comptesState.reactiver(u),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
        child: const Text('Réactiver', style: TextStyle(fontSize: 11)),
      );
    } else {
      action = OutlinedButton(
        onPressed: () => showComingSoon(context),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
        child: const Text('Réinit. mdp', style: TextStyle(fontSize: 11)),
      );
    }

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
