import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'theme.dart';

enum _PhotoSheetChoice { camera, gallery }

/// Sélectionne une photo — l'utilisateur choisit explicitement entre prendre
/// une photo en direct (caméra) ou en choisir une déjà existante (galerie),
/// comme [AvatarCapture] — puis la redimensionne/recompresse en JPEG avant
/// de la renvoyer en data URL base64, pour ne pas saturer la base locale
/// Drift quand elle transite par le fichier d'attente hors-ligne
/// (PendingOperations).
class PhotoCapture {
  static const int _maxWidth = 1280;
  static const int _jpegQuality = 70;

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
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final resized = decoded.width > _maxWidth ? img.copyResize(decoded, width: _maxWidth) : decoded;
    final jpeg = img.encodeJpg(resized, quality: _jpegQuality);
    return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
  }
}
