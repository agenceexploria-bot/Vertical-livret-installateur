import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../data/api_client.dart';
import '../../../data/models/chantier.dart';
import '../../../state/chantier_state.dart';
import '../../../state/comptes_state.dart';
import 'nouveau_chantier_rapide_dialog.dart';

/// Module SAV — dialogue de création d'une intervention SAV, partagé entre
/// deux points d'entrée : la fiche d'un chantier d'installation ([chantier]
/// déjà connu, le sélecteur ci-dessous est masqué) et le point d'entrée
/// générique "Nouveau" du back-office/mobile CT ([chantier] `null`, le
/// chantier d'origine se choisit par recherche réf./client parmi les
/// chantiers d'installation). [chantierDetailPath] construit la route de la
/// fiche du SAV créé — différente entre le back-office Web et l'app mobile
/// CT (voir router.dart), donc fournie par l'appelant plutôt que codée en
/// dur ici.
class CreerSavDialog extends StatefulWidget {
  final Chantier? chantier;
  final String Function(String reference) chantierDetailPath;

  const CreerSavDialog({super.key, this.chantier, required this.chantierDetailPath});

  @override
  State<CreerSavDialog> createState() => _CreerSavDialogState();
}

class _CreerSavDialogState extends State<CreerSavDialog> {
  final _descriptionController = TextEditingController();
  // Contrôleur externe (plutôt que celui, interne, que l'Autocomplete
  // créerait tout seul) — nécessaire pour refléter dans le champ le chantier
  // fraîchement créé depuis le mini-formulaire (voir _ouvrirNouveauChantier),
  // qui ne passe jamais par onSelected.
  final _chantierSearchController = TextEditingController();
  // Autocomplete exige que focusNode et textEditingController soient fournis
  // ensemble (ou ni l'un ni l'autre) — voir RawAutocomplete.
  final _chantierSearchFocusNode = FocusNode();
  late Chantier? _chantierOrigine = widget.chantier;
  String? _installateurId;
  DateTime? _savDate;
  bool _isSubmitting = false;
  String? _erreur;

  @override
  void dispose() {
    _descriptionController.dispose();
    _chantierSearchController.dispose();
    _chantierSearchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _savDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _savDate = picked);
  }

  /// Ouvre le mini-formulaire de création rapide d'un chantier ancien (voir
  /// NouveauChantierRapideDialog) au-dessus de ce dialogue — le chantier créé,
  /// s'il y en a un, est présélectionné dès le retour.
  Future<void> _ouvrirNouveauChantier() async {
    final created = await showDialog<Chantier>(
      context: context,
      builder: (_) => const NouveauChantierRapideDialog(),
    );
    if (created == null || !mounted) return;
    setState(() => _chantierOrigine = created);
    _chantierSearchController.text = '${created.reference} — ${created.client}';
  }

  Future<void> _creer() async {
    if (_chantierOrigine == null) {
      setState(() => _erreur = 'Choisissez le chantier terminé.');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _erreur = 'La description du problème est requise.');
      return;
    }
    if (_installateurId == null) {
      setState(() => _erreur = 'Choisissez un installateur à assigner.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _erreur = null;
    });
    try {
      final sav = await context.read<ChantierState>().createSav(
            _chantierOrigine!.reference,
            descriptionProbleme: _descriptionController.text.trim(),
            installateurId: _installateurId!,
            savDate: _savDate,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push(widget.chantierDetailPath(sav.reference));
    } on ApiException catch (e) {
      setState(() {
        _erreur = e.message;
        _isSubmitting = false;
      });
    } catch (_) {
      setState(() {
        _erreur = 'Une erreur est survenue. Réessayez.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final installateurs = context.watch<ComptesState>().installateurs.where((u) => u.isActive && !u.suspendu).toList();
    final chantiersInstallation = context.watch<ChantierState>().chantiersInstallationList;

    return AlertDialog(
      title: Text(
        widget.chantier != null ? 'Créer une intervention SAV — ${widget.chantier!.reference}' : 'Nouvelle intervention SAV',
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.chantier == null) ...[
                Autocomplete<Chantier>(
                  displayStringForOption: (c) => '${c.reference} — ${c.client}',
                  optionsBuilder: (textValue) {
                    final query = textValue.text.trim().toLowerCase();
                    if (query.isEmpty) return chantiersInstallation;
                    return chantiersInstallation.where(
                      (c) => c.reference.toLowerCase().contains(query) || c.client.toLowerCase().contains(query),
                    );
                  },
                  onSelected: (c) => setState(() => _chantierOrigine = c),
                  textEditingController: _chantierSearchController,
                  focusNode: _chantierSearchFocusNode,
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Chantier terminé',
                        hintText: 'Réf. ERP ou nom du client...',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _ouvrirNouveauChantier,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nouveau chantier'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description du problème', alignLabelWithHint: true),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _installateurId,
                decoration: const InputDecoration(labelText: 'Installateur à assigner'),
                items: installateurs.map((u) => DropdownMenuItem(value: u.id, child: Text(u.fullName))).toList(),
                onChanged: (value) => setState(() => _installateurId = value),
              ),
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date prévue (optionnel)'),
                  subtitle: Text(_savDate != null ? DateFormat('dd/MM/yyyy').format(_savDate!) : 'Aujourd\'hui'),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: _choisirDate,
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 10),
                Text(_erreur!, style: const TextStyle(color: AppColors.rouge, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _creer,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Créer'),
        ),
      ],
    );
  }
}
