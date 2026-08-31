import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:http/http.dart' as http;
import '../core/blob_filename.dart';

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

  /// Dépose un fichier (fourni en data URL base64, ex. "data:image/jpeg;base64,...")
  /// directement sur Vercel Blob plutôt que dans le corps JSON d'une requête à
  /// cette API — le corps des requêtes de nos fonctions serverless est
  /// plafonné à 4,5 Mo par Vercel, une limite non contournable côté code (voir
  /// backend/src/routes/uploads.ts). [kind] détermine, côté serveur, le type
  /// de fichier et la taille max réellement autorisés (jamais dictés par le
  /// client). Renvoie l'URL publique du fichier déposé, à transmettre ensuite
  /// à l'endpoint métier concerné (ex. addDocumentChantier).
  Future<String> uploadFile({required String kind, required String dataUrl, String? filename}) async {
    final match = RegExp(r'^data:([\w-]+/[\w.+-]+);base64,(.+)$').firstMatch(dataUrl);
    if (match == null) throw ApiException(0, 'Fichier invalide.');
    final contentType = match.group(1)!;
    final bytes = base64Decode(match.group(2)!);
    // Le nom d'origine (accents, espaces, tirets cadratins, points médians...)
    // n'est jamais utilisé tel quel comme chemin de stockage : mal encodé, il
    // peut faire échouer la validation du jeton côté Blob pour ce fichier
    // précis — voir [sanitizeBlobFilename].
    final resolvedFilename = sanitizeBlobFilename(filename ?? '$kind.${contentType.split('/').last}');

    final tokenData = await _request('POST', '/uploads/token', body: {
      'type': 'blob.generate-client-token',
      'payload': {
        'pathname': resolvedFilename,
        'callbackUrl': '$baseUrl/uploads/token',
        'clientPayload': jsonEncode({'kind': kind}),
        'multipart': false,
      },
    });
    final clientToken = tokenData['clientToken'] as String;

    final uri = Uri.parse('https://blob.vercel-storage.com/').replace(queryParameters: {'pathname': resolvedFilename});
    http.Response response;
    try {
      response = await http.put(uri, headers: {
        'authorization': 'Bearer $clientToken',
        'x-api-version': '9',
        'x-content-type': contentType,
      }, body: bytes);
    } catch (_) {
      throw ApiException(0, 'Erreur réseau. Vérifiez votre connexion.');
    }
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _extractBlobError(response.body));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Messages lisibles pour les erreurs renvoyées par Vercel Blob lors du
  /// dépôt direct (forme `{ error: { code, message } }`, distincte de celle
  /// de notre propre API — voir [_extractError]).
  String _extractBlobError(String body) {
    try {
      final decoded = jsonDecode(body);
      final error = decoded is Map ? decoded['error'] : null;
      final code = error is Map ? error['code'] : null;
      switch (code) {
        case 'file_too_large':
          return 'Ce fichier est trop volumineux.';
        case 'content_type_not_allowed':
          return 'Ce type de fichier n\'est pas autorisé ici.';
        case 'client_token_expired':
          // Le jeton d'upload est valable peu de temps — un envoi trop lent
          // (gros fichier, réseau lent) peut expirer avant la fin du dépôt.
          // Un nouveau clic sur "Réessayer" redemande un jeton frais (voir
          // uploadFile, qui refait tout le cycle à chaque appel).
          return 'L\'envoi a pris trop de temps et le lien a expiré. Réessayez.';
        case 'forbidden':
          return 'Accès refusé pour cet envoi. Réessayez.';
        case 'store_not_found':
        case 'store_suspended':
          return 'Le service de stockage est momentanément indisponible. Réessayez dans quelques instants.';
        default:
          return 'Impossible d\'envoyer le fichier. Réessayez.';
      }
    } catch (_) {
      return 'Erreur réseau. Vérifiez votre connexion.';
    }
  }

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
    try {
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
    } on UnsupportedError {
      rethrow;
    } catch (_) {
      // Aucune réponse HTTP reçue (pas de réseau, DNS, serveur injoignable,
      // timeout...) — distinct d'une réponse d'erreur du serveur (voir
      // _extractError ci-dessous), mais message identique côté utilisateur :
      // dans les deux cas, il n'y a rien de plus précis à lui dire.
      throw ApiException(0, 'Erreur réseau. Vérifiez votre connexion.');
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

  /// Extrait TOUJOURS un message lisible en français depuis le corps d'une
  /// réponse d'erreur — jamais de JSON brut (accolades/crochets) affiché à
  /// l'utilisateur, quelle que soit la forme de `{ error: ... }` :
  /// - chaîne simple (ex. "Identifiants incorrects") : renvoyée telle quelle.
  /// - objet `zod`'s `.flatten()` (`{ formErrors: [...], fieldErrors: {
  ///   champ: [...] } }`, voir tous les `parsed.error.flatten()` de
  ///   backend/src/routes/*.ts) : premier message de champ, sinon premier
  ///   message global.
  /// - objet d'erreur Prisma échappé sans passer par un message applicatif
  ///   (ex. contrainte unique P2002 non interceptée en amont côté backend) :
  ///   message générique, jamais le détail technique (nom de contrainte SQL,
  ///   colonnes...).
  /// - corps qui n'est pas du JSON valide (page d'erreur HTML de la
  ///   plateforme, timeout de proxy...) : traité comme une erreur réseau, il
  ///   n'y a rien de plus précis à dire à l'utilisateur dans ce cas.
  String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return 'Une erreur est survenue. Réessayez.';
      final error = decoded['error'];
      if (error is String) return error;
      if (error is Map) {
        final fieldErrors = error['fieldErrors'];
        if (fieldErrors is Map) {
          for (final messages in fieldErrors.values) {
            if (messages is List && messages.isNotEmpty) return messages.first.toString();
          }
        }
        final formErrors = error['formErrors'];
        if (formErrors is List && formErrors.isNotEmpty) return formErrors.first.toString();

        // Forme d'une erreur Prisma (PrismaClientKnownRequestError.toJSON()
        // ou équivalent) : { code: 'P2002', meta: {...}, message: '...' }.
        final code = error['code'];
        if (code is String && code.startsWith('P2')) {
          return code == 'P2002' ? 'Cette valeur est déjà utilisée par un autre compte.' : 'Une erreur est survenue. Réessayez.';
        }
      }
      return 'Une erreur est survenue. Réessayez.';
    } catch (_) {
      return 'Erreur réseau. Vérifiez votre connexion.';
    }
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

  /// Réinitialisation du mot de passe d'un installateur — CT/Direction/Admin.
  Future<void> reinitialiserMotDePasse(String id, String password) =>
      _request('POST', '/comptes/$id/reinitialiser-mot-de-passe', body: {'password': password});

  /// Modification du profil d'un installateur par le CT/Admin (distinct de
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

  Future<Map<String, dynamic>> addHabilitation({required String titre, required String dateExpiration, required String fileUrl}) {
    return _request('POST', '/comptes/moi/habilitations', body: {
      'titre': titre,
      'dateExpiration': dateExpiration,
      'fileUrl': fileUrl,
    });
  }

  /// [fileUrl] : photo de profil (JPEG/PNG) déjà déposée sur Vercel Blob —
  /// voir [uploadFile].
  Future<Map<String, dynamic>> uploadAvatar(String fileUrl) {
    return _request('POST', '/comptes/moi/avatar', body: {'fileUrl': fileUrl});
  }

  Future<Map<String, dynamic>> deleteAvatar() {
    return _request('DELETE', '/comptes/moi/avatar');
  }

  // ---- Temps réel (Pusher) ----

  /// Autorisation d'abonnement à un canal privé Pusher — voir
  /// RealtimeService._authorizer et backend/src/routes/pusherAuth.ts. Le JWT
  /// courant est déjà joint via les headers de [_request], comme pour tout
  /// autre appel authentifié de l'app.
  Future<Map<String, dynamic>> pusherAuth({required String socketId, required String channelName}) {
    return _request('POST', '/pusher/auth', body: {'socket_id': socketId, 'channel_name': channelName});
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

  Future<void> updatePoint(String reference, String pointId, {String? status, String? photoUrl, String? clientValidatedAt}) {
    return _request('PATCH', '/chantiers/$reference/points/$pointId', body: {
      'status': ?status,
      'photoUrl': ?photoUrl,
      'clientValidatedAt': ?clientValidatedAt,
    });
  }

  Future<Map<String, dynamic>> postRex(String reference, {String? transcription, String? audioUrl}) {
    return _request('POST', '/chantiers/$reference/rex', body: {
      'transcription': ?transcription,
      'audioUrl': ?audioUrl,
    });
  }

  /// Supprime une entrée REX précise (CT/Admin) — les autres entrées REX du
  /// chantier ne sont pas affectées.
  Future<Map<String, dynamic>> deleteRex(String reference, String rexId) =>
      _request('DELETE', '/chantiers/$reference/rex/$rexId');

  /// Dépôt (ou remplacement) du gabarit PV par le back-office — ne valide
  /// rien, voir signPv pour la signature qui valide effectivement le PV.
  Future<Map<String, dynamic>> uploadPvDocument(String reference, String fileUrl) {
    return _request('POST', '/chantiers/$reference/pv/document', body: {'fileUrl': fileUrl});
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

  /// Validation du formulaire PV interactif par l'installateur — contrairement
  /// à [signPv] (signature sur un gabarit PDF déjà déposé), il n'y a pas de
  /// gabarit ici : le backend génère le PDF final de toutes pièces à partir
  /// de [reponses] et de la signature (voir backend/src/lib/pvFormPdf.ts).
  /// [dateReception] au format `AAAA-MM-JJ`.
  Future<Map<String, dynamic>> postPvReponses(
    String reference, {
    required Map<String, dynamic> reponses,
    required String dateReception,
    required String nomSignataire,
    required String fonctionSignataire,
    required String signatureImage,
  }) {
    return _request('POST', '/chantiers/$reference/pv/reponses', body: {
      'reponses': reponses,
      'dateReception': dateReception,
      'nomSignataire': nomSignataire,
      'fonctionSignataire': fonctionSignataire,
      'signatureImage': signatureImage,
    });
  }

  /// Supprime définitivement le PV d'un chantier (CT/Admin) — gabarit et
  /// signature éventuelle.
  Future<Map<String, dynamic>> deletePv(String reference) =>
      _request('DELETE', '/chantiers/$reference/pv');

  Future<Map<String, dynamic>> addDocument(String reference, {required String titre, required String categorie, required String fileUrl}) {
    return _request('POST', '/chantiers/$reference/documents', body: {'titre': titre, 'categorie': categorie, 'fileUrl': fileUrl});
  }

  /// Suppression d'un document terrain (Module 8) — réservée à son auteur ou
  /// à un CT/Admin (vérifié côté serveur).
  Future<Map<String, dynamic>> deleteDocument(String reference, String docId) =>
      _request('DELETE', '/chantiers/$reference/documents/$docId');

  Future<Map<String, dynamic>> addDocumentChantier(String reference,
      {required String type, String? nom, String? nomFichierOriginal, required String fileUrl}) {
    return _request('POST', '/chantiers/$reference/documents-chantier', body: {
      'type': type,
      'nom': ?nom,
      'nomFichierOriginal': ?nomFichierOriginal,
      'fileUrl': fileUrl,
    });
  }

  Future<Map<String, dynamic>> deleteDocumentChantier(String reference, String docId) =>
      _request('DELETE', '/chantiers/$reference/documents-chantier/$docId');

  Future<Map<String, dynamic>> replaceDocumentChantier(String reference, String docId,
      {required String fileUrl, String? nomFichierOriginal}) {
    return _request('PUT', '/chantiers/$reference/documents-chantier/$docId', body: {
      'fileUrl': fileUrl,
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

  // ---- Listes de réception/contrôle (Admin) ----

  Future<List<dynamic>> getChecklistTemplates() async {
    final data = await _request('GET', '/checklist-templates');
    return data['items'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> addChecklistTemplateItem({
    required String type,
    required String categorie,
    required String libelle,
    bool critique = false,
  }) {
    return _request('POST', '/checklist-templates', body: {
      'type': type,
      'categorie': categorie,
      'libelle': libelle,
      'critique': critique,
    });
  }

  Future<Map<String, dynamic>> updateChecklistTemplateItem(String id, {String? categorie, String? libelle, bool? critique}) {
    return _request('PATCH', '/checklist-templates/$id', body: {
      'categorie': ?categorie,
      'libelle': ?libelle,
      'critique': ?critique,
    });
  }

  Future<void> deleteChecklistTemplateItem(String id) => _request('DELETE', '/checklist-templates/$id');
}
