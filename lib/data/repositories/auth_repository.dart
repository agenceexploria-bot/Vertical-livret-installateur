import 'dart:async';
import 'dart:convert';
import '../../core/jwt.dart';
import '../api_client.dart';
import '../local/app_database.dart';
import '../local/session_storage.dart';
import '../models/user.dart';

class AuthRepository {
  final ApiClient _api;
  final AppDatabase _db;
  final SessionStorage _storage = createSessionStorage();
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUser = 'cached_user';

  AuthRepository(this._api, this._db);

  Future<User> login(String identifier, String password) async {
    final data = await _api.login(identifier, password);
    _api.setTokens(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _persistRefreshToken(data['refreshToken'] as String);
    await _persistUser(user);
    return user;
  }

  Future<Map<String, dynamic>> requestEmailCode(String email) => _api.requestEmailCode(email);

  Future<void> requestPasswordReset(String email) => _api.requestPasswordReset(email);

  Future<void> resetPassword({required String email, required String code, required String password}) =>
      _api.resetPassword(email: email, code: code, password: password);

  Future<String> verifyEmailCode(String email, String code) async {
    final data = await _api.verifyEmailCode(email, code);
    return data['verificationTicket'] as String;
  }

  Future<User> signup({
    required String nom,
    required String prenom,
    String? mobile,
    required String password,
    required String email,
    required String verificationTicket,
    bool sousTraitant = false,
    String? societe,
  }) async {
    final data = await _api.signup(
      nom: nom,
      prenom: prenom,
      mobile: mobile,
      password: password,
      email: email,
      verificationTicket: verificationTicket,
      sousTraitant: sousTraitant,
      societe: societe,
    );
    _api.setTokens(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _persistRefreshToken(data['refreshToken'] as String);
    await _persistUser(user);
    return user;
  }

  Future<User> signupInterne({
    required String nom,
    required String prenom,
    required String mobile,
    required String password,
    required String email,
    required String role,
  }) async {
    final data = await _api.signupInterne(
      nom: nom,
      prenom: prenom,
      mobile: mobile,
      password: password,
      email: email,
      role: role,
    );
    _api.setTokens(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _persistRefreshToken(data['refreshToken'] as String);
    await _persistUser(user);
    return user;
  }

  Future<User> updateProfile({String? nom, String? prenom, String? email, String? mobile, String? societe}) async {
    final data = await _api.updateProfile(nom: nom, prenom: prenom, email: email, mobile: mobile, societe: societe);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _persistUser(user);
    return user;
  }

  /// [file] : certificat réel (PDF ou image), en data URL base64. Mis en
  /// file d'attente hors-ligne comme les autres pièces jointes terrain si le
  /// réseau échoue — rejoué par le SyncEngine au retour du réseau.
  Future<void> addHabilitation({required String titre, required DateTime dateExpiration, required String file}) async {
    final dateExpirationIso = dateExpiration.toIso8601String();
    try {
      await _api.addHabilitation(titre: titre, dateExpiration: dateExpirationIso, file: file);
    } catch (_) {
      await _db.enqueueOperation(
        type: 'addHabilitation',
        chantierReference: 'profil',
        payload: {'titre': titre, 'dateExpiration': dateExpirationIso, 'file': file},
      );
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await _storage.remove(_keyRefreshToken);
    await _storage.remove(_keyUser);
    // Évite qu'un autre installateur se connectant sur le même appareil voie
    // les chantiers mis en cache pour la session précédente.
    await _db.clearChantierCache();
  }

  /// Restaure la session au démarrage à partir du refresh token persisté.
  ///
  /// La session reste valable hors-ligne tant que ce token n'est pas expiré
  /// localement (N4) : on ne dépend d'aucun appel réseau pour authentifier
  /// l'utilisateur avec le profil déjà en cache. Un rafraîchissement réseau
  /// est tenté en tâche de fond, sans jamais bloquer ni déconnecter en cas
  /// d'échec (pas de réseau, serveur injoignable).
  Future<User?> tryAutoLogin() async {
    final refreshToken = await _storage.getString(_keyRefreshToken);
    if (refreshToken == null) return null;

    final expiry = jwtExpiry(refreshToken);
    if (expiry != null && expiry.isBefore(DateTime.now())) {
      await _storage.remove(_keyRefreshToken);
      await _storage.remove(_keyUser);
      return null;
    }

    _api.setTokens(refreshToken: refreshToken);

    final cachedJson = await _storage.getString(_keyUser);
    if (cachedJson != null) {
      unawaited(_refreshInBackground(refreshToken));
      return User.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
    }

    // Pas de profil en cache (ex. première ouverture après une connexion sur
    // un autre appareil) : on tente une seule récupération réseau.
    return _refreshInBackground(refreshToken);
  }

  /// Expiration du jeton de rafraîchissement — utilisée pour afficher jusqu'à
  /// quand la session hors-ligne reste valable.
  Future<DateTime?> getSessionExpiry() async {
    final refreshToken = await _storage.getString(_keyRefreshToken);
    return refreshToken == null ? null : jwtExpiry(refreshToken);
  }

  Future<User?> refreshCurrentUser() async {
    final user = await _fetchCurrentUser();
    if (user != null) await _persistUser(user);
    return user;
  }

  Future<User?> _refreshInBackground(String refreshToken) async {
    try {
      final restored = await _api.restoreSession(refreshToken);
      if (!restored) return null;
      final user = await _fetchCurrentUser();
      if (user != null) await _persistUser(user);
      return user;
    } catch (_) {
      // Hors-ligne ou serveur injoignable : on reste sur la session déjà en cache.
      return null;
    }
  }

  Future<User?> _fetchCurrentUser() async {
    try {
      final data = await _api.me();
      return User.fromJson(data['user'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistRefreshToken(String token) async {
    await _storage.setString(_keyRefreshToken, token);
  }

  Future<void> _persistUser(User user) async {
    await _storage.setString(_keyUser, jsonEncode(user.toJson()));
  }
}
