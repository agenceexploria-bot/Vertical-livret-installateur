import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/activity_feed.dart';
import '../../data/models/user.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';
import 'widgets/bo_table_row.dart';
import 'widgets/pv_signature_panel.dart';

class BoAdminDashboardScreen extends StatefulWidget {
  const BoAdminDashboardScreen({super.key});

  @override
  State<BoAdminDashboardScreen> createState() => _BoAdminDashboardScreenState();
}

class _BoAdminDashboardScreenState extends State<BoAdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminState>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    // Écran réservé au rôle admin — un CA/Qualité qui naviguerait ici
    // directement (URL tapée à la main) est renvoyé au tableau de bord.
    if (!authState.isLoading && authState.currentUser?.role != UserRole.admin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/backoffice');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final adminState = context.watch<AdminState>();
    final feed = adminState.activityFeed;

    return BoShell(
      activeNav: 'admin',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Administration', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          _buildComptesInternes(adminState),
          const SizedBox(height: 12),
          if (adminState.isLoading && feed == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            _buildWeeklyChart(adminState.weeklyStats),
            const SizedBox(height: 12),
            _buildAnomalies(feed),
            const SizedBox(height: 12),
            _buildPvRecents(feed),
            const SizedBox(height: 12),
            _buildRexEnAttente(feed),
          ],
        ],
      ),
    );
  }

  Widget _buildComptesInternes(AdminState adminState) {
    final enAttente = adminState.comptesInternes.where((u) => !u.isActive).toList();
    return BoPanel(
      title: 'Comptes internes en attente de validation (${enAttente.length})',
      child: enAttente.isEmpty
          ? const Text('Aucune demande en attente.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
          : Column(children: [for (final u in enAttente) _compteRow(adminState, u)]),
    );
  }

  Widget _compteRow(AdminState adminState, User u) {
    final roleLabel = u.role == UserRole.chargeAffaires ? 'Chargé d\'affaires' : 'Qualité';
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 8),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('$roleLabel · ${u.email ?? ''}', style: const TextStyle(fontSize: 10.5, color: AppColors.acierClair)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => adminState.validerCompteInterne(u),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: const Text('Valider', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(List<WeeklyStat> weeks) {
    return BoPanel(
      title: 'Activité par semaine (8 dernières semaines)',
      child: weeks.isEmpty
          ? const Text('Pas encore de données.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= weeks.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat('dd/MM').format(weeks[i].weekStart),
                                  style: const TextStyle(fontSize: 9, color: AppColors.acierClair),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < weeks.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(toY: weeks[i].pvSignes.toDouble(), color: AppColors.vert, width: 6),
                              BarChartRodData(toY: weeks[i].rexSoumis.toDouble(), color: AppColors.orange, width: 6),
                              BarChartRodData(toY: weeks[i].anomalies.toDouble(), color: AppColors.rouge, width: 6),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _legendDot(AppColors.vert, 'PV signés'),
                    const SizedBox(width: 16),
                    _legendDot(AppColors.orange, 'REX soumis'),
                    const SizedBox(width: 16),
                    _legendDot(AppColors.rouge, 'Anomalies'),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.acier)),
      ],
    );
  }

  Widget _buildAnomalies(ActivityFeed? feed) {
    final anomalies = feed?.anomalies ?? const <AnomalieSignalee>[];
    return BoPanel(
      title: 'Anomalies signalées (${anomalies.length})',
      child: anomalies.isEmpty
          ? const Text('Aucune anomalie en cours.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
          : Column(children: [for (final a in anomalies) _anomalieRow(a)]),
    );
  }

  Widget _anomalieRow(AnomalieSignalee a) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 6),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
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
                  '${a.chantierReference} · ${a.client} — ${a.libelle}${a.critique ? ' (sécurité)' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.acier, fontWeight: FontWeight.w600),
                ),
                if (a.validePar != null && a.valideAt != null)
                  Text(
                    'Signalé par ${a.validePar} · ${DateFormat('dd/MM HH:mm').format(a.valideAt!)}',
                    style: const TextStyle(fontSize: 10, color: AppColors.acierClair),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPvRecents(ActivityFeed? feed) {
    final pvRecents = feed?.pvRecents ?? const <PvRecent>[];
    return BoPanel(
      title: 'PV signés récemment — en attente de facturation (${pvRecents.length})',
      child: pvRecents.isEmpty
          ? const Text('Aucun PV signé récemment.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
          : Column(children: [for (final pv in pvRecents) _pvRow(context, pv)]),
    );
  }

  Widget _pvRow(BuildContext context, PvRecent pv) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 6),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      onTap: () => showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${pv.chantierReference} — ${pv.client}'),
          content: SizedBox(
            width: 360,
            child: PvSignaturePanel(
              signataire: pv.pvSigneur,
              signeAt: pv.pvSigneAt,
              signatureImagePath: pv.pvSignatureImagePath,
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer'))],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${pv.chantierReference} · ${pv.client}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            pv.pvSigneAt != null
                ? 'Signé par ${pv.pvSigneur ?? 'le client'} · ${DateFormat('dd/MM HH:mm').format(pv.pvSigneAt!)}'
                : '—',
            style: const TextStyle(fontSize: 10.5, color: AppColors.acierClair),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.acierClair),
        ],
      ),
    );
  }

  Widget _buildRexEnAttente(ActivityFeed? feed) {
    final rexEnAttente = feed?.rexEnAttente ?? const <RexEnAttente>[];
    return BoPanel(
      title: 'REX reçus — en attente de traitement BE/Qualité (${rexEnAttente.length})',
      child: rexEnAttente.isEmpty
          ? const Text('Aucun REX en attente.', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
          : Column(children: [for (final rex in rexEnAttente) _rexRow(rex)]),
    );
  }

  Widget _rexRow(RexEnAttente rex) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 6),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Text(
        '${rex.chantierReference} · ${rex.client} — « ${rex.rexTranscription} »',
        style: const TextStyle(fontSize: 10.5, color: AppColors.acier),
      ),
    );
  }
}
