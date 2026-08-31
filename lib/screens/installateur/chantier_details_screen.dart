import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/sync_banner.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../state/auth_state.dart';
import '../../state/chantier_state.dart';
import '../../state/network_state.dart';

class ChantierDetailsScreen extends StatelessWidget {
  const ChantierDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chantierState = context.watch<ChantierState>();
    final networkState = context.watch<NetworkState>();
    final offlineExpiry = context.watch<AuthState>().offlineExpiry;
    final chantier = chantierState.currentChantier;

    if (chantier == null) {
      return const ResponsiveLayout(
        child: Center(child: Text('Chantier introuvable')),
      );
    }

    final List<_ModuleItem> modules = [
      _ModuleItem(
        index: 1,
        titre: 'Fiche chantier',
        sousTitre: 'Consignes et contacts',
        icon: Icons.info_outline,
        onTap: () => context.push('/chantier/${chantier.reference}/fiche'),
      ),
      _ModuleItem(
        index: 2,
        titre: 'Documents administratifs',
        sousTitre: 'Sécurité et accès',
        icon: Icons.assignment_outlined,
        onTap: () => context.push('/chantier/${chantier.reference}/docs-admin'),
      ),
      _ModuleItem(
        index: 3,
        titre: 'Dossier technique',
        sousTitre: 'Plans et notices',
        icon: Icons.architecture_outlined,
        onTap: () => context.push('/chantier/${chantier.reference}/tech'),
      ),
      _ModuleItem(
        index: 4,
        titre: 'Réception marchandises',
        sousTitre: '${(chantier.progressionReception * 100).toInt()}% complété',
        icon: Icons.inventory_2_outlined,
        onTap: () => context.push('/chantier/${chantier.reference}/reception'),
      ),
      _ModuleItem(
        index: 5,
        titre: 'Auto-contrôle',
        sousTitre: '${(chantier.progressionAutoControle * 100).toInt()}% complété',
        icon: Icons.fact_check_outlined,
        onTap: () => context.push('/chantier/${chantier.reference}/auto-controle'),
      ),
      _ModuleItem(
        index: 6,
        titre: 'Procès-verbal de réception',
        // pvPdfPath == null signale le nouveau flux (formulaire interactif,
        // aucun gabarit à attendre du back-office) — voir la refonte du PV.
        sousTitre: chantier.pvSigne
            ? 'Signé par ${chantier.pvSigneur ?? 'le client'}'
            : chantier.pvEnAttenteSignature
                ? 'À faire signer par le client'
                : chantier.canSignPV
                    ? 'À faire signer par le client'
                    : 'Verrouillé — terminer l\'auto-contrôle',
        icon: Icons.draw_outlined,
        isLocked: !chantier.pvSigne && !chantier.canSignPV && !chantier.pvEnAttenteSignature,
        onTap: () => context.push(chantier.pvSigne
            ? '/confirmation'
            : chantier.pvPdfPath != null ? '/signature' : '/pv-formulaire'),
      ),
      _ModuleItem(
        index: 7,
        titre: 'Retour d\'expérience',
        sousTitre: chantier.rex.isEmpty ? 'À saisir' : '${chantier.rex.length} envoyé(s)',
        icon: Icons.mic_none_outlined,
        onTap: () => context.push('/chantier/${chantier.reference}/rex'),
      ),
      _ModuleItem(
        index: 8,
        titre: 'Documents terrain',
        sousTitre: 'Photos et bons de livraison',
        icon: Icons.camera_alt_outlined,
        onTap: () => context.push('/chantier/${chantier.reference}/terrain'),
      ),
    ];

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: Text('${chantier.reference} — ${chantier.client}'),
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
}

class _ModuleItem {
  final int index;
  final String titre;
  final String sousTitre;
  final IconData icon;
  final bool isLocked;
  final VoidCallback? onTap;

  _ModuleItem({
    required this.index,
    required this.titre,
    required this.sousTitre,
    required this.icon,
    this.isLocked = false,
    this.onTap,
  });
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;

  const _ModuleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: item.isLocked ? null : item.onTap,
      padding: EdgeInsets.zero,
      child: Opacity(
        opacity: item.isLocked ? 0.5 : 1.0,
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: item.isLocked ? AppColors.rouge : AppColors.acier,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Icon(
                  item.isLocked ? Icons.lock_outline : Icons.chevron_right,
                  color: AppColors.acierClair,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
