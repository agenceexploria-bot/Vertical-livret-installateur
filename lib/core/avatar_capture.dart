import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'theme.dart';

/// Sélection et compression d'une photo de profil — contrairement à
/// [PhotoCapture]/[DocumentCapture] (sélecteur natif de l'OS, qui propose
/// déjà lui-même caméra/galerie sur mobile), ici le choix est fait dans un
/// [BottomSheet] explicite pour un geste direct depuis l'avatar. Recadrée en
/// carré et recompressée en JPEG avant d'être renvoyée en data URL base64,
/// comme les autres captures d'image de l'app.
class AvatarCapture {
  static const int _size = 512;
  static const int _jpegQuality = 80;

  static Future<String?> pickViaBottomSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Photo de profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.encre)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.acier),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.acier),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final cropped = img.copyResizeCropSquare(decoded, size: _size);
    final jpeg = img.encodeJpg(cropped, quality: _jpegQuality);
    return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
  }
}
