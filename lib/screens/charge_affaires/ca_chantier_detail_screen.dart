import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets/ajouter_document_chantier_dialog.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/renseigner_pv_dialog.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/chantier.dart';
import '../../data/models/document_chantier.dart';
import '../../data/models/user.dart';
import '../../state/chantier_state.dart';

/// Fiche chantier mobile pour le CA — consultation de l'avancement, des
/// installateurs rattachés et dépôt de documents de référence (Modules 1 à 3),
/// avec accès à la modification (voir [CaEditChantierScreen] atteint via
/// l'icône crayon). Version réduite de BoChantierDetailScreen (Web).
class CaChantierDetailScreen extends StatelessWidget {
  const CaChantierDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = GoRouterState.of(context).pathParameters['ref'] ?? '—';
    final chantier = context.watch<ChantierState>().findByReference(ref);

    if (chantier == null) {
      return ResponsiveLayout(
        appBar: GlassAppBar(title: const Text('Chantier'), backgroundColor: AppColors.encre, foregroundColor: Colors.white),
        child: const Center(child: Text('Chantier introuvable')),
      );
    }

    final (livretLabel, livretType) = _livretStatus(chantier);
    final (pvLabel, pvType) = chantier.pvSigne
        ? ('Signé le ${DateFormat('dd/MM/yyyy').format(chantier.pvSigneAt ?? chantier.dateFin)}', StatusType.conforme)
        : chantier.pvEnAttenteSignature
            ? ('En attente de signature', StatusType.enCours)
            : ('Non déposé', StatusType.attente);

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: Text(chantier.reference),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => context.push('/ca/chantier/${chantier.reference}/modifier'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier ce chantier',
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chantier.client, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${chantier.adresse}, ${chantier.ville}', style: const TextStyle(color: AppColors.acier, fontSize: 13)),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _kv('Pose', '${DateFormat('dd/MM').format(chantier.dateDebut)} au ${DateFormat('dd/MM').format(chantier.dateFin)} · ${chantier.horaires}'),
                _kv('Contact', '${chantier.contactNom} · ${chantier.contactTel}'),
                _kv('Matériel', '${chantier.typeMonteCharge} · ${chantier.capacite} · ${chantier.niveaux} niveau(x)'),
                _kv('Réf. affaire ERP', chantier.referenceAffaire),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Livret installateur', style: TextStyle(fontWeight: FontWeight.bold)),
                    StatusIndicator(label: livretLabel, type: livretType),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: chantier.progressionAutoControle, color: AppColors.orange, backgroundColor: AppColors.lignes),
                const SizedBox(height: 6),
                Text(
                  '${(chantier.progressionAutoControle * 100).toInt()}% avancement auto-contrôle',
                  style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PV de réception', style: TextStyle(fontWeight: FontWeight.bold)),
                    StatusIndicator(label: pvLabel, type: pvType),
                  ],
                ),
                if (!chantier.pvSigne) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (dialogContext) => RenseignerPvDialog(chantier: chantier),
                      ),
                      child: Text(chantier.pvEnAttenteSignature ? 'Remplacer le PV' : 'Déposer le PV'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDocuments(context, chantier),
          const SizedBox(height: 16),
          Text('Installateurs rattachés (${chantier.installateursRattaches.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (chantier.installateursRattaches.isEmpty)
            const Text('Aucun installateur rattaché.', style: TextStyle(color: AppColors.acierClair, fontSize: 12))
          else
            for (final u in chantier.installateursRattaches) ...[
              _installateurCard(context, chantier, u),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _buildDocuments(BuildContext context, Chantier chantier) {
    final docs = chantier.documentsChantier;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Documents chantier (Modules 1-3)', style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (dialogContext) => AjouterDocumentChantierDialog(reference: chantier.reference),
                ),
                icon: const Icon(Icons.add_circle_outline, color: AppColors.orange),
                tooltip: 'Ajouter un document',
              ),
            ],
          ),
          if (docs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Aucun document déposé pour l\'instant.', style: TextStyle(color: AppColors.acierClair, fontSize: 12)),
            )
          else
            for (final d in docs) ...[
              const SizedBox(height: 8),
              _documentRow(context, chantier, d),
            ],
        ],
      ),
    );
  }

  Widget _documentRow(BuildContext context, Chantier chantier, DocumentChantier d) {
    final icon = switch (d.type) {
      TypeDocumentChantier.securite => Icons.shield_outlined,
      TypeDocumentChantier.ficheChantier => Icons.assignment_outlined,
      TypeDocumentChantier.technique => Icons.description_outlined,
    };
    return InkWell(
      onTap: () => launchUrl(Uri.parse(d.filePath)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.acier),
          const SizedBox(width: 8),
          Expanded(child: Text(d.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          IconButton(
            onPressed: () => _confirmerSuppressionDocument(context, chantier, d),
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.acierClair),
            tooltip: 'Supprimer',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _confirmerSuppressionDocument(BuildContext context, Chantier chantier, DocumentChantier d) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text('« ${d.nom} » sera supprimé définitivement, y compris le fichier stocké. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ChantierState>().deleteDocumentChantier(chantier.reference, d.id);
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  (String, StatusType) _livretStatus(Chantier chantier) {
    final ok = chantier.installateursRattaches.isNotEmpty &&
        chantier.installateursRattaches.every((u) => chantier.livretsOuverts.contains(u.id));
    return ok ? ('Ouvert', StatusType.conforme) : ('Non ouvert', StatusType.nonConforme);
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.acierClair))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _installateurCard(BuildContext context, Chantier chantier, User u) {
    final ouvert = chantier.livretsOuverts.contains(u.id);
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.acier,
            child: Text(
              '${u.prenom.isNotEmpty ? u.prenom[0] : ''}${u.nom.isNotEmpty ? u.nom[0] : ''}',
              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                StatusIndicator(
                  label: ouvert ? 'Livret ouvert' : 'Livret non ouvert',
                  type: ouvert ? StatusType.conforme : StatusType.nonConforme,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _appeler(context, u),
            icon: const Icon(Icons.phone_outlined, color: AppColors.acier),
            tooltip: 'Appeler ${u.fullName}',
          ),
        ],
      ),
    );
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
}
