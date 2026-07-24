import 'package:flutter/material.dart';
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
import 'widgets/pv_signature_panel.dart';

class BoQualiteScreen extends StatelessWidget {
  const BoQualiteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chantiers = context.watch<ChantierState>().chantiers;

    return BoShell(
      activeNav: 'qualite',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Auto-contrôles', style: Theme.of(context).textTheme.titleMedium),
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
                for (final c in chantiers) _dataRow(c),
              ],
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


  Widget _headerRow() {
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

  Widget _dataRow(Chantier c) {
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
}
