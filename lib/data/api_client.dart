import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
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

  /// Sur Vercel, frontend et backend sont servis sur la même origine — l'API
  /// répond sous /api (voir vercel.json et api/index.ts) : on construit un
  /// build web de prod (kReleaseMode) via `flutter build web`, jamais avec
  /// `flutter run`, donc ce cas ne couvre que le déploiement Vercel.
  /// En dev : localhost en Web (le navigateur tourne sur la même machine que
  /// le backend en dev) ; IP locale du PC pour toute autre plateforme (mobile
  /// physique, notamment).
  static String get baseUrl {
    if (kIsWeb && kReleaseMode) return '/api';
    return kIsWeb ? 'http://localhost:3000' : 'http://$_devMachineLanIp:3000';
  }

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
      case 'PUT':
        response = await http.put(uri, headers: headers, body: encoded);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers, body: encoded);
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

  Future<Map<String, dynamic>> requestEmailCode(String email) {
    return _request('POST', '/auth/request-email-code', auth: false, body: {'email': email});
  }

  Future<Map<String, dynamic>> verifyEmailCode(String email, String code) {
    return _request('POST', '/auth/verify-email-code', auth: false, body: {'email': email, 'code': code});
  }

  Future<Map<String, dynamic>> signup({
    required String nom,
    required String prenom,
    String? mobile,
    required String password,
    required String email,
    required String verificationTicket,
    bool sousTraitant = false,
    String? societe,
  }) {
    return _request('POST', '/auth/signup', auth: false, body: {
      'nom': nom,
      'prenom': prenom,
      'mobile': ?mobile,
      'password': password,
      'email': email,
      'verificationTicket': verificationTicket,
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

  Future<Map<String, dynamic>> requestPasswordReset(String email) {
    return _request('POST', '/auth/request-password-reset', auth: false, body: {'email': email});
  }

  Future<void> resetPassword({required String email, required String code, required String password}) {
    return _request('POST', '/auth/reset-password', auth: false, body: {
      'email': email,
      'code': code,
      'password': password,
    });
  }

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

  /// Suppression définitive — réservée à l'Admin côté back-office (voir la
  /// refonte des rôles) ; le backend rejette la requête pour tout autre rôle.
  Future<void> supprimerCompte(String id) => _request('DELETE', '/comptes/$id');

  /// Réinitialisation du mot de passe d'un installateur — CA/Direction/Admin.
  Future<void> reinitialiserMotDePasse(String id, String password) =>
      _request('POST', '/comptes/$id/reinitialiser-mot-de-passe', body: {'password': password});

  /// Modification du profil d'un installateur par le CA/Admin (distinct de
  /// updateProfile ci-dessus, qui modifie le compte connecté lui-même).
  Future<Map<String, dynamic>> updateCompte(String id,
      {String? nom, String? prenom, String? email, String? mobile, String? societe}) {
    return _request('PATCH', '/comptes/$id', body: {
      'nom': ?nom,
      'prenom': ?prenom,
      'email': ?email,
      'mobile': ?mobile,
      'societe': ?societe,
    });
  }

  Future<Map<String, dynamic>> updateProfile({String? nom, String? prenom, String? email, String? mobile, String? societe}) {
    return _request('PATCH', '/comptes/moi', body: {
      'nom': ?nom,
      'prenom': ?prenom,
      'email': ?email,
      'mobile': ?mobile,
      'societe': ?societe,
    });
  }

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

  Future<List<dynamic>> getAdminStats() async {
    final data = await _request('GET', '/admin/stats');
    return data['weeks'] as List<dynamic>;
  }

  /// Gestion globale des comptes (Admin) — tous les rôles sauf Admin,
  /// distinct de getComptes() qui ne renvoie que les installateurs.
  Future<List<dynamic>> getTousLesComptes() async {
    final data = await _request('GET', '/admin/comptes');
    return data['comptes'] as List<dynamic>;
  }

  /// Fiche détaillée d'un compte (n'importe quel rôle sauf Admin) — utilisée
  /// quand le compte n'est pas déjà dans la liste chargée localement (accès
  /// direct par lien, par exemple).
  Future<Map<String, dynamic>> getCompteAdmin(String id) => _request('GET', '/admin/comptes/$id');

  Future<Map<String, dynamic>> suspendreCompteAdmin(String id) => _request('POST', '/admin/comptes/$id/suspendre');
  Future<Map<String, dynamic>> reactiverCompteAdmin(String id) => _request('POST', '/admin/comptes/$id/reactiver');

  Future<void> reinitialiserMotDePasseAdmin(String id, String password) =>
      _request('POST', '/admin/comptes/$id/reinitialiser-mot-de-passe', body: {'password': password});

  Future<void> supprimerCompteAdmin(String id) => _request('DELETE', '/admin/comptes/$id');

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

  Future<Map<String, dynamic>> detacher(String reference, String userId) =>
      _request('DELETE', '/chantiers/$reference/rattacher/$userId');

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

  /// Supprime le REX d'un chantier (CA/Admin) — seule façon de débloquer
  /// l'installateur pour qu'il puisse en soumettre un nouveau.
  Future<Map<String, dynamic>> deleteRex(String reference) =>
      _request('DELETE', '/chantiers/$reference/rex');

  /// Dépôt (ou remplacement) du gabarit PV par le back-office — ne valide
  /// rien, voir signPv pour la signature qui valide effectivement le PV.
  Future<Map<String, dynamic>> uploadPvDocument(String reference, String file) {
    return _request('POST', '/chantiers/$reference/pv/document', body: {'file': file});
  }

  /// Signature du PV par le client, soumise par l'installateur — le client
  /// signe directement sur le PDF affiché, [signatureImage] est l'image PNG
  /// du tracé seul et [pageNumber]/[x]/[y]/[width]/[height] sa position sur
  /// le document (points PDF, origine bas-gauche — voir
  /// lib/screens/client/signature_screen.dart) ; la fusion avec le PDF
  /// gabarit (préservation intégrale de son texte et ses vecteurs) se fait
  /// côté serveur, voir backend/src/lib/pvMerge.ts.
  Future<Map<String, dynamic>> signPv(
    String reference, {
    required String nomSignataire,
    required String fonctionSignataire,
    required String signatureImage,
    required int pageNumber,
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    return _request('POST', '/chantiers/$reference/pv/signature', body: {
      'nomSignataire': nomSignataire,
      'fonctionSignataire': fonctionSignataire,
      'signatureImage': signatureImage,
      'pageNumber': pageNumber,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
  }

  /// Supprime définitivement le PV d'un chantier (CA/Admin) — gabarit et
  /// signature éventuelle.
  Future<Map<String, dynamic>> deletePv(String reference) =>
      _request('DELETE', '/chantiers/$reference/pv');

  Future<Map<String, dynamic>> addDocument(String reference, {required String titre, required String categorie, required String file}) {
    return _request('POST', '/chantiers/$reference/documents', body: {'titre': titre, 'categorie': categorie, 'file': file});
  }

  /// Suppression d'un document terrain (Module 8) — réservée à son auteur ou
  /// à un CA/Admin (vérifié côté serveur).
  Future<Map<String, dynamic>> deleteDocument(String reference, String docId) =>
      _request('DELETE', '/chantiers/$reference/documents/$docId');

  Future<Map<String, dynamic>> addDocumentChantier(String reference,
      {required String type, required String nom, String? nomFichierOriginal, required String file}) {
    return _request('POST', '/chantiers/$reference/documents-chantier', body: {
      'type': type,
      'nom': nom,
      'nomFichierOriginal': ?nomFichierOriginal,
      'file': file,
    });
  }

  Future<Map<String, dynamic>> deleteDocumentChantier(String reference, String docId) =>
      _request('DELETE', '/chantiers/$reference/documents-chantier/$docId');

  Future<Map<String, dynamic>> replaceDocumentChantier(String reference, String docId,
      {required String file, String? nomFichierOriginal}) {
    return _request('PUT', '/chantiers/$reference/documents-chantier/$docId', body: {
      'file': file,
      'nomFichierOriginal': ?nomFichierOriginal,
    });
  }

  /// Modification et suppression d'un chantier — réservées à l'Admin côté
  /// back-office (voir la refonte des rôles) ; le backend rejette la requête
  /// pour tout autre rôle.
  Future<Map<String, dynamic>> updateChantier(String reference, Map<String, dynamic> body) =>
      _request('PATCH', '/chantiers/$reference', body: body);

  Future<void> deleteChantier(String reference) => _request('DELETE', '/chantiers/$reference');

  // ---- Notifications ----

  Future<List<dynamic>> getNotifications() async {
    final data = await _request('GET', '/notifications');
    return data['notifications'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> marquerNotificationLue(String id) =>
      _request('PATCH', '/notifications/$id/lue');
}
