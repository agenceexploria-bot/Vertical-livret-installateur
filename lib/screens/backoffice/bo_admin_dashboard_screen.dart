import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/dashboard_stat_card.dart';
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

    final enAttente = adminState.comptesInternes.where((u) => !u.isActive).toList();

    return BoShell(
      activeNav: 'admin',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Administration', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          if (adminState.isLoading && feed == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            _buildStatsGrid(enAttente.length, feed),
            const SizedBox(height: 24),
            _buildComptesInternes(adminState, enAttente),
            const SizedBox(height: 16),
            _buildWeeklyChart(adminState.weeklyStats),
            const SizedBox(height: 16),
            _buildAnomalies(feed),
            const SizedBox(height: 16),
            _buildPvRecents(feed),
            const SizedBox(height: 16),
            _buildRexEnAttente(feed),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid(int comptesEnAttente, ActivityFeed? feed) {
    final anomalies = feed?.anomalies.length ?? 0;
    final pvEnAttenteFacturation = feed?.pvRecents.length ?? 0;
    final rexEnAttente = feed?.rexEnAttente.length ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 560 ? 2 : 1);
        final cards = [
          DashboardStatCard(
            icon: Icons.how_to_reg_outlined,
            value: '$comptesEnAttente',
            label: 'Comptes internes à valider',
            color: AppColors.orange,
            urgent: comptesEnAttente > 0,
          ),
          DashboardStatCard(
            icon: Icons.warning_amber_rounded,
            value: '$anomalies',
            label: 'Anomalies signalées',
            color: AppColors.rouge,
            urgent: anomalies > 0,
          ),
          DashboardStatCard(
            icon: Icons.receipt_long_outlined,
            value: '$pvEnAttenteFacturation',
            label: 'PV à facturer',
            color: AppColors.vert,
          ),
          DashboardStatCard(
            icon: Icons.record_voice_over_outlined,
            value: '$rexEnAttente',
            label: 'REX à traiter',
            color: AppColors.acier,
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

  Widget _buildComptesInternes(AdminState adminState, List<User> enAttente) {
    return BoPanel(
      title: 'Comptes internes en attente de validation (${enAttente.length})',
      child: enAttente.isEmpty
          ? const Text('Aucune demande en attente.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(children: [for (final u in enAttente) _compteRow(adminState, u)]),
    );
  }

  Widget _compteRow(AdminState adminState, User u) {
    final roleLabel = u.role == UserRole.chargeAffaires ? 'Chargé d\'affaires' : 'Qualité';
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 10),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('$roleLabel · ${u.email ?? ''}', style: const TextStyle(fontSize: 11.5, color: AppColors.acierClair)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => adminState.validerCompteInterne(u),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Valider'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(List<WeeklyStat> weeks) {
    return BoPanel(
      title: 'Activité par semaine (8 dernières semaines)',
      child: weeks.isEmpty
          ? const Text('Pas encore de données.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
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
          ? const Text('Aucune anomalie en cours.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(children: [for (final a in anomalies) _anomalieRow(a)]),
    );
  }

  Widget _anomalieRow(AnomalieSignalee a) {
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
                  '${a.chantierReference} · ${a.client} — ${a.libelle}${a.critique ? ' (sécurité)' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.acier, fontWeight: FontWeight.w600),
                ),
                if (a.validePar != null && a.valideAt != null)
                  Text(
                    'Signalé par ${a.validePar} · ${DateFormat('dd/MM HH:mm').format(a.valideAt!)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
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
          ? const Text('Aucun PV signé récemment.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(children: [for (final pv in pvRecents) _pvRow(context, pv)]),
    );
  }

  Widget _pvRow(BuildContext context, PvRecent pv) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      onTap: () => showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${pv.chantierReference} — ${pv.client}'),
          content: SizedBox(
            width: 360,
            child: PvSignaturePanel(
              signataire: pv.pvSigneur,
              fonction: pv.pvFonctionSignataire,
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
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            pv.pvSigneAt != null
                ? 'Signé par ${pv.pvSigneur ?? 'le client'} · ${DateFormat('dd/MM HH:mm').format(pv.pvSigneAt!)}'
                : '—',
            style: const TextStyle(fontSize: 11.5, color: AppColors.acierClair),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.acierClair),
        ],
      ),
    );
  }

  Widget _buildRexEnAttente(ActivityFeed? feed) {
    final rexEnAttente = feed?.rexEnAttente ?? const <RexEnAttente>[];
    return BoPanel(
      title: 'REX reçus — en attente de traitement BE/Qualité (${rexEnAttente.length})',
      child: rexEnAttente.isEmpty
          ? const Text('Aucun REX en attente.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(children: [for (final rex in rexEnAttente) _rexRow(rex)]),
    );
  }

  Widget _rexRow(RexEnAttente rex) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Text(
        '${rex.chantierReference} · ${rex.client} — « ${rex.rexTranscription} »',
        style: const TextStyle(fontSize: 12, color: AppColors.acier),
      ),
    );
  }
}
