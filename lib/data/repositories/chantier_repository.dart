import '../api_client.dart';
import '../local/app_database.dart';
import '../models/user.dart';
import '../models/chantier.dart';

class ChantierRepository {
  final ApiClient _api;
  final AppDatabase _db;

  ChantierRepository(this._api, this._db);

  /// Lecture hors-ligne : tente le réseau, et retombe sur le cache local en
  /// cas d'échec (pas de réseau, serveur injoignable).
  Future<List<Chantier>> getMyChantiers(User user) async {
    try {
      final data = await _api.getChantiers();
      final chantiers = data.cast<Map<String, dynamic>>();
      await _db.replaceAllChantiers(chantiers);
      return chantiers.map(Chantier.fromJson).toList();
    } catch (_) {
      final cached = await _db.getAllCachedChantiers();
      return cached.map(Chantier.fromJson).toList();
    }
  }

  Future<Chantier> getChantier(String reference) async {
    try {
      final data = await _api.getChantier(reference);
      final json = data['chantier'] as Map<String, dynamic>;
      await _db.cacheChantier(json);
      return Chantier.fromJson(json);
    } catch (_) {
      final cached = await _db.getCachedChantier(reference);
      if (cached != null) return Chantier.fromJson(cached);
      rethrow;
    }
  }

  Future<Chantier> createChantier(Map<String, dynamic> body) async {
    final data = await _api.createChantier(body);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  Future<Chantier> rattacher(String reference, String userId) async {
    final data = await _api.rattacher(reference, userId);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  /// Écriture hors-ligne : si l'appel réseau échoue, l'action est mise en
  /// file d'attente locale (table PendingOperations) pour être rejouée par le
  /// SyncEngine dès que le réseau revient.
  Future<void> markLivretOuvert(String reference) async {
    try {
      await _api.markLivretOuvert(reference);
    } catch (_) {
      await _db.enqueueOperation(type: 'markLivretOuvert', chantierReference: reference, payload: const {});
    }
  }

  /// [status] et/ou [photo] (JPEG compressé, en data URL base64) sont
  /// horodatés côté client (heure réelle de l'action terrain) plutôt que côté
  /// serveur, qui ne les recevra parfois que bien plus tard si l'installateur
  /// était hors-ligne au moment de l'action.
  Future<void> updatePoint(String reference, String pointId, {String? status, String? photo}) async {
    final clientValidatedAt = status != null ? DateTime.now().toIso8601String() : null;
    try {
      await _api.updatePoint(reference, pointId, status: status, photo: photo, clientValidatedAt: clientValidatedAt);
    } catch (_) {
      await _db.enqueueOperation(
        type: 'updatePoint',
        chantierReference: reference,
        payload: {
          'pointId': pointId,
          'status': ?status,
          'photo': ?photo,
          'clientValidatedAt': ?clientValidatedAt,
        },
      );
    }
  }

  /// [transcription] (texte) et/ou [audio] (note vocale compressée, en data
  /// URL base64) — l'un des deux suffit. La transcription automatique
  /// (Whisper) n'est pas requise pour la V1 : l'audio seul est accepté.
  Future<Chantier> submitRex(String reference, {String? transcription, String? audio}) async {
    try {
      final data = await _api.postRex(reference, transcription: transcription, audio: audio);
      return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
    } catch (_) {
      await _db.enqueueOperation(
        type: 'submitRex',
        chantierReference: reference,
        payload: {'transcription': ?transcription, 'audio': ?audio},
      );
      return getChantier(reference);
    }
  }

  Future<Chantier> submitPv(String reference, String signataire, {String? signatureImage}) async {
    try {
      final data = await _api.postPv(reference, signataire, signatureImage: signatureImage);
      return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
    } catch (_) {
      // L'image de signature (base64) est stockée telle quelle dans la file
      // d'attente locale — elle n'est donc jamais perdue si l'app est fermée
      // hors-ligne, et part vers l'API dès que le SyncEngine la rejoue.
      await _db.enqueueOperation(
        type: 'submitPv',
        chantierReference: reference,
        payload: {'signataire': signataire, 'signatureImage': ?signatureImage},
      );
      return getChantier(reference);
    }
  }

  /// [file] : photo ou PDF, en data URL base64 (compressé côté client pour
  /// les photos) — requis, comme pour les autres pièces jointes hors-ligne.
  Future<void> addDocument(String reference, {required String titre, required String categorie, required String file}) async {
    try {
      await _api.addDocument(reference, titre: titre, categorie: categorie, file: file);
    } catch (_) {
      await _db.enqueueOperation(
        type: 'addDocument',
        chantierReference: reference,
        payload: {'titre': titre, 'categorie': categorie, 'file': file},
      );
    }
  }
}
