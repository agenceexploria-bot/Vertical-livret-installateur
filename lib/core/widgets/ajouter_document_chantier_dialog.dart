import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import 'drop_zone.dart';
import '../../data/api_client.dart';
import '../../data/models/document_chantier.dart';
import '../../state/chantier_state.dart';

enum EnvoiStatus { attente, enCours, succes, echec }

/// Délai d'affichage de la coche verte avant qu'une ligne réussie ne
/// disparaisse de la liste — juste assez pour que le succès soit visible
/// avant que le fichier ne s'efface.
const _delaiAffichageSucces = Duration(milliseconds: 500);

/// MIME les plus courants déduits de l'extension — jamais de compression ici
/// (contrairement à DocumentCapture, partagé avec la capture photo/terrain,
/// où recompresser une photo de téléphone a du sens) : ce dialogue dépose
/// des documents de référence tels quels (PPSPS, plans, notices, vidéos...),
/// jamais des photos à optimiser. Toute extension non listée retombe sur
/// application/octet-stream — jamais de fichier écarté faute de type reconnu
/// (le serveur reste seul juge de ce qu'il accepte, voir KIND_CONFIG côté
/// backend).
const _mimesConnus = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'heic': 'image/heic',
  'mp4': 'video/mp4',
  'webm': 'video/webm',
  'mov': 'video/quicktime',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'odt': 'application/vnd.oasis.opendocument.text',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'rtf': 'application/rtf',
  'zip': 'application/zip',
  'rar': 'application/vnd.rar',
  '7z': 'application/x-7z-compressed',
};

String mimeForFilename(String fileName) {
  final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  return _mimesConnus[extension] ?? 'application/octet-stream';
}

/// Un fichier dans le cycle d'envoi du dialogue. [bytes] est `null`
/// uniquement si la LECTURE du fichier a échoué (rare — appareil qui a
/// perdu l'accès au fichier entre la sélection et la lecture, par exemple) :
/// même dans ce cas, le fichier reste dans la liste avec [status] = echec et
/// [erreur] renseigné, jamais retiré silencieusement (voir [lireDepuisPicker]
/// / [lireDepuisDrop]). [isFirst] désigne quel fichier reçoit le nom saisi
/// dans le champ optionnel — réassigné dynamiquement au premier fichier
/// lisible restant à chaque ajout ou retrait (voir
/// [reassignerPremierEnvoyable]), pour que ce nom ne se perde jamais
/// silencieusement si le fichier qui le portait disparaît de la liste.
class FichierAEnvoyer {
  final String fileName;
  final Uint8List? bytes;
  bool isFirst = false;
  EnvoiStatus status;
  String? erreur;

  FichierAEnvoyer({
    required this.fileName,
    required this.bytes,
    this.status = EnvoiStatus.attente,
    this.erreur,
  });

  bool get lisible => bytes != null;
  String get dataUrl => 'data:${mimeForFilename(fileName)};base64,${base64Encode(bytes!)}';
}

Future<FichierAEnvoyer> lireDepuisPicker(PlatformFile picked) async {
  final bytes = picked.bytes;
  if (bytes == null) {
    // file_picker n'a pas fourni les octets malgré withData: true — jamais
    // silencieux : le fichier reste dans la liste, marqué en échec.
    debugPrint('AjouterDocumentChantierDialog.lireDepuisPicker: bytes null pour "${picked.name}" (${picked.size} octets annoncés)');
    return FichierAEnvoyer(fileName: picked.name, bytes: null, status: EnvoiStatus.echec, erreur: 'Lecture du fichier impossible');
  }
  return FichierAEnvoyer(fileName: picked.name, bytes: bytes);
}

Future<FichierAEnvoyer> lireDepuisDrop(XFile file) async {
  try {
    final bytes = await file.readAsBytes();
    return FichierAEnvoyer(fileName: file.name, bytes: bytes);
  } catch (e) {
    debugPrint('AjouterDocumentChantierDialog.lireDepuisDrop: échec de lecture de "${file.name}" — $e');
    return FichierAEnvoyer(fileName: file.name, bytes: null, status: EnvoiStatus.echec, erreur: 'Lecture du fichier impossible');
  }
}

/// Réassigne isFirst au premier fichier ENVOYABLE (lisible) de [fichiers],
/// et l'enlève de tous les autres — à appeler après tout ajout ou retrait.
/// Sans ça, si le fichier qui portait ce drapeau est retiré par
/// l'utilisateur, ou s'avère illisible dès la sélection (voir
/// [lireDepuisPicker]/[lireDepuisDrop]), plus aucun fichier ne le porte : le
/// nom personnalisé saisi dans le dialogue ne s'appliquerait alors plus à
/// aucun document envoyé, silencieusement.
void reassignerPremierEnvoyable(List<FichierAEnvoyer> fichiers) {
  for (final f in fichiers) {
    f.isFirst = false;
  }
  for (final f in fichiers) {
    if (f.lisible) {
      f.isFirst = true;
      return;
    }
  }
}

/// Ajout d'un ou plusieurs documents de référence (PPSPS, plan, notice,
/// vidéo d'inspection...) pour un chantier — partagé entre le back-office
/// (Web) et l'espace mobile du CT, tous deux habilités à déposer ces
/// documents des Modules 1 à 3. Le nom n'est pas obligatoire : à défaut, le
/// nom du fichier d'origine fait l'affaire — ça évite de devoir taper un
/// intitulé pour chaque fichier quand on en importe plusieurs d'un coup.
///
/// N'affiche PAS les documents déjà déposés (module par module) — cette
/// vue-là vit dans l'écran appelant (voir bo_chantier_detail_screen.dart),
/// pas dans ce dialogue, qui ne gère que l'ajout.
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
  final List<FichierAEnvoyer> _fichiers = [];
  bool _isSubmitting = false;
  String? _progression;

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  bool get _peutEnvoyer => _fichiers.any((f) => f.lisible);
  bool get _aUnEchec => _fichiers.any((f) => f.status == EnvoiStatus.echec);

  /// [nouveaux] entre TOUJOURS dans la liste, quel que soit son contenu
  /// (type, lisibilité) — zéro rejet silencieux ici, voir [lireDepuisPicker]
  /// / [lireDepuisDrop] pour le seul cas qui marque directement un échec
  /// (lecture impossible).
  void _ajouterEntrees(List<FichierAEnvoyer> nouveaux) {
    if (nouveaux.isEmpty || !mounted) return;
    debugPrint('AjouterDocumentChantierDialog._ajouterEntrees: ${nouveaux.length} fichier(s) — ${nouveaux.map((f) => f.fileName).join(', ')}');
    setState(() {
      _fichiers.addAll(nouveaux);
      reassignerPremierEnvoyable(_fichiers);
    });
  }

  Future<void> _choisirFichiers() async {
    debugPrint('AjouterDocumentChantierDialog._choisirFichiers: ouverture du sélecteur (FileType.any)');
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true, allowMultiple: true);
    if (result == null || !mounted) return;
    final lus = await Future.wait(result.files.map(lireDepuisPicker));
    _ajouterEntrees(lus);
  }

  Future<void> _deposerFichiers(List<XFile> files) async {
    debugPrint('AjouterDocumentChantierDialog._deposerFichiers: ${files.length} fichier(s) déposé(s)');
    final lus = await Future.wait(files.map(lireDepuisDrop));
    _ajouterEntrees(lus);
  }

  /// Envoie [cibles] indépendamment les unes des autres — l'échec de l'une
  /// ne doit jamais empêcher les autres d'être ajoutées. Chaque envoi refait
  /// tout le cycle depuis le début (nouveau jeton Blob inclus, voir
  /// ApiClient.uploadFile) : pas de jeton mis en cache entre deux tentatives.
  /// Utilisé à la fois par le bouton principal (toutes les cibles
  /// envoyables restantes) et par le bouton de retry d'une ligne précise.
  Future<void> _envoyer(List<FichierAEnvoyer> cibles) async {
    final envoyables = cibles.where((f) => f.lisible).toList();
    if (envoyables.isEmpty) return;
    final chantierState = context.read<ChantierState>();
    final nomSaisi = _nomController.text.trim();

    setState(() {
      _isSubmitting = true;
      for (final f in envoyables) {
        f.status = EnvoiStatus.enCours;
        f.erreur = null;
      }
    });

    for (final (i, f) in envoyables.indexed) {
      if (!mounted) return;
      debugPrint('AjouterDocumentChantierDialog._envoyer: début envoi "${f.fileName}" (module=${_type.name}, ${f.bytes!.length} octets)');
      setState(() => _progression = envoyables.length > 1 ? 'Envoi ${i + 1}/${envoyables.length}...' : 'Envoi en cours...');
      try {
        await chantierState.addDocumentChantier(
          widget.reference,
          type: _type.name,
          nom: f.isFirst && nomSaisi.isNotEmpty ? nomSaisi : null,
          nomFichierOriginal: f.fileName,
          file: f.dataUrl,
        );
        debugPrint('AjouterDocumentChantierDialog._envoyer: succès "${f.fileName}"');
        if (!mounted) return;
        setState(() => f.status = EnvoiStatus.succes);
        await Future.delayed(_delaiAffichageSucces);
        if (!mounted) return;
        setState(() => _fichiers.remove(f));
      } on ApiException catch (e) {
        debugPrint('AjouterDocumentChantierDialog._envoyer: échec "${f.fileName}" — ApiException(${e.statusCode}): ${e.message}');
        if (!mounted) return;
        setState(() {
          f.status = EnvoiStatus.echec;
          f.erreur = e.message;
        });
      } catch (e, st) {
        // Contrairement au cas ApiException ci-dessus (message déjà connu et
        // déjà loggé par ApiClient), une exception qui atterrit ici est
        // n'importe quoi d'autre — jamais avalée sans trace, sans quoi ce
        // générique "Échec de l'envoi" est impossible à diagnostiquer.
        debugPrint('AjouterDocumentChantierDialog._envoyer: échec "${f.fileName}" — $e\n$st');
        if (!mounted) return;
        setState(() {
          f.status = EnvoiStatus.echec;
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
    // referme automatiquement. S'il reste des échecs (ou des fichiers
    // illisibles jamais envoyables), le dialogue reste ouvert pour permettre
    // le retry ou le retrait (voir _FichierRow).
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
            _ModuleSelector(
              type: _type,
              enabled: !_isSubmitting,
              onChanged: (type) => setState(() => _type = type),
            ),
            const SizedBox(height: 12),
            _DropZoneSelecteur(enabled: !_isSubmitting, onFilesDropped: _deposerFichiers, onTap: _choisirFichiers),
            if (_fichiers.isNotEmpty) ...[
              const SizedBox(height: 10),
              _FichierListe(
                fichiers: _fichiers,
                isSubmitting: _isSubmitting,
                onRetry: (f) => _envoyer([f]),
                onRetirer: (f) => setState(() {
                  _fichiers.remove(f);
                  reassignerPremierEnvoyable(_fichiers);
                }),
              ),
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
}

/// Sélecteur des 3 modules (Fiche chantier / Sécurité / Technique) —
/// détermine où le document sera classé côté chantier.
class _ModuleSelector extends StatelessWidget {
  final TypeDocumentChantier type;
  final bool enabled;
  final ValueChanged<TypeDocumentChantier> onChanged;
  const _ModuleSelector({required this.type, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.lignes, width: 1.5), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: _bouton(context, 'Module 1\nFiche chantier', TypeDocumentChantier.ficheChantier)),
          Expanded(child: _bouton(context, 'Module 2\nSécurité', TypeDocumentChantier.securite)),
          Expanded(child: _bouton(context, 'Module 3\nTechnique', TypeDocumentChantier.technique)),
        ],
      ),
    );
  }

  Widget _bouton(BuildContext context, String label, TypeDocumentChantier valeur) {
    final isOn = type == valeur;
    return GestureDetector(
      onTap: enabled ? () => onChanged(valeur) : null,
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

/// Zone de sélection unifiée : mêmes fichiers, même traitement, que le clic
/// ouvre le sélecteur natif ou qu'on glisse-dépose (Web uniquement, voir
/// [DropZone] — sur mobile, cette zone se réduit au bouton).
class _DropZoneSelecteur extends StatelessWidget {
  final bool enabled;
  final ValueChanged<List<XFile>> onFilesDropped;
  final VoidCallback onTap;
  const _DropZoneSelecteur({required this.enabled, required this.onFilesDropped, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DropZone(
      onFilesDropped: onFilesDropped,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: OutlinedButton.icon(
            onPressed: enabled ? onTap : null,
            icon: const Icon(Icons.attach_file),
            label: Text(kIsWeb ? 'Choisir des fichiers ou les glisser ici' : 'Choisir un ou plusieurs fichiers'),
          ),
        ),
      ),
    );
  }
}

/// Liste des fichiers du cycle d'envoi en cours, avec leur statut.
class _FichierListe extends StatelessWidget {
  final List<FichierAEnvoyer> fichiers;
  final bool isSubmitting;
  final ValueChanged<FichierAEnvoyer> onRetry;
  final ValueChanged<FichierAEnvoyer> onRetirer;
  const _FichierListe({required this.fichiers, required this.isSubmitting, required this.onRetry, required this.onRetirer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final f in fichiers)
          _FichierRow(fichier: f, isSubmitting: isSubmitting, onRetry: () => onRetry(f), onRetirer: () => onRetirer(f)),
      ],
    );
  }
}

class _FichierRow extends StatelessWidget {
  final FichierAEnvoyer fichier;
  final bool isSubmitting;
  final VoidCallback onRetry;
  final VoidCallback onRetirer;
  const _FichierRow({required this.fichier, required this.isSubmitting, required this.onRetry, required this.onRetirer});

  @override
  Widget build(BuildContext context) {
    final f = fichier;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _statusIcon(f.status),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.fileName, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                if (f.status == EnvoiStatus.echec)
                  Text('Échec — ${f.erreur ?? 'réessayez'}', style: const TextStyle(fontSize: 10.5, color: AppColors.rouge), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Pas de retry pour un fichier illisible (bytes == null) : rien à
          // renvoyer sans le re-sélectionner depuis le début.
          if (f.status == EnvoiStatus.echec && f.lisible)
            IconButton(
              onPressed: isSubmitting ? null : onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              tooltip: 'Réessayer',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          if (f.status == EnvoiStatus.attente || f.status == EnvoiStatus.echec)
            IconButton(
              onPressed: isSubmitting ? null : onRetirer,
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

  Widget _statusIcon(EnvoiStatus status) {
    switch (status) {
      case EnvoiStatus.enCours:
        return const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2));
      case EnvoiStatus.succes:
        return const Icon(Icons.check_circle, size: 16, color: AppColors.vert);
      case EnvoiStatus.echec:
        return const Icon(Icons.error_outline, size: 16, color: AppColors.rouge);
      case EnvoiStatus.attente:
        return const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.acierClair);
    }
  }
}
