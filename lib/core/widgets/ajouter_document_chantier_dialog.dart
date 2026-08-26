import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../document_capture.dart';
import '../theme.dart';
import 'drop_zone.dart';
import '../../data/api_client.dart';
import '../../data/models/document_chantier.dart';
import '../../state/chantier_state.dart';

/// Ajout d'un ou plusieurs documents de référence (PPSPS, plan, notice,
/// vidéo d'inspection...) pour un chantier — partagé entre le back-office
/// (Web) et l'espace mobile du CT, tous deux habilités à déposer ces
/// documents des Modules 1 à 3. Le nom n'est pas obligatoire : à défaut, le
/// nom du fichier d'origine fait l'affaire — ça évite de devoir taper un
/// intitulé pour chaque fichier quand on en importe plusieurs d'un coup.
class AjouterDocumentChantierDialog extends StatefulWidget {
  final String reference;
  const AjouterDocumentChantierDialog({super.key, required this.reference});

  @override
  State<AjouterDocumentChantierDialog> createState() => _AjouterDocumentChantierDialogState();
}

class _AjouterDocumentChantierDialogState extends State<AjouterDocumentChantierDialog> {
  final _nomController = TextEditingController();
  TypeDocumentChantier _type = TypeDocumentChantier.ficheChantier;
  final List<PickedDocument> _picked = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  bool get _peutEnvoyer => _picked.isNotEmpty;

  Future<void> _choisirFichiers() async {
    final picked = await DocumentCapture.pickMultipleFiles();
    if (picked.isEmpty) return;
    setState(() => _picked.addAll(picked));
  }

  Future<void> _envoyer() async {
    setState(() => _isSubmitting = true);
    final chantierState = context.read<ChantierState>();
    // Le nom saisi (s'il y en a un) ne s'applique qu'au premier fichier —
    // au-delà, ou s'il est vide, chaque document prend le nom de son propre
    // fichier d'origine (voir doc de la classe).
    final nomSaisi = _nomController.text.trim();
    try {
      for (final (i, picked) in _picked.indexed) {
        await chantierState.addDocumentChantier(
          widget.reference,
          type: _type.name,
          nom: i == 0 && nomSaisi.isNotEmpty ? nomSaisi : null,
          nomFichierOriginal: picked.fileName,
          file: picked.dataUrl,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'envoi du document — réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter des documents chantier'),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width - 80).clamp(0, 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nomController,
              decoration: InputDecoration(
                labelText: 'Nom du document (optionnel)',
                hintText: _picked.length > 1 ? 'Laissez vide — chaque fichier garde son nom' : 'PPSPS, Plan de coupe, Notice...',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(border: Border.all(color: AppColors.lignes, width: 1.5), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: _typeButton('Module 1\nFiche chantier', TypeDocumentChantier.ficheChantier)),
                  Expanded(child: _typeButton('Module 2\nSécurité', TypeDocumentChantier.securite)),
                  Expanded(child: _typeButton('Module 3\nTechnique', TypeDocumentChantier.technique)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildDropZone(),
            if (_picked.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._picked.map((p) => _fichierRow(p)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _peutEnvoyer && !_isSubmitting ? _envoyer : null,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_picked.length > 1 ? 'Ajouter (${_picked.length})' : 'Ajouter'),
        ),
      ],
    );
  }

  /// Le glisser-déposer n'a de sens que sur le back-office Web — sur mobile,
  /// seul le bouton de sélection est proposé (voir [DropZone]/[kIsWeb]).
  Widget _buildDropZone() {
    return DropZone(
      onFilesDropped: (files) async {
        final dropped = await DocumentCapture.fromDroppedFiles(files);
        if (dropped.isEmpty) return;
        setState(() => _picked.addAll(dropped));
      },
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: OutlinedButton.icon(
            onPressed: _choisirFichiers,
            icon: const Icon(Icons.attach_file),
            label: Text(kIsWeb ? 'Choisir des fichiers ou les glisser ici' : 'Choisir un ou plusieurs fichiers'),
          ),
        ),
      ),
    );
  }

  Widget _fichierRow(PickedDocument picked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.acierClair),
          const SizedBox(width: 6),
          Expanded(child: Text(picked.fileName, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
          IconButton(
            onPressed: () => setState(() => _picked.remove(picked)),
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String label, TypeDocumentChantier type) {
    final isOn = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: isOn ? AppColors.encre : Colors.white),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOn ? Colors.white : AppColors.acier),
        ),
      ),
    );
  }
}
