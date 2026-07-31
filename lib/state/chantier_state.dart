import 'package:flutter/material.dart';
import '../data/models/chantier.dart';
import '../data/models/document_chantier.dart';
import '../data/models/document_terrain.dart';
import '../data/models/point_controle.dart';
import '../data/models/user.dart';
import '../data/repositories/chantier_repository.dart';

class ChantierState extends ChangeNotifier {
  final ChantierRepository _repository;
  List<Chantier> _chantiers = [];
  Chantier? _currentChantier;
  bool _isLoading = false;

  ChantierState(this._repository);

  List<Chantier> get chantiers => _chantiers;
  Chantier? get currentChantier => _currentChantier;
  bool get isLoading => _isLoading;

  /// Stale-while-revalidate : si le cache Drift a déjà des chantiers, ils
  /// s'affichent immédiatement (pas de spinner) pendant que le réseau
  /// rafraîchit en arrière-plan — l'écran ne reste bloqué sur un chargeur que
  /// s'il n'y a vraiment rien à montrer.
  Future<void> fetchChantiers(User user) async {
    final cached = await _repository.getCachedChantiers();
    if (cached.isNotEmpty) {
      _chantiers = cached;
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _chantiers = await _repository.getMyChantiers(user);
    } finally {
      _isLoading = false;
    }

    // Vérification de la veille (EX-22) : ouvrir la liste de ses chantiers
    // marque le livret comme consulté pour cet installateur.
    if (user.role == UserRole.installateur) {
      for (final c in _chantiers) {
        c.livretsOuverts.add(user.id);
      }
      await Future.wait(_chantiers.map((c) => _repository.markLivretOuvert(c.reference)));
    }
    notifyListeners();
  }

  void selectChantier(Chantier chantier) {
    _currentChantier = chantier;
    notifyListeners();
  }

  Chantier? findByReference(String reference) {
    for (final c in _chantiers) {
      if (c.reference == reference) return c;
    }
    return null;
  }

  Future<void> createChantier(Map<String, dynamic> body) async {
    final created = await _repository.createChantier(body);
    _chantiers = [..._chantiers, created];
    notifyListeners();
  }

  Future<void> rattacher(String reference, String userId) async {
    final updated = await _repository.rattacher(reference, userId);
    _replaceInList(updated);
  }

  /// Optimistic UI : l'installateur disparaît immédiatement de la liste des
  /// rattachés, avec réaffichage en cas d'échec réseau réel.
  Future<void> detacher(String reference, String userId) async {
    final chantier = findByReference(reference);
    User? removed;
    if (chantier != null) {
      for (final u in chantier.installateursRattaches) {
        if (u.id == userId) {
          removed = u;
          break;
        }
      }
      if (removed != null) chantier.installateursRattaches.remove(removed);
      notifyListeners();
      await _repository.cacheChantierLocally(chantier);
    }
    try {
      final updated = await _repository.detacher(reference, userId);
      _replaceInList(updated);
    } catch (e) {
      if (chantier != null && removed != null) {
        chantier.installateursRattaches.add(removed);
        notifyListeners();
        await _repository.cacheChantierLocally(chantier);
      }
      rethrow;
    }
  }

  /// Modification et suppression d'un chantier (Admin uniquement — voir la
  /// refonte des rôles back-office).
  Future<void> updateChantier(String reference, Map<String, dynamic> body) async {
    final updated = await _repository.updateChantier(reference, body);
    _replaceInList(updated);
  }

  /// Optimistic UI : le chantier disparaît immédiatement de la liste (et du
  /// cache Drift), avec réaffichage en cas d'échec réseau réel.
  Future<void> deleteChantier(String reference) async {
    final removedChantier = findByReference(reference);
    final wasCurrent = _currentChantier?.reference == reference;
    _chantiers = _chantiers.where((c) => c.reference != reference).toList();
    if (wasCurrent) _currentChantier = null;
    notifyListeners();
    await _repository.removeCachedChantier(reference);

    try {
      await _repository.deleteChantier(reference);
    } catch (e) {
      if (removedChantier != null) {
        _chantiers = [..._chantiers, removedChantier];
        if (wasCurrent) _currentChantier = removedChantier;
        notifyListeners();
        await _repository.cacheChantierLocally(removedChantier);
      }
      rethrow;
    }
  }

  Future<void> addDocumentChantier(String reference,
      {required String type, required String nom, String? nomFichierOriginal, required String file}) async {
    final updated = await _repository.addDocumentChantier(reference,
        type: type, nom: nom, nomFichierOriginal: nomFichierOriginal, file: file);
    _replaceInList(updated);
  }

  /// Optimistic UI : le document disparaît immédiatement de la liste. En cas
  /// d'échec réseau (pas de file d'attente hors-ligne pour cette action CA),
  /// on le réaffiche et on laisse l'erreur remonter à l'écran appelant.
  Future<void> deleteDocumentChantier(String reference, String docId) async {
    final chantier = findByReference(reference);
    DocumentChantier? removed;
    if (chantier != null) {
      for (final d in chantier.documentsChantier) {
        if (d.id == docId) {
          removed = d;
          break;
        }
      }
      if (removed != null) chantier.documentsChantier.remove(removed);
      notifyListeners();
      await _repository.cacheChantierLocally(chantier);
    }
    try {
      final updated = await _repository.deleteDocumentChantier(reference, docId);
      _replaceInList(updated);
    } catch (e) {
      if (chantier != null && removed != null) {
        chantier.documentsChantier.add(removed);
        notifyListeners();
        await _repository.cacheChantierLocally(chantier);
      }
      rethrow;
    }
  }

  Future<void> replaceDocumentChantier(String reference, String docId,
      {required String file, String? nomFichierOriginal}) async {
    final updated = await _repository.replaceDocumentChantier(reference, docId, file: file, nomFichierOriginal: nomFichierOriginal);
    _replaceInList(updated);
  }

  /// Optimistic UI : le point est mis à jour dans l'état local ET l'écran
  /// notifié AVANT même l'appel réseau — l'installateur voit sa coche/photo
  /// s'appliquer instantanément, l'appel API (et la file d'attente hors-ligne
  /// si besoin, voir ChantierRepository) se fait en arrière-plan. Pas de
  /// refetch complet du chantier ensuite : inutile et coûteux en latence
  /// perçue, la mutation locale reflète déjà exactement ce que fera le serveur
  /// (même règle isPointComplete des deux côtés), et l'événement Pusher
  /// chantier-changed (s'il est configuré) rattrapera tout écart éventuel.
  Future<void> updatePoint(String reference, String pointId, {String? status, String? photo, String? validatedByName}) async {
    final chantier = findByReference(reference);
    if (chantier != null) {
      for (final point in [...chantier.receptionMarchandises, ...chantier.autoControle]) {
        if (point.id != pointId) continue;
        if (status != null) {
          point.status = PointStatus.values.firstWhere((s) => s.name == status);
          if (status == 'vide') {
            point.validePar = null;
            point.valideAt = null;
          } else {
            if (validatedByName != null) point.validePar = validatedByName;
            point.valideAt = DateTime.now();
          }
        }
        if (photo != null) point.photoPath = photo;
        break;
      }
      notifyListeners();
      await _repository.cacheChantierLocally(chantier);
    }
    await _repository.updatePoint(reference, pointId, status: status, photo: photo, validatedByName: validatedByName);
  }

  Future<void> submitRex(String reference, {String? transcription, String? audio}) async {
    final updated = await _repository.submitRex(reference, transcription: transcription, audio: audio);
    _replaceInList(updated);
  }

  /// Optimistic UI : le REX disparaît immédiatement, avec restauration en cas
  /// d'échec réseau réel.
  Future<void> deleteRex(String reference) async {
    final chantier = findByReference(reference);
    final prevRexValide = chantier?.rexValide ?? false;
    final prevTranscription = chantier?.rexTranscription;
    if (chantier != null) {
      chantier.rexValide = false;
      chantier.rexTranscription = null;
      notifyListeners();
      await _repository.cacheChantierLocally(chantier);
    }
    try {
      final updated = await _repository.deleteRex(reference);
      _replaceInList(updated);
    } catch (e) {
      if (chantier != null) {
        chantier.rexValide = prevRexValide;
        chantier.rexTranscription = prevTranscription;
        notifyListeners();
        await _repository.cacheChantierLocally(chantier);
      }
      rethrow;
    }
  }

  /// Dépôt (ou remplacement) du gabarit PV par le back-office — ne valide
  /// rien (voir [signPv]).
  Future<void> uploadPvDocument(String reference, String file) async {
    final updated = await _repository.uploadPvDocument(reference, file);
    _replaceInList(updated);
  }

  /// Signature du PV par le client, soumise par l'installateur — [signatureImage]
  /// est l'image PNG du tracé seul ; la fusion avec le PDF gabarit se fait
  /// côté serveur (voir signature_screen.dart).
  Future<void> signPv(
    String reference, {
    required String nomSignataire,
    required String fonctionSignataire,
    required String signatureImage,
  }) async {
    final updated = await _repository.signPv(
      reference,
      nomSignataire: nomSignataire,
      fonctionSignataire: fonctionSignataire,
      signatureImage: signatureImage,
    );
    _replaceInList(updated);
  }

  /// Optimistic UI : le PV (gabarit et signature) disparaît immédiatement,
  /// avec restauration en cas d'échec réseau réel.
  Future<void> deletePv(String reference) async {
    final chantier = findByReference(reference);
    final prevPvPdfPath = chantier?.pvPdfPath;
    final prevPvSigne = chantier?.pvSigne ?? false;
    final prevPvSigneur = chantier?.pvSigneur;
    final prevPvFonctionSignataire = chantier?.pvFonctionSignataire;
    final prevPvSigneAt = chantier?.pvSigneAt;
    final prevPvSignatureImagePath = chantier?.pvSignatureImagePath;
    if (chantier != null) {
      chantier.pvPdfPath = null;
      chantier.pvSigne = false;
      chantier.pvSigneur = null;
      chantier.pvFonctionSignataire = null;
      chantier.pvSigneAt = null;
      chantier.pvSignatureImagePath = null;
      notifyListeners();
      await _repository.cacheChantierLocally(chantier);
    }
    try {
      final updated = await _repository.deletePv(reference);
      _replaceInList(updated);
    } catch (e) {
      if (chantier != null) {
        chantier.pvPdfPath = prevPvPdfPath;
        chantier.pvSigne = prevPvSigne;
        chantier.pvSigneur = prevPvSigneur;
        chantier.pvFonctionSignataire = prevPvFonctionSignataire;
        chantier.pvSigneAt = prevPvSigneAt;
        chantier.pvSignatureImagePath = prevPvSignatureImagePath;
        notifyListeners();
        await _repository.cacheChantierLocally(chantier);
      }
      rethrow;
    }
  }

  /// Optimistic UI : un document "en file" (même style que le dépôt hors-ligne
  /// existant, voir ChantierRepository) apparaît immédiatement dans la liste
  /// pendant l'envoi réel, plutôt que de laisser l'écran figé le temps des
  /// deux appels réseau (dépôt puis refetch).
  Future<void> addDocument(String reference, {required String titre, required String categorie, required String file, String? auteurName}) async {
    final chantier = findByReference(reference);
    if (chantier != null) {
      chantier.docsTerrain.add(DocumentTerrain(
        titre: titre,
        categorie: CategorieDocument.values.firstWhere((c) => c.name == categorie),
        horodatage: DateTime.now(),
        auteur: auteurName ?? '',
        envoye: false,
      ));
      notifyListeners();
      await _repository.cacheChantierLocally(chantier);
    }
    await _repository.addDocument(reference, titre: titre, categorie: categorie, file: file, auteurName: auteurName);
    final updated = await _repository.getChantier(reference);
    _replaceInList(updated);
  }

  /// Optimistic UI : suppression immédiate de la liste, avec réaffichage en
  /// cas d'échec réseau réel (pas de file d'attente hors-ligne ici, comme
  /// pour deleteDocumentChantier).
  Future<void> deleteDocument(String reference, String docId) async {
    final chantier = findByReference(reference);
    DocumentTerrain? removed;
    if (chantier != null) {
      for (final d in chantier.docsTerrain) {
        if (d.id == docId) {
          removed = d;
          break;
        }
      }
      if (removed != null) chantier.docsTerrain.remove(removed);
      notifyListeners();
      await _repository.cacheChantierLocally(chantier);
    }
    try {
      final updated = await _repository.deleteDocument(reference, docId);
      _replaceInList(updated);
    } catch (e) {
      if (chantier != null && removed != null) {
        chantier.docsTerrain.add(removed);
        notifyListeners();
        await _repository.cacheChantierLocally(chantier);
      }
      rethrow;
    }
  }

  /// Réagit à un événement temps réel "chantier-changed" (voir RealtimeService)
  /// : refetch ce seul chantier — couvre aussi bien une mise à jour d'un
  /// chantier déjà connu qu'une création par un autre utilisateur (absent de
  /// la liste locale, alors ajouté par [_replaceInList]).
  Future<void> handleRealtimeChange(String reference) async {
    try {
      final updated = await _repository.getChantier(reference);
      _replaceInList(updated);
    } catch (_) {
      // Chantier supprimé entre-temps ou réseau indisponible — ignoré, la
      // suppression est de toute façon signalée par son propre événement.
    }
  }

  void handleRealtimeDelete(String reference) {
    _chantiers = _chantiers.where((c) => c.reference != reference).toList();
    if (_currentChantier?.reference == reference) _currentChantier = null;
    notifyListeners();
  }

  void _replaceInList(Chantier updated) {
    final index = _chantiers.indexWhere((c) => c.reference == updated.reference);
    if (index != -1) {
      _chantiers = [..._chantiers];
      _chantiers[index] = updated;
    } else {
      _chantiers = [..._chantiers, updated];
    }
    if (_currentChantier?.reference == updated.reference) {
      _currentChantier = updated;
    }
    notifyListeners();
  }
}
