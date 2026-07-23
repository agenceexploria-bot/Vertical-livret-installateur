import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  /// IP locale du PC de dev sur le Wi-Fi — un téléphone physique ne peut pas
  /// résoudre "localhost" vers le backend qui tourne sur l'ordinateur de dev,
  /// il doit passer par l'adresse réseau locale. À mettre à jour si l'IP
  /// change (reconnexion Wi-Fi, autre réseau) : trouvable via `ipconfig`
  /// (Windows, carte "Wi-Fi", ligne "Adresse IPv4").
  static const String _devMachineLanIp = '192.168.1.161';

  /// localhost en Web (le navigateur tourne sur la même machine que le
  /// backend en dev) ; IP locale du PC pour toute autre plateforme (mobile
  /// physique, notamment).
  static String get baseUrl => kIsWeb ? 'http://localhost:3000' : 'http://$_devMachineLanIp:3000';

  String? _accessToken;
  String? _refreshToken;

  String? get refreshToken => _refreshToken;

  void setTokens({String? accessToken, String? refreshToken}) {
    if (accessToken != null) _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  Map<String, String> _headers({bool auth = true}) => {
        'Content-Type': 'application/json',
        if (auth && _accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool allowRetry = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = _headers(auth: auth);
    final encoded = body != null ? jsonEncode(body) : null;

    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: encoded);
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: encoded);
        break;
      default:
        throw UnsupportedError('Méthode HTTP non supportée : $method');
    }

    if (response.statusCode == 401 && auth && allowRetry && _refreshToken != null) {
      if (await _tryRefresh()) {
        return _request(method, path, body: body, auth: auth, allowRetry: false);
      }
    }

    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _extractError(response.body));
    }

    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) return decoded['error'].toString();
    } catch (_) {}
    return 'Une erreur est survenue';
  }

  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final uri = Uri.parse('$baseUrl/auth/refresh');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _accessToken = data['accessToken'] as String;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- Auth ----

  Future<Map<String, dynamic>> signup({
    required String nom,
    required String prenom,
    required String mobile,
    required String password,
    required String email,
    bool sousTraitant = false,
    String? societe,
  }) {
    return _request('POST', '/auth/signup', auth: false, body: {
      'nom': nom,
      'prenom': prenom,
      'mobile': mobile,
      'password': password,
      'email': email,
      'sousTraitant': sousTraitant,
      'societe': ?societe,
    });
  }

  Future<Map<String, dynamic>> signupInterne({
    required String nom,
    required String prenom,
    required String mobile,
    required String password,
    required String email,
    required String role,
  }) {
    return _request('POST', '/auth/signup-interne', auth: false, body: {
      'nom': nom,
      'prenom': prenom,
      'mobile': mobile,
      'password': password,
      'email': email,
      'role': role,
    });
  }

  Future<Map<String, dynamic>> login(String identifier, String password) {
    return _request('POST', '/auth/login', auth: false, body: {
      'identifier': identifier,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> me() => _request('GET', '/auth/me');

  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await _request('POST', '/auth/logout', auth: false, body: {'refreshToken': _refreshToken});
      } catch (_) {
        // Le serveur peut être injoignable : on nettoie quand même la session locale.
      }
    }
    clearTokens();
  }

  /// Restaure une session à partir d'un refresh token persisté (ex. démarrage de l'app).
  Future<bool> restoreSession(String refreshToken) async {
    _refreshToken = refreshToken;
    return _tryRefresh();
  }

  // ---- Comptes ----

  Future<List<dynamic>> getComptes() async {
    final data = await _request('GET', '/comptes');
    return data['installateurs'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> validerCompte(String id) => _request('POST', '/comptes/$id/valider');
  Future<Map<String, dynamic>> suspendreCompte(String id) => _request('POST', '/comptes/$id/suspendre');
  Future<Map<String, dynamic>> reactiverCompte(String id) => _request('POST', '/comptes/$id/reactiver');

  Future<Map<String, dynamic>> addHabilitation({required String titre, required String dateExpiration, required String file}) {
    return _request('POST', '/comptes/moi/habilitations', body: {
      'titre': titre,
      'dateExpiration': dateExpiration,
      'file': file,
    });
  }

  // ---- Admin ----

  Future<List<dynamic>> getComptesInternes() async {
    final data = await _request('GET', '/admin/comptes-internes');
    return data['comptesInternes'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> validerCompteInterne(String id) => _request('POST', '/admin/comptes-internes/$id/valider');

  Future<Map<String, dynamic>> getActivityFeed() => _request('GET', '/admin/activity');

  // ---- Chantiers ----

  Future<List<dynamic>> getChantiers() async {
    final data = await _request('GET', '/chantiers');
    return data['chantiers'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getChantier(String reference) => _request('GET', '/chantiers/$reference');

  Future<Map<String, dynamic>> createChantier(Map<String, dynamic> body) =>
      _request('POST', '/chantiers', body: body);

  Future<Map<String, dynamic>> rattacher(String reference, String userId) =>
      _request('POST', '/chantiers/$reference/rattacher', body: {'userId': userId});

  Future<void> markLivretOuvert(String reference) =>
      _request('POST', '/chantiers/$reference/livret-ouvert');

  Future<void> updatePoint(String reference, String pointId, {String? status, String? photo, String? clientValidatedAt}) {
    return _request('PATCH', '/chantiers/$reference/points/$pointId', body: {
      'status': ?status,
      'photo': ?photo,
      'clientValidatedAt': ?clientValidatedAt,
    });
  }

  Future<Map<String, dynamic>> postRex(String reference, {String? transcription, String? audio}) {
    return _request('POST', '/chantiers/$reference/rex', body: {
      'transcription': ?transcription,
      'audio': ?audio,
    });
  }

  Future<Map<String, dynamic>> postPv(String reference, String signataire, {String? signatureImage}) {
    return _request('POST', '/chantiers/$reference/pv', body: {
      'signataire': signataire,
      'signatureImage': ?signatureImage,
    });
  }

  Future<Map<String, dynamic>> addDocument(String reference, {required String titre, required String categorie, required String file}) {
    return _request('POST', '/chantiers/$reference/documents', body: {'titre': titre, 'categorie': categorie, 'file': file});
  }
}
