import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/chantier.dart';
import '../../data/models/user.dart';
import '../../state/auth_state.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';

/// Interface mobile dédiée au CA — volontairement réduite par rapport au
/// back-office Web (BoShell) : consultation de l'avancement des chantiers en
/// cours, relance des installateurs n'ayant pas ouvert leur livret, et
/// validation des inscriptions. Pas de tableau de bord complet ici, le CA en
/// déplacement n'a besoin que de ces trois gestes rapides.
class CaHomeScreen extends StatefulWidget {
  const CaHomeScreen({super.key});

  @override
  State<CaHomeScreen> createState() => _CaHomeScreenState();
}

class _CaHomeScreenState extends State<CaHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthState>().currentUser;
      if (user != null) {
        context.read<ChantierState>().fetchChantiers(user);
      }
      context.read<ComptesState>().fetch();
    });
  }

  List<(Chantier, User)> _livretsNonOuverts(List<Chantier> chantiers) {
    final result = <(Chantier, User)>[];
    for (final c in chantiers) {
      for (final u in c.installateursRattaches) {
        if (!c.livretsOuverts.contains(u.id)) result.add((c, u));
      }
    }
    return result;
  }

  /// Statut affiché sur la carte chantier — les trois étapes concrètes que
  /// le CA doit surveiller en priorité en déplacement, dans leur ordre
  /// naturel (une seule étiquette à la fois, pas un pourcentage abstrait).
  (String, StatusType) _chantierStatus(Chantier c) {
    if (c.pvSigne) return ('PV signé', StatusType.conforme);
    if (c.progressionAutoControle > 0) return ('Auto-contrôle en cours', StatusType.enCours);
    if (c.progressionReception > 0) return ('Réception en cours', StatusType.enCours);
    final livretOk = c.installateursRattaches.isNotEmpty &&
        c.installateursRattaches.every((u) => c.livretsOuverts.contains(u.id));
    if (!livretOk) return ('Livret non ouvert', StatusType.nonConforme);
    return ('Prêt à démarrer', StatusType.attente);
  }

  Future<void> _appeler(BuildContext context, User u) async {
    if (u.mobile == null || u.mobile!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun numéro de mobile enregistré pour ${u.fullName}.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: u.mobile);
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lancer l\'appel sur cet appareil.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chantierState = context.watch<ChantierState>();
    final comptesState = context.watch<ComptesState>();
    final pendingCount = comptesState.installateurs.where((u) => !u.isActive).length;
    final relances = _livretsNonOuverts(chantierState.chantiers);

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('Suivi chantiers'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => context.read<AuthState>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      child: chantierState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pendingCount > 0) ...[
                  _buildAlert(context, pendingCount),
                  const SizedBox(height: 24),
                ],
                Text(
                  'Chantiers en cours',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final c in chantierState.chantiers) ...[
                  _buildChantierItem(context, c),
                  const SizedBox(height: 12),
                ],
                if (relances.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Livrets non ouverts (${relances.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final (c, u) in relances) ...[
                    _buildRelanceItem(context, c, u),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 16),
                _buildActionItem(
                  context,
                  'Valider une inscription',
                  Icons.person_add_outlined,
                  onTap: () => context.push('/ca/validation'),
                ),
              ],
            ),
    );
  }

  Widget _buildAlert(BuildContext context, int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inscriptions à traiter',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pendingCount installateur(s) en attente de validation.',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.push('/ca/validation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Traiter', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildChantierItem(BuildContext context, Chantier c) {
    final (label, type) = _chantierStatus(c);
    final progress = c.progressionAutoControle;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.reference} — ${c.client}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              StatusIndicator(label: label, type: type),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            color: AppColors.orange,
            backgroundColor: AppColors.lignes,
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% avancement auto-contrôle',
            style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
          ),
        ],
      ),
    );
  }

  Widget _buildRelanceItem(BuildContext context, Chantier c, User u) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '${c.reference} — ${c.client}',
                  style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _appeler(context, u),
            icon: const Icon(Icons.phone, size: 15),
            label: const Text('Appeler', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    String label,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.acier),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.chevron_right, color: AppColors.acierClair),
        ],
      ),
    );
  }
}
