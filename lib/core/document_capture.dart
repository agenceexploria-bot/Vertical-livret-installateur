import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'theme.dart';

/// Fichier sélectionné par l'utilisateur : le contenu encodé en data URL
/// base64, et son nom d'origine (ex. "Plan_fabricant.pdf") tel qu'il
/// apparaissait sur l'appareil — affiché ensuite tel quel dans l'interface
/// plutôt qu'un nom généré, pour que l'utilisateur reconnaisse son fichier.
class PickedDocument {
  final String dataUrl;
  final String fileName;
  const PickedDocument({required this.dataUrl, required this.fileName});
}

const _videoExtensionMimes = {'mp4': 'video/mp4', 'webm': 'video/webm'};

/// Extensions par défaut acceptées lors de l'import d'un document chantier ou
/// terrain — photo, PDF ou vidéo (rapport d'inspection filmé, par exemple).
const documentPickerExtensions = ['jpg', 'jpeg', 'png', 'pdf', 'mp4', 'webm'];

/// Sélectionne un document terrain ou un certificat — photo (prise sur place
/// ou déjà existante), PDF ou vidéo, au choix de l'utilisateur dans le
/// sélecteur natif. Les images sont redimensionnées et recompressées comme
/// [PhotoCapture] ; un PDF ou une vidéo sont envoyés tels quels.
class DocumentCapture {
  static const int _maxWidth = 1280;
  static const int _jpegQuality = 70;

  /// Cœur commun à toutes les sources de fichiers (sélecteur natif, caméra,
  /// glisser-déposer) : à partir d'un nom et d'octets bruts, produit le
  /// [PickedDocument] correspondant — images recompressées, PDF/vidéo
  /// envoyés tels quels. `null` si le type de fichier n'est pas reconnu.
  static PickedDocument? _fromBytes(String fileName, Uint8List bytes) {
    final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    if (extension == 'pdf') {
      return PickedDocument(dataUrl: 'data:application/pdf;base64,${base64Encode(bytes)}', fileName: fileName);
    }
    final videoMime = _videoExtensionMimes[extension];
    if (videoMime != null) {
      return PickedDocument(dataUrl: 'data:$videoMime;base64,${base64Encode(bytes)}', fileName: fileName);
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final resized = decoded.width > _maxWidth ? img.copyResize(decoded, width: _maxWidth) : decoded;
    final jpeg = img.encodeJpg(resized, quality: _jpegQuality);
    return PickedDocument(dataUrl: 'data:image/jpeg;base64,${base64Encode(jpeg)}', fileName: fileName);
  }

  static PickedDocument? _toPickedDocument(PlatformFile picked) {
    final bytes = picked.bytes;
    if (bytes == null) return null;
    return _fromBytes(picked.name, bytes);
  }

  /// Convertit les fichiers obtenus par glisser-déposer (voir [DropZone])
  /// en [PickedDocument] — même traitement qu'un import classique
  /// (recompression des images, PDF/vidéo envoyés tels quels). Les fichiers
  /// de type non reconnu sont silencieusement ignorés.
  static Future<List<PickedDocument>> fromDroppedFiles(List<XFile> files) async {
    final result = <PickedDocument>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final picked = _fromBytes(file.name, bytes);
      if (picked != null) result.add(picked);
    }
    return result;
  }

  static Future<PickedDocument?> pickFile({List<String> allowedExtensions = documentPickerExtensions}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    final picked = result?.files.single;
    if (picked == null) return null;
    return _toPickedDocument(picked);
  }

  /// Sélection de plusieurs fichiers en une seule fois — le nom de chaque
  /// fichier fait l'affaire par défaut, sans avoir à nommer chacun un par un.
  static Future<List<PickedDocument>> pickMultipleFiles({List<String> allowedExtensions = documentPickerExtensions}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return [];
    return result.files.map(_toPickedDocument).whereType<PickedDocument>().toList();
  }

  /// Enregistrement caméra plafonné à 3 minutes : la vidéo transite ensuite
  /// en base64 (comme les autres pièces jointes de l'app, voir
  /// PendingOperations), un enregistrement trop long saturerait la mémoire.
  static const _maxVideoDuration = Duration(minutes: 3);

  /// Propose de prendre une photo ou de filmer une vidéo EN DIRECT (caméra),
  /// en plus du sélecteur de fichiers classique (galerie, PDF, fichier déjà
  /// existant) — utilisé sur le terrain (documents terrain, certificats),
  /// là où [pickFile] seul obligeait à passer par la galerie même pour
  /// capturer quelque chose à l'instant.
  static Future<PickedDocument?> pickWithCameraOption(BuildContext context, {List<String> allowedExtensions = documentPickerExtensions}) async {
    final choice = await showModalBottomSheet<_DocumentSheetChoice>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.acier),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(sheetContext).pop(_DocumentSheetChoice.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: AppColors.acier),
              title: const Text('Filmer une vidéo'),
              onTap: () => Navigator.of(sheetContext).pop(_DocumentSheetChoice.video),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined, color: AppColors.acier),
              title: const Text('Choisir un fichier'),
              onTap: () => Navigator.of(sheetContext).pop(_DocumentSheetChoice.file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    switch (choice) {
      case _DocumentSheetChoice.photo:
        final picked = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
        if (picked == null) return null;
        final bytes = await picked.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) return null;
        final resized = decoded.width > _maxWidth ? img.copyResize(decoded, width: _maxWidth) : decoded;
        final jpeg = img.encodeJpg(resized, quality: _jpegQuality);
        return PickedDocument(dataUrl: 'data:image/jpeg;base64,${base64Encode(jpeg)}', fileName: picked.name);
      case _DocumentSheetChoice.video:
        final picked = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: _maxVideoDuration);
        if (picked == null) return null;
        final bytes = await picked.readAsBytes();
        final extension = picked.name.split('.').last.toLowerCase();
        final mime = _videoExtensionMimes[extension] ?? 'video/mp4';
        return PickedDocument(dataUrl: 'data:$mime;base64,${base64Encode(bytes)}', fileName: picked.name);
      case _DocumentSheetChoice.file:
        return pickFile(allowedExtensions: allowedExtensions);
      case null:
        return null;
    }
  }
}

enum _DocumentSheetChoice { photo, video, file }
