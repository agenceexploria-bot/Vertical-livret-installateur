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

/// Liste des chantiers d'INSTALLATION (voir module SAV, qui a sa propre liste
/// — SavListScreen) — anciennement le contenu de l'accueil installateur,
/// déplacé ici quand l'accueil est devenu les deux tuiles ("Mes chantiers" /
/// "Interventions SAV", voir InstallateurHomeScreen).
class ChantiersInstallationScreen extends StatefulWidget {
  const ChantiersInstallationScreen({super.key});

  @override
  State<ChantiersInstallationScreen> createState() => _ChantiersInstallationScreenState();
}

class _ChantiersInstallationScreenState extends State<ChantiersInstallationScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));

  @override
  void initState() {
    super.initState();
    // Redondant si on arrive depuis l'accueil (qui a déjà déclenché le
    // fetch), mais nécessaire si cet écran est atteint directement (retour
    // arrière, état restauré) — stale-while-revalidate, voir fetchChantiers.
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
    final installations = chantierState.chantiersInstallationList;
    final enCours = installations.where((c) => !c.pvSigne).toList();
    final termines = installations.where((c) => c.pvSigne).toList()
      ..sort((a, b) => (b.pvSigneAt ?? DateTime(0)).compareTo(a.pvSigneAt ?? DateTime(0)));
    final activeList = _tabController.index == 0 ? enCours : termines;

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Mes chantiers'),
        backgroundColor: AppColors.primaire,
        foregroundColor: Colors.white,
      ),
      child: Column(
        children: [
          SyncBanner(
            isOnline: networkState.isOnline,
            pendingCount: networkState.pendingCount,
            offlineUntil: offlineExpiry != null ? DateFormat('dd/MM').format(offlineExpiry) : '--',
          ),
          if (installations.isNotEmpty)
            Container(
              color: AppColors.blanc,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primaire,
                unselectedLabelColor: AppColors.acier,
                indicatorColor: AppColors.primaire,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: 'En cours (${enCours.length})'),
                  Tab(text: 'Terminés (${termines.length})'),
                ],
              ),
            ),
          Expanded(
            child: chantierState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                : installations.isEmpty
                    ? _buildEmptyState(context)
                    : activeList.isEmpty
                        ? _buildEmptyTabState(context, isTermines: _tabController.index == 1)
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: activeList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final chantier = activeList[index];
                              return _ChantierCard(chantier: chantier);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabState(BuildContext context, {required bool isTermines}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isTermines ? Icons.check_circle_outline : Icons.construction_outlined,
            size: 48,
            color: AppColors.acierClair,
          ),
          const SizedBox(height: 16),
          Text(
            isTermines ? 'Aucun chantier terminé pour l\'instant' : 'Aucun chantier en cours',
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
          const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.acierClair),
          const SizedBox(height: 16),
          Text(
            'Aucun chantier ne vous a été rattaché pour l\'instant',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre compte est actif. Dès qu\'un chargé d\'affaires vous rattachera à une affaire, elle apparaîtra ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.acier, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ChantierCard extends StatelessWidget {
  final Chantier chantier;

  const _ChantierCard({required this.chantier});

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
              Text(
                '${chantier.reference} — ${chantier.client}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Icon(Icons.chevron_right, color: AppColors.acierClair),
            ],
          ),
          const SizedBox(height: 4),
          Text(chantier.ville, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Pose du ${DateFormat('dd/MM').format(chantier.dateDebut)} au ${DateFormat('dd/MM').format(chantier.dateFin)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          // Terminé (PV signé) prime sur le statut de chargement du livret,
          // devenu secondaire une fois le chantier bouclé.
          if (chantier.pvSigne)
            const StatusIndicator(label: 'Terminé — PV signé', type: StatusType.conforme)
          else if (chantier.syncStatus == ChantierSyncStatus.charge)
            const StatusIndicator(
              label: 'Livret chargé — prêt hors-ligne',
              type: StatusType.conforme,
            )
          else
            const StatusIndicator(
              label: 'Nouveau — appuyer pour pré-charger',
              type: StatusType.enCours,
            ),
        ],
      ),
    );
  }
}
