import 'dart:convert';

/// Lit le claim `exp` d'un JWT sans vérifier sa signature — utilisé
/// uniquement pour décider localement si une session hors-ligne est encore
/// valable. La vérification cryptographique reste faite par le serveur à
/// chaque appel réseau.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
    final exp = payload['exp'];
    if (exp is int) return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  } catch (_) {}
  return null;
}
