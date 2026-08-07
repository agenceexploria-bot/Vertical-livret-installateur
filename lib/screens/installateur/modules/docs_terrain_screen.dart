import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/document_capture.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_app_bar.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/api_client.dart';
import '../../../state/auth_state.dart';
import '../../../state/chantier_state.dart';
import '../../../state/network_state.dart';
import '../../../data/models/document_terrain.dart';

class DocsTerrainScreen extends StatefulWidget {
  const DocsTerrainScreen({super.key});

  @override
  State<DocsTerrainScreen> createState() => _DocsTerrainScreenState();
}

class _DocsTerrainScreenState extends State<DocsTerrainScreen> {
  CategorieDocument? _selectedCategory;
  bool _isCapturing = false;

  static const _categories = [
    ('Bon de livraison', CategorieDocument.bonLivraison),
    ('Document client', CategorieDocument.documentClient),
    ('Certificat', CategorieDocument.habilitation),
    ('Constat', CategorieDocument.constat),
  ];

  @override
  Widget build(BuildContext context) {
    final chantierState = context.watch<ChantierState>();
    final chantier = chantierState.currentChantier!;
    final docs = chantier.docsTerrain;
    final userId = context.watch<AuthState>().currentUser?.id;

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Documents terrain'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Déposer un nouveau document', style: Theme.of(context).textTheme.titleMedium),
          ),
          _buildCategoryGrid(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _selectedCategory == null || _isCapturing ? null : () => _addDocument(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un document (photo ou PDF)'),
            ),
          ),
          if (_isCapturing) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Préparation du document...', style: TextStyle(fontSize: 11, color: AppColors.acierClair)),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Historique des dépôts', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                if (docs.isEmpty)
                  const Text('Aucun document déposé pour le moment.', style: TextStyle(color: AppColors.acierClair, fontSize: 12)),
                for (final d in docs.reversed) ...[
                  _buildDocItem(context, d, canDelete: d.auteurId != null && d.auteurId == userId),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        children: _categories.map((cat) => Padding(
          padding: const EdgeInsets.all(4.0),
          child: GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat.$2),
            child: Container(
              width: (500 - 40) / 2, // approximation for responsive col
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: _selectedCategory == cat.$2 ? AppColors.encre : Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _selectedCategory == cat.$2 ? AppColors.encre : AppColors.lignes),
              ),
              child: Text(
                cat.$1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _selectedCategory == cat.$2 ? Colors.white : AppColors.acier,
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _addDocument(BuildContext context) async {
    final categorie = _selectedCategory!;

    // EX-13 : les habilitations personnelles se déposent sur le profil, pas par affaire.
    if (categorie == CategorieDocument.habilitation) {
      setState(() => _selectedCategory = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les habilitations se déposent sur votre profil, une seule fois.')),
      );
      context.push('/profil');
      return;
    }

    setState(() => _isCapturing = true);
    final picked = await DocumentCapture.pickFile();
    if (!context.mounted) return;
    if (picked == null) {
      setState(() => _isCapturing = false);
      return;
    }

    final isOnline = context.read<NetworkState>().isOnline;
    final chantierState = context.read<ChantierState>();
    final reference = chantierState.currentChantier!.reference;
    final auteur = context.read<AuthState>().currentUser?.fullName;

    // Le repository tente le réseau et, en cas d'échec, met l'envoi en file
    // d'attente locale (PendingOperations) — rejoué automatiquement au retour réseau.
    await chantierState.addDocument(
      reference,
      titre: picked.fileName,
      categorie: categorie.name,
      file: picked.dataUrl,
      auteurName: auteur,
    );

    if (!context.mounted) return;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hors-ligne : le document sera envoyé au retour du réseau.')),
      );
    }
    setState(() {
      _selectedCategory = null;
      _isCapturing = false;
    });
  }

  Widget _buildDocItem(BuildContext context, DocumentTerrain d, {required bool canDelete}) {
    return AppCard(
      onTap: d.filePath == null ? null : () => launchUrl(Uri.parse(d.filePath!)),
      child: Row(
        children: [
          Icon(d.filePath != null ? Icons.description_outlined : Icons.image_outlined, color: AppColors.acierClair),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.titre, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${d.categorieLabel} · ${DateFormat('dd/MM HH:mm').format(d.horodatage)} · ${d.auteur}',
                  style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: d.envoye ? AppColors.vert : AppColors.orange, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(d.envoye ? 'Envoyé' : 'En file', style: const TextStyle(fontSize: 11, color: AppColors.acierClair)),
              if (canDelete && d.id != null)
                IconButton(
                  onPressed: () => _confirmerSuppression(context, d),
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.acierClair),
                  tooltip: 'Supprimer',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmerSuppression(BuildContext context, DocumentTerrain d) {
    final chantierState = context.read<ChantierState>();
    final reference = chantierState.currentChantier!.reference;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text('« ${d.titre} » sera supprimé définitivement. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleAction(context, () => chantierState.deleteDocument(reference, d.id!));
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  /// Affiche un message clair en cas d'échec d'une action serveur — sans ça,
  /// un clic qui échoue (droits insuffisants, réseau...) ne montrait
  /// strictement rien à l'utilisateur (exception non attendue, silencieuse).
  Future<void> _handleAction(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Une erreur est survenue. Réessayez.')));
    }
  }
}
