// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Déclenche le téléchargement d'un fichier texte (CSV) depuis le
/// navigateur — construit un Blob et simule un clic sur un lien `<a
/// download>` éphémère, seul mécanisme fiable pour un export déclenché
/// depuis le clavier/la souris sans passer par un serveur.
void downloadTextFile(String filename, String content, {String mimeType = 'text/plain'}) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
