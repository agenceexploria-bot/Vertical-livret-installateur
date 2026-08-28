import '../api_client.dart';
import '../local/app_database.dart';
import '../models/user.dart';
import '../models/chantier.dart';
import '../models/point_controle.dart';
import '../models/document_terrain.dart';

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

  /// Lecture cache uniquement (aucun appel réseau) — utilisée pour afficher
  /// la liste instantanément à l'ouverture de l'écran (voir
  /// ChantierState.fetchChantiers, pattern stale-while-revalidate).
  Future<List<Chantier>> getCachedChantiers() async {
    final cached = await _db.getAllCachedChantiers();
    return cached.map(Chantier.fromJson).toList();
  }

  /// Écrit un chantier déjà muté de façon optimiste (ChantierState) dans le
  /// cache Drift, pour que l'action (suppression, détachement...) survive un
  /// rechargement immédiat sans attendre la réponse serveur.
  Future<void> cacheChantierLocally(Chantier chantier) => _db.cacheChantier(chantier.toJson());

  Future<void> removeCachedChantier(String reference) => _db.deleteCachedChantier(reference);

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

  Future<Chantier> detacher(String reference, String userId) async {
    final data = await _api.detacher(reference, userId);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  /// Modification et suppression d'un chantier — réservées à l'Admin (voir la
  /// refonte des rôles back-office) ; le backend rejette la requête sinon.
  Future<Chantier> updateChantier(String reference, Map<String, dynamic> body) async {
    final data = await _api.updateChantier(reference, body);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  Future<void> deleteChantier(String reference) => _api.deleteChantier(reference);

  /// Dépôt d'un document de référence (PPSPS, plan, vidéo...) par le CT —
  /// action back-office web, pas de file d'attente hors-ligne (comme
  /// [createChantier] et [rattacher], qui supposent déjà un réseau
  /// disponible). [file] est déposé directement sur Vercel Blob (voir
  /// [ApiClient.uploadFile]) avant de créer l'enregistrement — [nom] est
  /// optionnel, le nom du fichier d'origine fait l'affaire à défaut.
  Future<Chantier> addDocumentChantier(String reference,
      {required String type, String? nom, String? nomFichierOriginal, required String file}) async {
    final fileUrl = await _api.uploadFile(kind: 'documentChantier', dataUrl: file, filename: nomFichierOriginal);
    final data = await _api.addDocumentChantier(reference,
        type: type, nom: nom, nomFichierOriginal: nomFichierOriginal, fileUrl: fileUrl);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  /// Suppression et remplacement du fichier d'un document chantier — en base
  /// ET sur Vercel Blob côté serveur (voir la route backend), pour ne pas
  /// laisser de fichiers orphelins stockés indéfiniment.
  Future<Chantier> deleteDocumentChantier(String reference, String docId) async {
    final data = await _api.deleteDocumentChantier(reference, docId);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  Future<Chantier> replaceDocumentChantier(String reference, String docId,
      {required String file, String? nomFichierOriginal}) async {
    final fileUrl = await _api.uploadFile(kind: 'documentChantier', dataUrl: file, filename: nomFichierOriginal);
    final data = await _api.replaceDocumentChantier(reference, docId, fileUrl: fileUrl, nomFichierOriginal: nomFichierOriginal);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  /// Applique la même mutation qu'une action réussie directement sur le
  /// chantier mis en cache (Drift), pour que l'écran reflète l'action
  /// immédiatement même hors-ligne — sans ça, le prochain [getChantier]
  /// retomberait sur le cache resté figé à l'état d'avant l'action, et
  /// l'installateur croirait que son geste n'a pas été pris en compte.
  Future<void> _applyOptimisticUpdate(String reference, void Function(Chantier) mutate) async {
    final cached = await _db.getCachedChantier(reference);
    if (cached == null) return;
    final chantier = Chantier.fromJson(cached);
    mutate(chantier);
    await _db.cacheChantier(chantier.toJson());
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
  /// était hors-ligne au moment de l'action. [validatedByName] n'est utilisé
  /// que pour la mise à jour optimiste locale (l'attribution nominative
  /// envoyée au serveur est toujours dérivée du compte connecté côté API,
  /// jamais d'une valeur fournie par le client).
  Future<void> updatePoint(String reference, String pointId, {String? status, String? photo, String? validatedByName}) async {
    final clientValidatedAt = status != null ? DateTime.now().toIso8601String() : null;
    try {
      final photoUrl = photo != null ? await _api.uploadFile(kind: 'pointPhoto', dataUrl: photo) : null;
      await _api.updatePoint(reference, pointId, status: status, photoUrl: photoUrl, clientValidatedAt: clientValidatedAt);
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
      await _applyOptimisticUpdate(reference, (chantier) {
        for (final point in [...chantier.receptionMarchandises, ...chantier.autoControle]) {
          if (point.id != pointId) continue;
          if (status != null) point.status = PointStatus.values.firstWhere((s) => s.name == status);
          if (photo != null) point.photoPath = photo;
          // Une annulation de validation (retour à `vide`) efface l'attribution,
          // comme côté serveur (voir PATCH .../points/:pointId).
          if (status == 'vide') {
            point.validePar = null;
            point.valideAt = null;
          } else {
            if (validatedByName != null) point.validePar = validatedByName;
            if (clientValidatedAt != null) point.valideAt = DateTime.parse(clientValidatedAt);
          }
          break;
        }
      });
    }
  }

  /// [transcription] (texte) et/ou [audio] (note vocale compressée, en data
  /// URL base64) — l'un des deux suffit, l'audio seul est accepté. Si
  /// [transcription] est absente, le backend tente une transcription
  /// automatique de l'audio (voir backend/src/lib/transcription.ts).
  Future<Chantier> submitRex(String reference, {String? transcription, String? audio}) async {
    try {
      final audioUrl = audio != null ? await _api.uploadFile(kind: 'rexAudio', dataUrl: audio) : null;
      final data = await _api.postRex(reference, transcription: transcription, audioUrl: audioUrl);
      return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
    } catch (_) {
      await _db.enqueueOperation(
        type: 'submitRex',
        chantierReference: reference,
        payload: {'transcription': ?transcription, 'audio': ?audio},
      );
      await _applyOptimisticUpdate(reference, (chantier) {
        chantier.rex.insert(0, Rex(id: 'local-${DateTime.now().microsecondsSinceEpoch}', transcription: transcription, soumisAt: DateTime.now()));
      });
      return getChantier(reference);
    }
  }

  /// Supprime une entrée REX précise (CT/Admin, back-office) — action
  /// toujours en ligne, comme [deleteChantier]/[deleteDocumentChantier].
  Future<Chantier> deleteRex(String reference, String rexId) async {
    final data = await _api.deleteRex(reference, rexId);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  /// Dépôt du gabarit PV par le back-office — toujours en ligne, comme
  /// [addDocumentChantier] (action web, pas de file d'attente hors-ligne).
  Future<Chantier> uploadPvDocument(String reference, String file) async {
    final fileUrl = await _api.uploadFile(kind: 'pvDocument', dataUrl: file);
    final data = await _api.uploadPvDocument(reference, fileUrl);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  /// Signature du PV par le client, soumise par l'installateur — toujours en
  /// ligne : la fusion gabarit + signature se fait côté serveur (voir
  /// ApiClient.signPv), donc pas de file d'attente hors-ligne possible ici.
  Future<Chantier> signPv(
    String reference, {
    required String nomSignataire,
    required String fonctionSignataire,
    required String signatureImage,
    required int pageNumber,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    final data = await _api.signPv(
      reference,
      nomSignataire: nomSignataire,
      fonctionSignataire: fonctionSignataire,
      signatureImage: signatureImage,
      pageNumber: pageNumber,
      x: x,
      y: y,
      width: width,
      height: height,
    );
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  /// Supprime définitivement le PV d'un chantier (CT/Admin, back-office) —
  /// action toujours en ligne, comme [deleteRex]/[deleteChantier].
  Future<Chantier> deletePv(String reference) async {
    final data = await _api.deletePv(reference);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  /// Suppression d'un document terrain (Module 8) — toujours en ligne, comme
  /// [deleteDocumentChantier] (action destructive, pas de file d'attente).
  Future<Chantier> deleteDocument(String reference, String docId) async {
    final data = await _api.deleteDocument(reference, docId);
    return Chantier.fromJson(data['chantier'] as Map<String, dynamic>);
  }

  /// [file] : photo ou PDF, en data URL base64 (compressé côté client pour
  /// les photos) — requis, comme pour les autres pièces jointes hors-ligne.
  /// [auteurName] n'est utilisé que pour l'affichage optimiste local.
  Future<void> addDocument(String reference, {required String titre, required String categorie, required String file, String? auteurName}) async {
    try {
      final fileUrl = await _api.uploadFile(kind: 'documentTerrain', dataUrl: file);
      await _api.addDocument(reference, titre: titre, categorie: categorie, fileUrl: fileUrl);
    } catch (_) {
      await _db.enqueueOperation(
        type: 'addDocument',
        chantierReference: reference,
        payload: {'titre': titre, 'categorie': categorie, 'file': file},
      );
      await _applyOptimisticUpdate(reference, (chantier) {
        chantier.docsTerrain.add(DocumentTerrain(
          titre: titre,
          categorie: CategorieDocument.values.firstWhere((c) => c.name == categorie),
          horodatage: DateTime.now(),
          auteur: auteurName ?? '',
          envoye: false,
        ));
      });
    }
  }
}
