import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

/// Sélectionne un document terrain ou un certificat — photo (prise sur place
/// ou déjà existante) ou PDF, au choix de l'utilisateur dans le sélecteur
/// natif — et le renvoie en data URL base64. Les images sont redimensionnées
/// et recompressées comme [PhotoCapture] ; un PDF est envoyé tel quel.
class DocumentCapture {
  static const int _maxWidth = 1280;
  static const int _jpegQuality = 70;

  static Future<String?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return null;

    if ((picked.extension ?? '').toLowerCase() == 'pdf') {
      return 'data:application/pdf;base64,${base64Encode(bytes)}';
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final resized = decoded.width > _maxWidth ? img.copyResize(decoded, width: _maxWidth) : decoded;
    final jpeg = img.encodeJpg(resized, quality: _jpegQuality);
    return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
  }
}
