import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

/// Sélectionne une photo — l'utilisateur choisit, via le sélecteur natif de
/// l'appareil, de prendre une photo ou d'en choisir une déjà existante — puis
/// la redimensionne/recompresse en JPEG avant de la renvoyer en data URL
/// base64, pour ne pas saturer la base locale Drift quand elle transite par
/// le fichier d'attente hors-ligne (PendingOperations).
class PhotoCapture {
  static const int _maxWidth = 1280;
  static const int _jpegQuality = 70;

  static Future<String?> captureCompressed() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null) return null;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final resized = decoded.width > _maxWidth ? img.copyResize(decoded, width: _maxWidth) : decoded;
    final jpeg = img.encodeJpg(resized, quality: _jpegQuality);
    return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
  }
}
