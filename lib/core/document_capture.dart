import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

/// Fichier sélectionné par l'utilisateur : le contenu encodé en data URL
/// base64, et son nom d'origine (ex. "Plan_fabricant.pdf") tel qu'il
/// apparaissait sur l'appareil — affiché ensuite tel quel dans l'interface
/// plutôt qu'un nom généré, pour que l'utilisateur reconnaisse son fichier.
class PickedDocument {
  final String dataUrl;
  final String fileName;
  const PickedDocument({required this.dataUrl, required this.fileName});
}

/// Sélectionne un document terrain ou un certificat — photo (prise sur place
/// ou déjà existante) ou PDF, au choix de l'utilisateur dans le sélecteur
/// natif. Les images sont redimensionnées et recompressées comme
/// [PhotoCapture] ; un PDF est envoyé tel quel.
class DocumentCapture {
  static const int _maxWidth = 1280;
  static const int _jpegQuality = 70;

  static Future<PickedDocument?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return null;

    if ((picked.extension ?? '').toLowerCase() == 'pdf') {
      return PickedDocument(
        dataUrl: 'data:application/pdf;base64,${base64Encode(bytes)}',
        fileName: picked.name,
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final resized = decoded.width > _maxWidth ? img.copyResize(decoded, width: _maxWidth) : decoded;
    final jpeg = img.encodeJpg(resized, quality: _jpegQuality);
    return PickedDocument(
      dataUrl: 'data:image/jpeg;base64,${base64Encode(jpeg)}',
      fileName: picked.name,
    );
  }
}
