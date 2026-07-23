import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/chantier.dart';
import '../../state/auth_state.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';

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

  @override
  Widget build(BuildContext context) {
    final chantierState = context.watch<ChantierState>();
    final comptesState = context.watch<ComptesState>();
    final pendingCount = comptesState.installateurs
        .where((u) => !u.isActive)
        .length;

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
    final progress = c.progressionAutoControle;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${c.reference} — ${c.client}',
            style: const TextStyle(fontWeight: FontWeight.bold),
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
