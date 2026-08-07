import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'theme.dart';

enum _AvatarSheetChoice { camera, gallery, remove }

/// Résultat du choix utilisateur dans [AvatarCapture.pickViaBottomSheet] :
/// `dataUrl` renseigné pour une nouvelle photo, `remove` à `true` pour une
/// demande de suppression — jamais les deux à la fois. `null` (le record
/// entier) signifie que l'utilisateur a fermé le BottomSheet sans choisir.
typedef AvatarPickResult = ({String? dataUrl, bool remove});

/// Sélection et compression d'une photo de profil — contrairement à
/// [PhotoCapture]/[DocumentCapture] (sélecteur natif de l'OS, qui propose
/// déjà lui-même caméra/galerie sur mobile), ici le choix est fait dans un
/// [BottomSheet] explicite pour un geste direct depuis l'avatar. Recadrée en
/// carré et recompressée en JPEG avant d'être renvoyée en data URL base64,
/// comme les autres captures d'image de l'app.
class AvatarCapture {
  static const int _size = 512;
  static const int _jpegQuality = 80;

  /// [hasAvatar] contrôle l'affichage de l'option "Supprimer la photo" — pas
  /// de suppression proposée si l'utilisateur n'a déjà pas de photo.
  static Future<AvatarPickResult?> pickViaBottomSheet(BuildContext context, {required bool hasAvatar}) async {
    final choice = await showModalBottomSheet<_AvatarSheetChoice>(
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
              onTap: () => Navigator.of(sheetContext).pop(_AvatarSheetChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.acier),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(sheetContext).pop(_AvatarSheetChoice.gallery),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.rouge),
                title: const Text('Supprimer la photo', style: TextStyle(color: AppColors.rouge)),
                onTap: () => Navigator.of(sheetContext).pop(_AvatarSheetChoice.remove),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return null;
    if (choice == _AvatarSheetChoice.remove) return (dataUrl: null, remove: true);

    final source = choice == _AvatarSheetChoice.camera ? ImageSource.camera : ImageSource.gallery;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final cropped = img.copyResizeCropSquare(decoded, size: _size);
    final jpeg = img.encodeJpg(cropped, quality: _jpegQuality);
    return (dataUrl: 'data:image/jpeg;base64,${base64Encode(jpeg)}', remove: false);
  }
}
