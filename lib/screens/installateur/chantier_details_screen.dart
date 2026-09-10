import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/sync_banner.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../state/auth_state.dart';
import '../../state/chantier_state.dart';
import '../../state/network_state.dart';

enum ChantierModule { fiche, docsAdmin, tech, reception, autoControle, pv, rex, terrain }

/// Modules affichés sur la fiche chantier, dans l'ordre. Une intervention
/// SAV n'a ni réception marchandises, ni auto-contrôle, ni documents terrain
/// (aucun point de contrôle créé côté backend, voir POST .../sav) —
/// masqués plutôt qu'affichés vides. Pure — testable sans BuildContext ni
/// ChantierState (voir chantier_details_screen_test.dart).
const _installationModules = [
  ChantierModule.fiche,
  ChantierModule.docsAdmin,
  ChantierModule.tech,
  ChantierModule.reception,
  ChantierModule.autoControle,
  ChantierModule.pv,
  ChantierModule.rex,
  ChantierModule.terrain,
];
const _savModules = [
  ChantierModule.fiche,
  ChantierModule.docsAdmin,
  ChantierModule.tech,
  ChantierModule.pv,
  ChantierModule.rex,
];

List<ChantierModule> visibleModules(ChantierType type) => type == ChantierType.sav ? _savModules : _installationModules;

class ChantierDetailsScreen extends StatefulWidget {
  const ChantierDetailsScreen({super.key});

  @override
  State<ChantierDetailsScreen> createState() => _ChantierDetailsScreenState();
}

class _ChantierDetailsScreenState extends State<ChantierDetailsScreen> {
  bool _isLoading = false;
  String? _error;
  String? _requestedRef;

  /// Un lien direct (WhatsApp/SMS, voir bo_chantier_detail_screen.dart
  /// "Copier le lien") peut atterrir ici avant même que la liste des
  /// chantiers n'ait été chargée (l'accueil, qui déclenche normalement
  /// fetchChantiers, n'est alors jamais construit) — ou avec un
  /// currentChantier resté sur un AUTRE chantier consulté juste avant. Dans
  /// les deux cas, on va chercher CE chantier précis par sa référence plutôt
  /// que de supposer qu'il est déjà là.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ref = GoRouterState.of(context).pathParameters['ref'];
    if (ref == null || ref == _requestedRef) return;
    final chantierState = context.read<ChantierState>();
    if (chantierState.currentChantier?.reference == ref) return;
    _requestedRef = ref;
    _load(ref);
  }

  Future<void> _load(String ref) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<ChantierState>().loadChantierByReference(ref);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger ce chantier. Vérifiez votre connexion.');
      return;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final chantierState = context.watch<ChantierState>();
    final networkState = context.watch<NetworkState>();
    final offlineExpiry = context.watch<AuthState>().offlineExpiry;
    final ref = GoRouterState.of(context).pathParameters['ref'];
    final chantier = chantierState.currentChantier;

    if (_isLoading) {
      return const ResponsiveLayout(
        child: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    if (_error != null) {
      return ResponsiveLayout(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(_error!, textAlign: TextAlign.center)),
        ),
      );
    }

    if (chantier == null || (ref != null && chantier.reference != ref)) {
      return const ResponsiveLayout(
        child: Center(child: Text('Chantier introuvable')),
      );
    }

    final modules = [
      for (final (i, module) in visibleModules(chantier.type).indexed)
        _buildModuleItem(context, module, index: i + 1, chantier: chantier),
    ];

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: Text('${chantier.reference} — ${chantier.client}'),
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
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: modules.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _ModuleCard(item: modules[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  _ModuleItem _buildModuleItem(BuildContext context, ChantierModule module, {required int index, required Chantier chantier}) {
    switch (module) {
      case ChantierModule.fiche:
        return _ModuleItem(
          index: index,
          titre: 'Fiche chantier',
          sousTitre: 'Consignes et contacts',
          icon: Icons.info_outline,
          onTap: () => context.push('/chantier/${chantier.reference}/fiche'),
        );
      case ChantierModule.docsAdmin:
        return _ModuleItem(
          index: index,
          titre: 'Documents administratifs',
          sousTitre: 'Sécurité et accès',
          icon: Icons.assignment_outlined,
          onTap: () => context.push('/chantier/${chantier.reference}/docs-admin'),
        );
      case ChantierModule.tech:
        return _ModuleItem(
          index: index,
          titre: 'Dossier technique',
          sousTitre: 'Plans et notices',
          icon: Icons.architecture_outlined,
          onTap: () => context.push('/chantier/${chantier.reference}/tech'),
        );
      case ChantierModule.reception:
        return _ModuleItem(
          index: index,
          titre: 'Réception marchandises',
          sousTitre: '${(chantier.progressionReception * 100).toInt()}% complété',
          icon: Icons.inventory_2_outlined,
          onTap: () => context.push('/chantier/${chantier.reference}/reception'),
        );
      case ChantierModule.autoControle:
        return _ModuleItem(
          index: index,
          titre: 'Auto-contrôle',
          sousTitre: '${(chantier.progressionAutoControle * 100).toInt()}% complété',
          icon: Icons.fact_check_outlined,
          onTap: () => context.push('/chantier/${chantier.reference}/auto-controle'),
        );
      case ChantierModule.pv:
        final isSav = chantier.type == ChantierType.sav;
        return _ModuleItem(
          index: index,
          titre: isSav ? 'Procès-verbal d\'intervention' : 'Procès-verbal de réception',
          // Accessible en permanence, dès le premier jour du chantier, quel
          // que soit l'avancement de l'auto-contrôle (décision métier
          // confirmée 2026-09-01) — seul un PV déjà signé change ce
          // libellé/la destination (voir onTap ci-dessous, /confirmation en
          // lecture seule).
          sousTitre: chantier.pvSigne ? 'Signé par ${chantier.pvSigneur ?? 'le client'}' : 'À faire signer par le client',
          icon: Icons.draw_outlined,
          // pvPdfPath == null signale le nouveau flux (formulaire
          // interactif, aucun gabarit à attendre du back-office) — voir la
          // refonte du PV. Une intervention SAV n'a jamais de gabarit
          // déposé : uniquement le formulaire allégé /pv-sav-formulaire.
          onTap: () => context.push(chantier.pvSigne
              ? '/confirmation'
              : isSav
                  ? '/pv-sav-formulaire'
                  : chantier.pvPdfPath != null ? '/signature' : '/pv-formulaire'),
        );
      case ChantierModule.rex:
        return _ModuleItem(
          index: index,
          titre: 'Retour d\'expérience',
          sousTitre: chantier.rex.isEmpty ? 'À saisir' : '${chantier.rex.length} envoyé(s)',
          icon: Icons.mic_none_outlined,
          onTap: () => context.push('/chantier/${chantier.reference}/rex'),
        );
      case ChantierModule.terrain:
        return _ModuleItem(
          index: index,
          titre: 'Documents terrain',
          sousTitre: 'Photos et bons de livraison',
          icon: Icons.camera_alt_outlined,
          onTap: () => context.push('/chantier/${chantier.reference}/terrain'),
        );
    }
  }
}

class _ModuleItem {
  final int index;
  final String titre;
  final String sousTitre;
  final IconData icon;
  final VoidCallback? onTap;

  _ModuleItem({
    required this.index,
    required this.titre,
    required this.sousTitre,
    required this.icon,
    this.onTap,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;

  const _ModuleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: item.onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 48,
              decoration: const BoxDecoration(
                color: AppColors.fond,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(9),
                  bottomLeft: Radius.circular(9),
                ),
              ),
              child: Center(
                child: Text(
                  item.index.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.acier,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.titre,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.sousTitre,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.acier),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(Icons.chevron_right, color: AppColors.acierClair),
            ),
          ],
        ),
      ),
    );
  }
}
