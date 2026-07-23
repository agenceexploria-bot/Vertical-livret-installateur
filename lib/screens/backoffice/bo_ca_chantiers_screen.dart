import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/chantier.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';

/// Espace Chargé d'Affaires — gestion des chantiers (création, suivi, PV
/// signés pour facturation) et validation des installateurs. Les anomalies et
/// habilitations relèvent de l'espace Qualité, pas de celui-ci.
class BoCaChantiersScreen extends StatelessWidget {
  const BoCaChantiersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BoShell(
      activeNav: 'chantiers',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          final table = _buildTable(context);
          final sidePanel = _buildSidePanel(context);

          if (!isWide) {
            return Column(children: [table, const SizedBox(height: 16), sidePanel]);
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 16, child: table),
              const SizedBox(width: 20),
              Expanded(flex: 10, child: sidePanel),
            ],
          );
        },
      ),
    );
  }

  (String, StatusType) _livretBadge(Chantier c) {
    if (c.pvSigne) return ('Terminé', StatusType.conforme);
    if (c.progressionAutoControle > 0 || c.progressionReception > 0) return ('Pose en cours', StatusType.enCours);
    if (c.installateursRattaches.isEmpty) return ('Non rattaché', StatusType.nonConforme);
    return ('Prêt', StatusType.conforme);
  }

  (String, StatusType) _pvBadge(Chantier c) {
    if (c.pvSigne) return ('Signé — facturer dans l\'ERP', StatusType.conforme);
    return ('—', StatusType.factuel);
  }

  Widget _buildTable(BuildContext context) {
    final chantiers = context.watch<ChantierState>().chantiers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Chantiers en cours', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.push('/backoffice/ca/chantiers/nouveau'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('+ Nouveau chantier', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.blanc,
            border: Border.all(color: AppColors.lignes),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            children: [
              _headerRow(),
              for (final c in chantiers) _dataRow(context, c),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerRow() {
    const style = TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.acier, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFFEDF0F2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('AFFAIRE (RÉF. ERP)', style: style)),
          Expanded(flex: 3, child: Text('CLIENT', style: style)),
          Expanded(flex: 2, child: Text('POSE', style: style)),
          Expanded(flex: 4, child: Text('LIVRET', style: style)),
          Expanded(flex: 4, child: Text('PV', style: style)),
        ],
      ),
    );
  }

  Widget _dataRow(BuildContext context, Chantier c) {
    final livret = _livretBadge(c);
    final pv = _pvBadge(c);
    return InkWell(
      onTap: () => context.push('/backoffice/ca/chantiers/${c.reference}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lignes))),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(c.reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            Expanded(flex: 3, child: Text(c.client, style: const TextStyle(fontSize: 12))),
            Expanded(flex: 2, child: Text(DateFormat('dd/MM').format(c.dateDebut), style: const TextStyle(fontSize: 12))),
            Expanded(flex: 4, child: StatusIndicator(label: livret.$1, type: livret.$2)),
            Expanded(flex: 4, child: StatusIndicator(label: pv.$1, type: pv.$2)),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    final comptesState = context.watch<ComptesState>();
    final chantiers = context.watch<ChantierState>().chantiers;

    final pendingAccounts = comptesState.installateurs.where((u) => !u.isActive).toList();
    final unopenedLivrets = <(Chantier, String)>[];
    for (final c in chantiers) {
      for (final u in c.installateursRattaches) {
        if (!c.livretsOuverts.contains(u.id)) unopenedLivrets.add((c, u.fullName));
      }
    }

    final items = <Widget>[
      for (final u in pendingAccounts) _notif(StatusType.enCours, 'Inscription à valider : ', u.fullName),
      for (final (c, nom) in unopenedLivrets) _notif(StatusType.nonConforme, '${c.reference} : ', '$nom n\'a pas ouvert son livret'),
    ];

    return BoPanel(
      title: 'À traiter (${items.length})',
      child: items.isEmpty
          ? const Text('Rien à signaler.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
          : Column(children: items),
    );
  }

  Widget _notif(StatusType type, String prefix, String bold) {
    final color = type == StatusType.nonConforme
        ? AppColors.rouge
        : type == StatusType.enCours
            ? AppColors.orange
            : AppColors.acierClair;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 10.5, color: AppColors.acier),
                children: [
                  TextSpan(text: prefix),
                  TextSpan(text: bold, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.encre)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
