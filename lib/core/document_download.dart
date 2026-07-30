/// Force le téléchargement local d'un document stocké sur Vercel Blob (accès
/// public) plutôt que de l'ouvrir dans un nouvel onglet du navigateur —
/// Vercel Blob renvoie `Content-Disposition: attachment` dès que la requête
/// porte le paramètre `download` (voir doc Vercel Blob).
Uri forceDownloadUri(String url) {
  final uri = Uri.parse(url);
  return uri.replace(queryParameters: {...uri.queryParameters, 'download': '1'});
}
