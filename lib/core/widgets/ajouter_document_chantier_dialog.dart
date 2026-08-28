import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../document_capture.dart';
import '../theme.dart';
import 'drop_zone.dart';
import '../../data/api_client.dart';
import '../../data/models/document_chantier.dart';
import '../../state/chantier_state.dart';

enum _EnvoiStatus { attente, enCours, succes, echec }

/// Délai d'affichage de la coche verte avant qu'une ligne réussie ne
/// disparaisse de la liste — juste assez pour que le succès soit visible
/// avant que le fichier ne s'efface.
const _delaiAffichageSucces = Duration(milliseconds: 500);

/// Suivi de l'envoi d'un fichier précis dans le dialogue — [isFirst] fige
/// définitivement quel fichier reçoit le nom saisi (voir doc de la classe),
/// y compris après un retry où l'ordre des statuts a changé.
class _FichierAEnvoyer {
  final PickedDocument picked;
  final bool isFirst;
  _EnvoiStatus status = _EnvoiStatus.attente;
  String? erreur;
  _FichierAEnvoyer(this.picked, {required this.isFirst});
}

/// Ajout d'un ou plusieurs documents de référence (PPSPS, plan, notice,
/// vidéo d'inspection...) pour un chantier — partagé entre le back-office
/// (Web) et l'espace mobile du CT, tous deux habilités à déposer ces
/// documents des Modules 1 à 3. Le nom n'est pas obligatoire : à défaut, le
/// nom du fichier d'origine fait l'affaire — ça évite de devoir taper un
/// intitulé pour chaque fichier quand on en importe plusieurs d'un coup.
///
/// Tout le feedback d'envoi (progression, succès, échec, retry) reste dans
/// cette fenêtre — aucun SnackBar sur l'écran principal, qui resterait
/// affiché en arrière-plan une fois le dialogue fermé.
class AjouterDocumentChantierDialog extends StatefulWidget {
  final String reference;
  const AjouterDocumentChantierDialog({super.key, required this.reference});

  @override
  State<AjouterDocumentChantierDialog> createState() => _AjouterDocumentChantierDialogState();
}

class _AjouterDocumentChantierDialogState extends State<AjouterDocumentChantierDialog> {
  final _nomController = TextEditingController();
  TypeDocumentChantier _type = TypeDocumentChantier.ficheChantier;
  final List<_FichierAEnvoyer> _fichiers = [];
  bool _isSubmitting = false;
  String? _progression;

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  bool get _peutEnvoyer => _fichiers.isNotEmpty;
  bool get _aUnEchec => _fichiers.any((f) => f.status == _EnvoiStatus.echec);

  void _ajouterPicked(List<PickedDocument> picked) {
    if (picked.isEmpty || !mounted) return;
    setState(() {
      var premier = _fichiers.isEmpty;
      for (final p in picked) {
        _fichiers.add(_FichierAEnvoyer(p, isFirst: premier));
        premier = false;
      }
    });
  }

  Future<void> _choisirFichiers() async {
    _ajouterPicked(await DocumentCapture.pickMultipleFiles());
  }

  /// Envoie [cibles] indépendamment les unes des autres — l'échec de l'une
  /// ne doit pas empêcher les autres d'être ajoutées. Utilisé à la fois par
  /// le bouton principal (toutes les cibles restantes) et par le bouton de
  /// retry d'une ligne précise (une seule cible).
  Future<void> _envoyer(List<_FichierAEnvoyer> cibles) async {
    if (cibles.isEmpty) return;
    final chantierState = context.read<ChantierState>();
    final nomSaisi = _nomController.text.trim();

    setState(() {
      _isSubmitting = true;
      for (final f in cibles) {
        f.status = _EnvoiStatus.enCours;
        f.erreur = null;
      }
    });

    for (final (i, f) in cibles.indexed) {
      if (!mounted) return;
      setState(() => _progression = cibles.length > 1 ? 'Envoi ${i + 1}/${cibles.length}...' : 'Envoi en cours...');
      try {
        await chantierState.addDocumentChantier(
          widget.reference,
          type: _type.name,
          nom: f.isFirst && nomSaisi.isNotEmpty ? nomSaisi : null,
          nomFichierOriginal: f.picked.fileName,
          file: f.picked.dataUrl,
        );
        if (!mounted) return;
        setState(() => f.status = _EnvoiStatus.succes);
        await Future.delayed(_delaiAffichageSucces);
        if (!mounted) return;
        setState(() => _fichiers.remove(f));
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          f.status = _EnvoiStatus.echec;
          f.erreur = e.message;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          f.status = _EnvoiStatus.echec;
          f.erreur = 'Échec de l\'envoi';
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _progression = null;
    });

    // Tous les fichiers sont partis avec succès : rien d'autre à faire, on
    // referme automatiquement. S'il reste des échecs, le dialogue reste
    // ouvert pour permettre le retry (voir _fichierRow).
    if (_fichiers.isEmpty) Navigator.of(context).pop();
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
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: 'Nom du document (optionnel)',
                hintText: _fichiers.length > 1 ? 'Laissez vide — chaque fichier garde son nom' : 'PPSPS, Plan de coupe, Notice...',
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
            if (_fichiers.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._fichiers.map(_fichierRow),
            ],
            if (_progression != null) ...[
              const SizedBox(height: 8),
              Text(_progression!, style: const TextStyle(fontSize: 11.5, color: AppColors.acier)),
            ] else if (_aUnEchec) ...[
              const SizedBox(height: 8),
              Text(
                '${_fichiers.length} fichier${_fichiers.length > 1 ? 's' : ''} en échec — réessayez ou retirez-le${_fichiers.length > 1 ? 's' : ''}.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.rouge),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _peutEnvoyer && !_isSubmitting ? () => _envoyer(List.of(_fichiers)) : null,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_aUnEchec ? 'Réessayer (${_fichiers.length})' : _fichiers.length > 1 ? 'Ajouter (${_fichiers.length})' : 'Ajouter'),
        ),
      ],
    );
  }

  /// Le glisser-déposer n'a de sens que sur le back-office Web — sur mobile,
  /// seul le bouton de sélection est proposé (voir [DropZone]/[kIsWeb]).
  Widget _buildDropZone() {
    return DropZone(
      onFilesDropped: (files) async {
        _ajouterPicked(await DocumentCapture.fromDroppedFiles(files));
      },
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _choisirFichiers,
            icon: const Icon(Icons.attach_file),
            label: Text(kIsWeb ? 'Choisir des fichiers ou les glisser ici' : 'Choisir un ou plusieurs fichiers'),
          ),
        ),
      ),
    );
  }

  Widget _fichierRow(_FichierAEnvoyer f) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _fichierStatusIcon(f.status),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.picked.fileName, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                if (f.status == _EnvoiStatus.echec)
                  Text('Échec — ${f.erreur ?? 'réessayez'}', style: const TextStyle(fontSize: 10.5, color: AppColors.rouge), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (f.status == _EnvoiStatus.echec)
            IconButton(
              onPressed: _isSubmitting ? null : () => _envoyer([f]),
              icon: const Icon(Icons.refresh, size: 16),
              tooltip: 'Réessayer',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          if (f.status == _EnvoiStatus.attente || f.status == _EnvoiStatus.echec)
            IconButton(
              onPressed: _isSubmitting ? null : () => setState(() => _fichiers.remove(f)),
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Retirer',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _fichierStatusIcon(_EnvoiStatus status) {
    switch (status) {
      case _EnvoiStatus.enCours:
        return const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2));
      case _EnvoiStatus.succes:
        return const Icon(Icons.check_circle, size: 16, color: AppColors.vert);
      case _EnvoiStatus.echec:
        return const Icon(Icons.error_outline, size: 16, color: AppColors.rouge);
      case _EnvoiStatus.attente:
        return const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.acierClair);
    }
  }

  Widget _typeButton(String label, TypeDocumentChantier type) {
    final isOn = _type == type;
    return GestureDetector(
      onTap: _isSubmitting ? null : () => setState(() => _type = type),
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
