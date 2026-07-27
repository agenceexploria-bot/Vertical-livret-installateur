import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/user.dart';
import '../../state/comptes_state.dart';

class CaValidationScreen extends StatelessWidget {
  const CaValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final comptesState = context.watch<ComptesState>();
    final pending = comptesState.installateurs.where((u) => !u.isActive).toList();

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Valider des inscriptions'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Nouvelles demandes d\'inscription (${pending.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (pending.isEmpty)
            const Text('Aucune demande en attente.', style: TextStyle(color: AppColors.acierClair)),
          for (final u in pending) ...[
            _buildRequestCard(context, u, comptesState),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, User u, ComptesState comptesState) {
    final statut = u.status == UserStatus.sousTraitant ? 'Sous-traitant${u.societe != null ? ' (${u.societe})' : ''}' : 'Salarié';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(u.mobile ?? u.email ?? '', style: const TextStyle(color: AppColors.acier, fontSize: 13)),
          Text(statut, style: const TextStyle(color: AppColors.acierClair, fontSize: 11)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handle(context, comptesState.suspendre(u), '${u.fullName} refusé'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.rouge, side: const BorderSide(color: AppColors.lignes)),
                  child: const Text('Refuser', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handle(context, comptesState.valider(u), '${u.fullName} validé avec succès'),
                  child: const Text('Valider', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handle(BuildContext context, Future<void> action, String successMessage) async {
    try {
      await action;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible — vérifiez votre connexion.')),
      );
    }
  }
}
