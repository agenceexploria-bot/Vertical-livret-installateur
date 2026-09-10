import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/sync_banner.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../state/auth_state.dart';
import '../../state/network_state.dart';
import '../../state/chantier_state.dart';
import '../../data/models/chantier.dart';

/// Liste des interventions SAV rattachées à l'installateur — même structure
/// que ChantiersInstallationScreen (deux onglets En cours/Terminées, dérivés
/// de pvSigne, ici le PV SAV), voir aussi la tuile "Interventions SAV" de
/// InstallateurHomeScreen.
class SavListScreen extends StatefulWidget {
  const SavListScreen({super.key});

  @override
  State<SavListScreen> createState() => _SavListScreenState();
}

class _SavListScreenState extends State<SavListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthState>().currentUser;
      if (user != null) {
        context.read<ChantierState>().fetchChantiers(user);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkState = context.watch<NetworkState>();
    final chantierState = context.watch<ChantierState>();
    final authState = context.watch<AuthState>();
    final offlineExpiry = authState.offlineExpiry;
    final savs = chantierState.chantiersSavList;
    final enCours = savs.where((c) => !c.pvSigne).toList();
    final terminees = savs.where((c) => c.pvSigne).toList()
      ..sort((a, b) => (b.pvSigneAt ?? DateTime(0)).compareTo(a.pvSigneAt ?? DateTime(0)));
    final activeList = _tabController.index == 0 ? enCours : terminees;

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Interventions SAV'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: Column(
        children: [
          SyncBanner(
            isOnline: networkState.isOnline,
            pendingCount: networkState.pendingCount,
            offlineUntil: offlineExpiry != null ? DateFormat('dd/MM').format(offlineExpiry) : '--',
          ),
          if (savs.isNotEmpty)
            Container(
              color: AppColors.blanc,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.orange,
                unselectedLabelColor: AppColors.acier,
                indicatorColor: AppColors.orange,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: 'En cours (${enCours.length})'),
                  Tab(text: 'Terminées (${terminees.length})'),
                ],
              ),
            ),
          Expanded(
            child: chantierState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                : savs.isEmpty
                    ? _buildEmptyState(context)
                    : activeList.isEmpty
                        ? _buildEmptyTabState(context, isTerminees: _tabController.index == 1)
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: activeList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) => _SavCard(chantier: activeList[index]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabState(BuildContext context, {required bool isTerminees}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isTerminees ? Icons.check_circle_outline : Icons.build_outlined,
            size: 48,
            color: AppColors.acierClair,
          ),
          const SizedBox(height: 16),
          Text(
            isTerminees ? 'Aucune intervention SAV terminée pour l\'instant' : 'Aucune intervention SAV en cours',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build_outlined, size: 48, color: AppColors.acierClair),
          const SizedBox(height: 16),
          Text(
            'Aucune intervention SAV ne vous a été assignée pour l\'instant',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Une intervention SAV apparaît ici dès qu\'un chargé d\'affaires vous l\'assigne depuis un chantier d\'installation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.acier, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SavCard extends StatelessWidget {
  final Chantier chantier;

  const _SavCard({required this.chantier});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        context.read<ChantierState>().selectChantier(chantier);
        context.push('/chantier/${chantier.reference}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${chantier.reference} — ${chantier.client}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.acierClair),
            ],
          ),
          const SizedBox(height: 4),
          Text('Rattaché au chantier ${chantier.parentReference ?? '—'}', style: Theme.of(context).textTheme.bodyMedium),
          if (chantier.descriptionIntervention != null) ...[
            const SizedBox(height: 4),
            Text(
              chantier.descriptionIntervention!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            chantier.savDate != null ? 'Intervention du ${DateFormat('dd/MM/yyyy').format(chantier.savDate!)}' : '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (chantier.pvSigne)
            const StatusIndicator(label: 'Terminée — PV signé', type: StatusType.conforme)
          else
            const StatusIndicator(label: 'À faire signer par le client', type: StatusType.enCours),
        ],
      ),
    );
  }
}
