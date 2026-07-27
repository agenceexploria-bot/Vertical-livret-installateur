import 'session_storage_io.dart' if (dart.library.html) 'session_storage_web.dart' as impl;

/// Persistance clé/valeur pour la session (refresh token, profil en cache).
///
/// Sur Web, chaque onglet a son propre `sessionStorage` navigateur — deux
/// onglets peuvent donc être connectés à des comptes différents sans se
/// marcher dessus. `localStorage` (utilisé par défaut par `shared_preferences`
/// sur Web) est au contraire partagé entre tous les onglets d'une même
/// origine : une connexion dans un onglet y écrasait la session d'un autre,
/// ce qui causait la confusion de rôle/session rapportée (voir AuthRepository).
/// Sur mobile/desktop (pas de notion d'onglet), on garde `shared_preferences`
/// pour que la session survive bien aux redémarrages de l'app.
abstract class SessionStorage {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

SessionStorage createSessionStorage() => impl.PlatformSessionStorage();
