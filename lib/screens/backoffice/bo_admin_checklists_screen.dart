import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/models/checklist_template_item.dart';
import '../../state/checklist_templates_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';
import 'widgets/bo_table_row.dart';

/// Gestion des listes de réception et de contrôle (Admin) — appliquées à la
/// création de chaque nouveau chantier (voir POST /chantiers) ; les modifier
/// n'affecte jamais les chantiers déjà en cours.
class BoAdminChecklistsScreen extends StatefulWidget {
  const BoAdminChecklistsScreen({super.key});

  @override
  State<BoAdminChecklistsScreen> createState() => _BoAdminChecklistsScreenState();
}

class _BoAdminChecklistsScreenState extends State<BoAdminChecklistsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChecklistTemplatesState>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChecklistTemplatesState>();
    return BoShell(
      activeNav: 'checklists',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Listes de réception et de contrôle', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Appliquées à chaque nouveau chantier créé — les modifier n\'affecte jamais les chantiers déjà en cours.',
            style: TextStyle(fontSize: 12, color: AppColors.acier),
          ),
          const SizedBox(height: 20),
          if (state.isLoading && state.items.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else ...[
            _buildSection(context, 'Liste de réception', ChecklistTemplateType.reception, state),
            _buildSection(context, 'Liste de contrôle (auto-contrôle)', ChecklistTemplateType.autoControle, state),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, ChecklistTemplateType type, ChecklistTemplatesState state) {
    final items = state.itemsOfType(type);
    return BoPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Aucun point pour l\'instant.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair)),
            )
          else
            for (final item in items) _itemRow(context, item),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openAddDialog(context, type),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter un point'),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, ChecklistTemplateItem item) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 8),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(item.categorie, style: const TextStyle(fontSize: 11.5, color: AppColors.acierClair))),
          Expanded(child: Text(item.libelle, style: const TextStyle(fontSize: 13))),
          if (item.critique)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.rouge.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
              child: const Text('Critique', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.rouge)),
            ),
          IconButton(
            onPressed: () => _openRenameDialog(context, item),
            icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.acierClair),
            tooltip: 'Renommer',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => _confirmerSuppression(context, item),
            icon: const Icon(Icons.delete_outline, size: 17, color: AppColors.acierClair),
            tooltip: 'Supprimer',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  void _openRenameDialog(BuildContext context, ChecklistTemplateItem item) {
    final controller = TextEditingController(text: item.libelle);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renommer ce point'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Libellé')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(dialogContext);
              if (value.isEmpty || value == item.libelle) return;
              _handleAction(context, () => context.read<ChecklistTemplatesState>().renommer(item, value));
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppression(BuildContext context, ChecklistTemplateItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce point ?'),
        content: Text(
          '« ${item.libelle} » sera retiré de la liste appliquée aux prochains chantiers. Les chantiers déjà créés ne sont pas affectés.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleAction(context, () => context.read<ChecklistTemplatesState>().supprimer(item));
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _openAddDialog(BuildContext context, ChecklistTemplateType type) {
    final categorieController = TextEditingController();
    final libelleController = TextEditingController();
    bool critique = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Ajouter un point'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: categorieController,
                  decoration: const InputDecoration(labelText: 'Catégorie', hintText: 'Mécanique, Essais...'),
                ),
                const SizedBox(height: 12),
                TextField(controller: libelleController, autofocus: true, decoration: const InputDecoration(labelText: 'Libellé')),
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: critique,
                  onChanged: (v) => setDialogState(() => critique = v ?? false),
                  title: const Text('Point critique (photo obligatoire)', style: TextStyle(fontSize: 12.5)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final categorie = categorieController.text.trim();
                final libelle = libelleController.text.trim();
                if (categorie.isEmpty || libelle.isEmpty) return;
                Navigator.pop(dialogContext);
                _handleAction(
                  context,
                  () => context.read<ChecklistTemplatesState>().ajouter(type: type, categorie: categorie, libelle: libelle, critique: critique),
                );
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

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
