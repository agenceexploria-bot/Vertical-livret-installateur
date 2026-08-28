import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'theme.dart';

enum _PhotoSheetChoice { camera, gallery }

/// Sélectionne une photo — l'utilisateur choisit explicitement entre prendre
/// une photo en direct (caméra) ou en choisir une déjà existante (galerie),
/// comme [AvatarCapture] — puis la redimensionne/recompresse en JPEG avant
/// de la renvoyer en data URL base64, pour ne pas saturer la base locale
/// Drift quand elle transite par le fichier d'attente hors-ligne
/// (PendingOperations). La compression passe par flutter_image_compress
/// (natif sur mobile, Canvas sur Web) plutôt que le package `image` en pur
/// Dart — nettement plus rapide, notamment sur les photos de caméra en haute
/// résolution qui rendaient la prise de photo perceptiblement lente.
class PhotoCapture {
  static const int _maxDimension = 1600;
  static const int _jpegQuality = 80;

  static Future<Uint8List?> _compress(Uint8List bytes) async {
    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _jpegQuality,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> captureCompressed(BuildContext context) async {
    final choice = await showModalBottomSheet<_PhotoSheetChoice>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.acier),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoSheetChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.acier),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoSheetChoice.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return null;

    final source = choice == _PhotoSheetChoice.camera ? ImageSource.camera : ImageSource.gallery;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final compressed = await _compress(bytes);
    if (compressed == null) return null;
    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }

  /// Convertit une image obtenue par glisser-déposer (voir [DropZone]) en
  /// data URL base64 — même compression que [captureCompressed]. `null` si
  /// le fichier déposé n'est pas une image reconnue.
  static Future<String?> fromDroppedBytes(Uint8List bytes) async {
    final compressed = await _compress(bytes);
    if (compressed == null) return null;
    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }
}
