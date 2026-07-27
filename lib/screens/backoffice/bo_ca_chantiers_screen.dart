import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/chantier.dart';
import '../../data/models/point_controle.dart';
import '../../data/models/user.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';
import 'widgets/bo_responsive_table.dart';
import 'widgets/pv_signature_panel.dart';

/// Espace Chargé d'Affaires — gestion des chantiers (création, suivi, PV
/// signés pour facturation), validation des installateurs, et — depuis la
/// fusion du rôle Qualité dans cet espace — auto-contrôles, REX à qualifier,
/// anomalies et habilitations.
class BoCaChantiersScreen extends StatelessWidget {
  const BoCaChantiersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chantiers = context.watch<ChantierState>().chantiers;

    return BoShell(
      activeNav: 'chantiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
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
          const SizedBox(height: 20),
          Text('Auto-contrôles & qualité', style: Theme.of(context).textTheme.titleMedium),
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
                  _qualiteHeaderRow(),
                  for (final c in chantiers) _qualiteDataRow(c),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          BoPanel(
            title: 'File REX — à qualifier',
            child: () {
              final rexs = chantiers.where((c) => c.rexValide && c.rexTranscription != null).toList();
              if (rexs.isEmpty) {
                return const Text('Aucun REX en attente de qualification.', style: TextStyle(fontSize: 11, color: AppColors.acierClair));
              }
              return Column(children: [for (final c in rexs) _rexRow(c)]);
            }(),
          ),
          const SizedBox(height: 12),
          _buildPvSignes(context, chantiers),
          const SizedBox(height: 12),
          _buildAnomalies(chantiers),
          const SizedBox(height: 12),
          _buildHabilitations(context),
        ],
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
        BoResponsiveTable(
          minWidth: 600,
          child: Container(
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

  // ---- Ex-espace Qualité, fusionné ici : auto-contrôles, REX, anomalies, habilitations ----

  Widget _qualiteHeaderRow() {
    const style = TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.acier, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFFEDF0F2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('AFFAIRE', style: style)),
          Expanded(flex: 3, child: Text('CONFORMITÉ', style: style)),
          Expanded(flex: 4, child: Text('SIGNÉ PAR (COMPTE)', style: style)),
          Expanded(flex: 3, child: Text('DOCS TERRAIN', style: style)),
        ],
      ),
    );
  }

  Widget _qualiteDataRow(Chantier c) {
    final total = c.autoControle.length;
    final done = c.autoControle.where((p) => p.isComplete).length;
    final (label, type) = c.pvSigne || done == total
        ? ('$done/$total', StatusType.conforme)
        : done > 0
            ? ('$done/$total — en cours', StatusType.enCours)
            : ('$done/$total', StatusType.attente);

    final signataire = c.installateursRattaches.isNotEmpty
        ? '${c.installateursRattaches.first.fullName}${c.pvSigne ? ' · ${DateFormat('dd/MM').format(c.dateFin)}' : ''}'
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.lignes))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(c.reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 3, child: StatusIndicator(label: label, type: type)),
          Expanded(flex: 4, child: Text(signataire, style: const TextStyle(fontSize: 11.5))),
          Expanded(flex: 3, child: Text(c.docsTerrain.isEmpty ? '—' : '${c.docsTerrain.length} document(s)', style: const TextStyle(fontSize: 11.5))),
        ],
      ),
    );
  }

  Widget _rexRow(Chantier c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${c.reference}${c.installateursRattaches.isNotEmpty ? ' · ${c.installateursRattaches.first.fullName}' : ''} — « ${c.rexTranscription} »',
              style: const TextStyle(fontSize: 10.5, color: AppColors.acier),
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
          ? const Text('Aucun PV signé pour l\'instant.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
          : Column(children: [for (final c in signes) _pvRow(context, c)]),
    );
  }

  Widget _pvRow(BuildContext context, Chantier c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${c.reference} — ${c.client}'),
            content: SizedBox(
              width: 360,
              child: PvSignaturePanel(
                signataire: c.pvSigneur,
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
              child: Text('${c.reference} · ${c.client}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            Text(
              c.pvSigneAt != null
                  ? 'Signé par ${c.pvSigneur ?? 'le client'} · ${DateFormat('dd/MM HH:mm').format(c.pvSigneAt!)}'
                  : '—',
              style: const TextStyle(fontSize: 10.5, color: AppColors.acierClair),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.acierClair),
          ],
        ),
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
          ? const Text('Aucune anomalie en cours.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
          : Column(children: [for (final (c, p) in anomalies) _anomalieRow(c, p)]),
    );
  }

  Widget _anomalieRow(Chantier c, PointControle p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.rouge, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.reference} · ${c.client} — ${p.libelle}${p.critique ? ' (sécurité)' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.acier, fontWeight: FontWeight.w600),
                ),
                if (p.validePar != null && p.valideAt != null)
                  Text(
                    'Signalé par ${p.validePar} · ${DateFormat('dd/MM HH:mm').format(p.valideAt!)}',
                    style: const TextStyle(fontSize: 10, color: AppColors.acierClair),
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
          ? const Text('Aucune habilitation enregistrée.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
          : Column(children: [for (final (u, h) in rows) _habilitationRow(u, h)]),
    );
  }

  Widget _habilitationRow(User u, Habilitation h) {
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
            flex: 3,
            child: Text(u.fullName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${h.titre} · ${DateFormat('dd/MM/yyyy').format(h.dateExpiration)}',
              style: const TextStyle(fontSize: 11, color: AppColors.acier),
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
