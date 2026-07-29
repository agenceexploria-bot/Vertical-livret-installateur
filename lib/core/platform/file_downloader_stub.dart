/// Export CSV réservé au back-office Web (voir BoShell, bloqué sur mobile
/// natif) — cette implémentation ne devrait jamais être appelée en pratique.
void downloadTextFile(String filename, String content, {String mimeType = 'text/plain'}) {
  throw UnsupportedError('Le téléchargement de fichier n\'est disponible que sur Web.');
}
