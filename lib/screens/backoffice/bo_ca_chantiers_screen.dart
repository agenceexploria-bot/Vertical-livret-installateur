import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets/dashboard_stat_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/chantier.dart';
import '../../data/models/point_controle.dart';
import '../../data/models/user.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';
import 'widgets/bo_responsive_table.dart';
import 'widgets/bo_table_row.dart';
import 'widgets/pv_signature_panel.dart';

/// Espace Chargé d'Affaires — gestion des chantiers (création, suivi, PV
/// signés pour facturation), validation des installateurs, et — depuis la
/// fusion du rôle Qualité dans cet espace — auto-contrôles, REX à qualifier,
/// anomalies et habilitations.
class BoCaChantiersScreen extends StatefulWidget {
  const BoCaChantiersScreen({super.key});

  @override
  State<BoCaChantiersScreen> createState() => _BoCaChantiersScreenState();
}

class _BoCaChantiersScreenState extends State<BoCaChantiersScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chantiers = context.watch<ChantierState>().chantiers;

    final query = _search.trim().toLowerCase();
    final filteredChantiers = query.isEmpty
        ? chantiers
        : chantiers.where((c) => c.reference.toLowerCase().contains(query) || c.client.toLowerCase().contains(query)).toList();

    return BoShell(
      activeNav: 'chantiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(context, chantiers),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final table = _buildTable(context, filteredChantiers, query.isNotEmpty);
              final sidePanel = _buildSidePanel(context);

              if (!isWide) {
                return Column(children: [table, const SizedBox(height: 20), sidePanel]);
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 16, child: table),
                  const SizedBox(width: 24),
                  Expanded(flex: 10, child: sidePanel),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildPvSignes(context, chantiers),
          const SizedBox(height: 16),
          _buildAnomalies(chantiers),
          const SizedBox(height: 16),
          _buildHabilitations(context),
        ],
      ),
    );
  }

  /// Vue d'ensemble en un coup d'œil, au-dessus du détail — les compteurs
  /// urgents (anomalies, éléments à traiter) sont mis en évidence par un
  /// point orange (voir [DashboardStatCard.urgent]).
  Widget _buildStatsGrid(BuildContext context, List<Chantier> chantiers) {
    final comptesState = context.watch<ComptesState>();
    final enCours = chantiers.where((c) => !c.pvSigne).length;
    final pvSignes = chantiers.where((c) => c.pvSigne).length;
    final anomalies = chantiers
        .expand((c) => [...c.receptionMarchandises, ...c.autoControle])
        .where((p) => p.status == PointStatus.nonConforme)
        .length;
    final aTraiter = comptesState.installateurs.where((u) => !u.isActive).length +
        chantiers.expand((c) => c.installateursRattaches.where((u) => !c.livretsOuverts.contains(u.id))).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 560 ? 2 : 1);
        final cards = [
          DashboardStatCard(icon: Icons.construction_outlined, value: '$enCours', label: 'Chantiers en cours', color: AppColors.acier),
          DashboardStatCard(icon: Icons.verified_outlined, value: '$pvSignes', label: 'PV signés', color: AppColors.vert),
          DashboardStatCard(
            icon: Icons.warning_amber_rounded,
            value: '$anomalies',
            label: 'Anomalies signalées',
            color: AppColors.rouge,
            urgent: anomalies > 0,
          ),
          DashboardStatCard(
            icon: Icons.pending_actions_outlined,
            value: '$aTraiter',
            label: 'Éléments à traiter',
            color: AppColors.orange,
            urgent: aTraiter > 0,
          ),
        ];
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.6,
          children: cards,
        );
      },
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

  Widget _buildTable(BuildContext context, List<Chantier> chantiers, bool isSearching) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Chantiers en cours', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  hintText: 'Réf. ERP ou client...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/backoffice/ca/chantiers/nouveau'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Nouveau chantier'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 20)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (chantiers.isEmpty)
          BoPanel(
            child: EmptyState(
              icon: Icons.construction_outlined,
              message: isSearching ? 'Aucun résultat pour « ${_search.trim()} ».' : 'Aucun chantier en cours pour l\'instant.',
              actionLabel: isSearching ? null : 'Créer un nouveau chantier',
              onAction: isSearching ? null : () => context.push('/backoffice/ca/chantiers/nouveau'),
            ),
          )
        else
          BoResponsiveTable(
            minWidth: 600,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.blanc,
                border: Border.all(color: AppColors.lignes),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: AppColors.encre.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _headerRow(),
                  for (final (i, c) in chantiers.indexed) _dataRow(context, c, i),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _headerRow() {
    const style = TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.acier, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFFEDF0F2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  Widget _dataRow(BuildContext context, Chantier c, int index) {
    final livret = _livretBadge(c);
    final pv = _pvBadge(c);
    return BoTableRow(
      onTap: () => context.push('/backoffice/ca/chantiers/${c.reference}'),
      border: const Border(top: BorderSide(color: AppColors.lignes)),
      backgroundColor: index.isOdd ? const Color(0xFFF7F8F9) : null,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(c.reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(flex: 3, child: Text(c.client, style: const TextStyle(fontSize: 13))),
          Expanded(flex: 2, child: Text(DateFormat('dd/MM').format(c.dateDebut), style: const TextStyle(fontSize: 13))),
          Expanded(flex: 4, child: StatusBadge(label: livret.$1, type: livret.$2)),
          Expanded(flex: 4, child: StatusBadge(label: pv.$1, type: pv.$2)),
        ],
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

    // Fond légèrement teinté dès qu'il y a des éléments à traiter — pour que
    // ce panneau attire l'œil en priorité, comme demandé pour les actions
    // urgentes du CA.
    return Container(
      decoration: items.isNotEmpty
          ? BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)))
          : null,
      child: BoPanel(
        title: 'À traiter (${items.length})',
        child: items.isEmpty
            ? const Text('Rien à signaler.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
            : Column(children: items),
      ),
    );
  }

  Widget _notif(StatusType type, String prefix, String bold) {
    final color = type == StatusType.nonConforme
        ? AppColors.rouge
        : type == StatusType.enCours
            ? AppColors.orange
            : AppColors.acierClair;
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: AppColors.acier),
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

  Widget _buildPvSignes(BuildContext context, List<Chantier> chantiers) {
    final signes = chantiers.where((c) => c.pvSigne).toList();
    return BoPanel(
      title: 'PV signés (${signes.length})',
      child: signes.isEmpty
          ? const Text('Aucun PV signé pour l\'instant.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(children: [for (final c in signes) _pvRow(context, c)]),
    );
  }

  Widget _pvRow(BuildContext context, Chantier c) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      onTap: () => showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${c.reference} — ${c.client}'),
          content: SizedBox(
            width: 360,
            child: PvSignaturePanel(
              signataire: c.pvSigneur,
              fonction: c.pvFonctionSignataire,
              signeAt: c.pvSigneAt,
              signatureImagePath: c.pvSignatureImagePath,
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer'))],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('${c.reference} · ${c.client}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          Text(
            c.pvSigneAt != null
                ? 'Signé par ${c.pvSigneur ?? 'le client'} · ${DateFormat('dd/MM HH:mm').format(c.pvSigneAt!)}'
                : '—',
            style: const TextStyle(fontSize: 11.5, color: AppColors.acierClair),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.acierClair),
        ],
      ),
    );
  }

  Widget _buildAnomalies(List<Chantier> chantiers) {
    final anomalies = <(Chantier, PointControle)>[];
    for (final c in chantiers) {
      for (final p in [...c.receptionMarchandises, ...c.autoControle]) {
        if (p.status == PointStatus.nonConforme) anomalies.add((c, p));
      }
    }

    return BoPanel(
      title: 'Anomalies signalées (${anomalies.length})',
      child: anomalies.isEmpty
          ? const Text('Aucune anomalie en cours.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(children: [for (final (c, p) in anomalies) _anomalieRow(c, p)]),
    );
  }

  Widget _anomalieRow(Chantier c, PointControle p) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.rouge, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.reference} · ${c.client} — ${p.libelle}${p.critique ? ' (sécurité)' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.acier, fontWeight: FontWeight.w600),
                ),
                if (p.validePar != null && p.valideAt != null)
                  Text(
                    'Signalé par ${p.validePar} · ${DateFormat('dd/MM HH:mm').format(p.valideAt!)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabilitations(BuildContext context) {
    final installateurs = context.watch<ComptesState>().installateurs;
    final rows = <(User, Habilitation)>[
      for (final u in installateurs)
        for (final h in u.habilitations) (u, h),
    ];

    return BoPanel(
      title: 'Habilitations (${rows.length})',
      child: rows.isEmpty
          ? const Text('Aucune habilitation enregistrée.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(children: [for (final (u, h) in rows) _habilitationRow(u, h)]),
    );
  }

  Widget _habilitationRow(User u, Habilitation h) {
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
            flex: 3,
            child: Text(u.fullName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${h.titre} · ${DateFormat('dd/MM/yyyy').format(h.dateExpiration)}',
              style: const TextStyle(fontSize: 12, color: AppColors.acier),
            ),
          ),
          StatusIndicator(label: label, type: type),
          if (h.filePath != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => launchUrl(Uri.parse(h.filePath!)),
              style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Voir', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
