import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../data/models/user.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';

class BoChantierDetailScreen extends StatelessWidget {
  const BoChantierDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = GoRouterState.of(context).pathParameters['ref'] ?? '—';
    final chantier = context.watch<ChantierState>().findByReference(ref);

    if (chantier == null) {
      return const BoShell(activeNav: 'chantiers', child: Text('Chantier introuvable'));
    }

    final livretOk = chantier.installateursRattaches.isNotEmpty &&
        chantier.installateursRattaches.every((u) => chantier.livretsOuverts.contains(u.id));

    return BoShell(
      activeNav: 'chantiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${chantier.reference} — ${chantier.client}, ${chantier.ville}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 10),
              StatusIndicator(
                label: livretOk ? 'Prêt' : 'En attente',
                type: livretOk ? StatusType.conforme : StatusType.enCours,
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: const Text('Modifier', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final left = _buildLeftColumn(context, chantier);
              final right = _buildRightColumn(chantier);
              if (!isWide) return Column(children: [left, const SizedBox(height: 12), right]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 20),
                  Expanded(child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(BuildContext context, Chantier chantier) {
    return Column(
      children: [
        BoPanel(
          title: 'Installateurs rattachés',
          child: Column(
            children: [
              if (chantier.installateursRattaches.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Aucun installateur rattaché pour l\'instant.', style: TextStyle(fontSize: 11, color: AppColors.acierClair)),
                ),
              for (final u in chantier.installateursRattaches) _installateurRow(context, chantier, u),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _openRattacherDialog(context, chantier),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    child: const Text('+ Rattacher', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SMS de relance envoyé')),
                    ),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    child: const Text('Relancer par SMS', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const BoPanel(
          title: 'Filet de secours',
          child: Text(
            'PDF récapitulatif (fiche + consignes) envoyé automatiquement à chaque rattachement — lisible sans app ni compte.',
            style: TextStyle(fontSize: 10.5, color: AppColors.acier),
          ),
        ),
        if (chantier.pvSigne)
          BoPanel(
            title: 'Validation du PV',
            child: _buildPvSignature(context, chantier),
          ),
      ],
    );
  }

  Widget _buildPvSignature(BuildContext context, Chantier chantier) {
    final signataire = chantier.pvSigneur ?? 'le client';
    final horodatage = chantier.pvSigneAt != null ? DateFormat('dd/MM/yyyy à HH:mm').format(chantier.pvSigneAt!) : null;
    final caption = Text(
      'Signé par $signataire${horodatage != null ? ' le $horodatage' : ''}.',
      style: const TextStyle(fontSize: 11, color: AppColors.acier),
    );

    if (chantier.pvSignatureImagePath == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          caption,
          const SizedBox(height: 4),
          const Text('Aucune image de signature disponible.', style: TextStyle(fontSize: 10.5, color: AppColors.acierClair)),
        ],
      );
    }

    final imageUrl = '${ApiClient.baseUrl}${chantier.pvSignatureImagePath}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        caption,
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openSignatureDialog(context, imageUrl),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.lignes), borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.all(8),
            child: Image.network(
              imageUrl,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Text('Impossible de charger l\'image de signature.', style: TextStyle(fontSize: 10.5, color: AppColors.acierClair)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text('Cliquer sur l\'image pour l\'agrandir et valider avant facturation.', style: TextStyle(fontSize: 10, color: AppColors.acierClair)),
      ],
    );
  }

  void _openSignatureDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(imageUrl, fit: BoxFit.contain),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _installateurRow(BuildContext context, Chantier chantier, User u) {
    final ouvert = chantier.livretsOuverts.contains(u.id);
    final initials = '${u.prenom.isNotEmpty ? u.prenom[0] : ''}${u.nom.isNotEmpty ? u.nom[0] : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: Row(
        children: [
          CircleAvatar(radius: 10, backgroundColor: AppColors.acier, child: Text(initials, style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: Text('${u.fullName} (${u.status == UserStatus.sousTraitant ? 'sous-traitant' : 'salarié'})', style: const TextStyle(fontSize: 11.5))),
          StatusIndicator(
            label: ouvert ? 'Prêt hors-ligne' : 'Livret non ouvert',
            type: ouvert ? StatusType.conforme : StatusType.nonConforme,
          ),
        ],
      ),
    );
  }

  void _openRattacherDialog(BuildContext context, Chantier chantier) {
    final comptesState = context.read<ComptesState>();
    final disponibles = comptesState.installateurs
        .where((u) => u.isActive && !u.suspendu && !chantier.installateursRattaches.any((r) => r.id == u.id))
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rattacher un installateur'),
        content: SizedBox(
          width: 320,
          child: disponibles.isEmpty
              ? const Text('Aucun compte validé disponible.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: disponibles.map((u) => ListTile(
                        title: Text(u.fullName),
                        subtitle: Text(u.societe ?? (u.status == UserStatus.sousTraitant ? 'Sous-traitant' : 'Salarié')),
                        onTap: () {
                          context.read<ChantierState>().rattacher(chantier.reference, u.id);
                          Navigator.pop(dialogContext);
                        },
                      )).toList(),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _buildRightColumn(Chantier chantier) {
    return BoPanel(
      title: 'Avancement des 8 modules',
      child: Column(
        children: [
          BoKv(label: '1-3 · Consultation', value: const StatusIndicator(label: 'Complet', type: StatusType.conforme)),
          BoKv(
            label: '4 · Réception',
            value: StatusIndicator(
              label: '${(chantier.progressionReception * 100).toInt()}%',
              type: chantier.progressionReception == 0
                  ? StatusType.attente
                  : chantier.progressionReception == 1
                      ? StatusType.conforme
                      : StatusType.enCours,
            ),
          ),
          BoKv(
            label: '5 · Auto-contrôle',
            value: StatusIndicator(
              label: '${(chantier.progressionAutoControle * 100).toInt()}%',
              type: chantier.progressionAutoControle == 0
                  ? StatusType.attente
                  : chantier.progressionAutoControle == 1
                      ? StatusType.conforme
                      : StatusType.enCours,
            ),
          ),
          BoKv(
            label: '6 · PV',
            value: chantier.pvSigne
                ? const StatusIndicator(label: 'Signé', type: StatusType.conforme)
                : const Text('—', style: TextStyle(fontSize: 11, color: AppColors.acierClair)),
          ),
          BoKv(
            label: '7 · REX',
            value: chantier.rexValide
                ? const StatusIndicator(label: 'Envoyé', type: StatusType.conforme)
                : const Text('—', style: TextStyle(fontSize: 11, color: AppColors.acierClair)),
          ),
          BoKv(
            label: '8 · Docs terrain',
            value: chantier.docsTerrain.isEmpty
                ? const Text('—', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
                : StatusIndicator(label: '${chantier.docsTerrain.length} déposé(s)', type: StatusType.enCours),
          ),
        ],
      ),
    );
  }
}
