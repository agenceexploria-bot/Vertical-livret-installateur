import 'package:flutter/material.dart';
import '../data/models/chantier.dart';
import '../data/models/document_chantier.dart';
import '../data/models/document_terrain.dart';
import '../data/models/point_controle.dart';
import '../data/models/pv_reponses.dart';
import '../data/models/user.dart';
import '../data/repositories/chantier_repository.dart';

/// "Terminé" est dérivé de [Chantier.pvSigne] — jamais un statut saisi à la
/// main : le PV signé (réception faite, chantier bouclé) est la seule
/// source de vérité, donc un chantier reclasse automatiquement s'il se
/// désigne (voir [ChantierState.deletePv], qui remet pvSigne à `false`).
/// Pure — testable sans ChantierState ni ses dépendances (repository,
/// réseau...), voir aussi [chantiersTermines].
List<Chantier> chantiersEnCours(List<Chantier> chantiers) => chantiers.where((c) => !c.pvSigne).toList();

/// Triés par date de signature décroissante (la plus récente en premier) —
/// contrairement à [chantiersEnCours], qui conserve l'ordre existant de la
/// liste (comportement actuel, non modifié par cette fonctionnalité).
List<Chantier> chantiersTermines(List<Chantier> chantiers) {
  final termines = chantiers.where((c) => c.pvSigne).toList();
  termines.sort((a, b) => (b.pvSigneAt ?? DateTime(0)).compareTo(a.pvSigneAt ?? DateTime(0)));
  return termines;
}

/// Module SAV — sépare les chantiers d'installation des interventions SAV
/// (voir [Chantier.type]) : les deux tuiles de l'accueil installateur en
/// dérivent chacune une liste. Pure, comme [chantiersEnCours]/[chantiersTermines].
List<Chantier> chantiersInstallation(List<Chantier> chantiers) => chantiers.where((c) => c.type == ChantierType.installation).toList();
List<Chantier> chantiersSav(List<Chantier> chantiers) => chantiers.where((c) => c.type == ChantierType.sav).toList();

class ChantierState extends ChangeNotifier {
  final ChantierRepository _repository;
  List<Chantier> _chantiers = [];
  Chantier? _currentChantier;
  bool _isLoading = false;

  ChantierState(this._repository);

  List<Chantier> get chantiers => _chantiers;
  Chantier? get currentChantier => _currentChantier;
  bool get isLoading => _isLoading;

  /// Vues dérivées de [chantiers] — voir [chantiersEnCours]/[chantiersTermines]
  /// (fonctions pures, plus haut) pour la logique de filtrage/tri elle-même.
  List<Chantier> get chantiersEnCoursList => chantiersEnCours(_chantiers);
  List<Chantier> get chantiersTerminesList => chantiersTermines(_chantiers);

  /// Module SAV — les deux tuiles de l'accueil installateur mènent chacune à
  /// l'une de ces deux vues, dérivées du même [chantiers] déjà chargé (pas
  /// d'appel réseau séparé). Voir [chantiersInstallation]/[chantiersSav].
  List<Chantier> get chantiersInstallationList => chantiersInstallation(_chantiers);
  List<Chantier> get chantiersSavList => chantiersSav(_chantiers);

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
      // Rejet serveur ou bug client possible depuis que markLivretOuvert ne
      // met plus en file d'attente hors-ligne que les vraies coupures réseau
      // (voir ChantierRepository.markLivretOuvert) — un simple "vu" raté ne
      // doit jamais empêcher le chargement de la liste des chantiers.
      await Future.wait(_chantiers.map((c) => _repository.markLivretOuvert(c.reference).catchError((e) {
            debugPrint('ChantierState.fetchChantiers: markLivretOuvert a échoué pour ${c.reference} — $e');
          })));
    }
    notifyListeners();
  }

  void selectChantier(Chantier chantier) {
    _currentChantier = chantier;
    notifyListeners();
  }

  /// Résout un chantier à partir de sa seule référence — utilisé par un lien
  /// direct (route /chantier/:ref, voir router.dart) : contrairement à la
  /// navigation normale depuis la liste (déjà chargée, [selectChantier]
  /// suffit), un lien WhatsApp/SMS peut arriver avant même que
  /// [fetchChantiers] n'ait tourné (accueil jamais construit, la route est
  /// atteinte directement) — va chercher le chantier au besoin. Laisse
  /// l'exception (404 introuvable, 403 pas rattaché — voir
  /// requireRattachement côté backend) remonter à l'appelant, qui affiche un
  /// message clair plutôt qu'un écran vide.
  Future<void> loadChantierByReference(String reference) async {
    final chantier = await _repository.getChantier(reference);
    _replaceInList(chantier);
    selectChantier(chantier);
  }

  Chantier? findByReference(String reference) {
    for (final c in _chantiers) {
      if (c.reference == reference) return c;
    }
    return null;
  }

  Future<Chantier> createChantier(Map<String, dynamic> body) async {
    final created = await _repository.createChantier(body);
    _chantiers = [..._chantiers, created];
    notifyListeners();
    return created;
  }

  /// Module SAV — création d'une intervention SAV depuis la fiche du
  /// chantier d'origine (back-office). Renvoie le chantier SAV créé pour que
  /// l'écran appelant puisse y naviguer directement.
  Future<Chantier> createSav(
    String reference, {
    required String descriptionProbleme,
    required String installateurId,
    DateTime? savDate,
  }) async {
    final sav = await _repository.createSav(
      reference,
      descriptionProbleme: descriptionProbleme,
      installateurId: installateurId,
      savDate: savDate,
    );
    _chantiers = [..._chantiers, sav];
    notifyListeners();
    return sav;
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
      {required String type, String? nom, String? nomFichierOriginal, required String file}) async {
    final updated = await _repository.addDocumentChantier(reference,
        type: type, nom: nom, nomFichierOriginal: nomFichierOriginal, file: file);
    _replaceInList(updated);
  }

  /// Optimistic UI : le document disparaît immédiatement de la liste. En cas
  /// d'échec réseau (pas de file d'attente hors-ligne pour cette action CT),
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

  /// Renvoie `true` si l'envoi a été mis en file d'attente hors-ligne
  /// (vraie coupure réseau) plutôt que réellement parti au serveur — voir
  /// [SubmitRexResult] et rex_screen.dart, qui en tire un message différent
  /// selon le cas plutôt qu'un succès générique dans les deux cas.
  Future<bool> submitRex(String reference, {String? transcription, String? audio}) async {
    final result = await _repository.submitRex(reference, transcription: transcription, audio: audio);
    _replaceInList(result.chantier);
    return result.wasQueued;
  }

  /// Optimistic UI : l'entrée REX disparaît immédiatement, avec restauration
  /// en cas d'échec réseau réel. Les autres entrées REX du chantier ne sont
  /// pas affectées.
  Future<void> deleteRex(String reference, String rexId) async {
    final chantier = findByReference(reference);
    final removedIndex = chantier?.rex.indexWhere((r) => r.id == rexId) ?? -1;
    Rex? removed;
    if (chantier != null && removedIndex != -1) {
      removed = chantier.rex.removeAt(removedIndex);
      notifyListeners();
      await _repository.cacheChantierLocally(chantier);
    }
    try {
      final updated = await _repository.deleteRex(reference, rexId);
      _replaceInList(updated);
    } catch (e) {
      if (chantier != null && removed != null) {
        chantier.rex.insert(removedIndex, removed);
        notifyListeners();
        await _repository.cacheChantierLocally(chantier);
      }
      rethrow;
    }
  }

  /// Relance la transcription automatique d'un REX audio sans transcription.
  /// Pas de mise à jour optimiste (le texte n'est connu qu'au retour du
  /// serveur) — la carte REX affiche son propre indicateur de chargement le
  /// temps de l'appel (voir RexCard).
  Future<void> transcribeRex(String reference, String rexId) async {
    final updated = await _repository.transcribeRex(reference, rexId);
    _replaceInList(updated);
  }

  /// Dépôt (ou remplacement) du gabarit PV par le back-office — ne valide
  /// rien (voir [signPv]).
  Future<void> uploadPvDocument(String reference, String file) async {
    final updated = await _repository.uploadPvDocument(reference, file);
    _replaceInList(updated);
  }

  /// Signature du PV par le client, soumise par l'installateur — [signatureImage]
  /// est l'image PNG du tracé seul et [pageNumber]/[x]/[y]/[width]/[height]
  /// sa position sur le document ; la fusion avec le PDF gabarit se fait
  /// côté serveur (voir signature_screen.dart).
  Future<void> signPv(
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
    final updated = await _repository.signPv(
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
    _replaceInList(updated);
  }

  /// Validation du formulaire PV interactif (voir pv_formulaire_screen.dart) —
  /// le backend génère le PDF final à partir de [reponses] et de la signature.
  Future<void> submitPvFormulaire(
    String reference, {
    required PvFormReponses reponses,
    required DateTime dateReception,
    required String nomSignataire,
    required String fonctionSignataire,
    required String signatureImage,
  }) async {
    final updated = await _repository.submitPvFormulaire(
      reference,
      reponses: reponses,
      dateReception: dateReception,
      nomSignataire: nomSignataire,
      fonctionSignataire: fonctionSignataire,
      signatureImage: signatureImage,
    );
    _replaceInList(updated);
  }

  /// Module SAV — validation du PV SAV, voir [ChantierRepository.submitSavPvFormulaire].
  Future<void> submitSavPvFormulaire(
    String reference, {
    required String descriptionIntervention,
    String? piecesRemplacees,
    required List<String> photos,
    required String nomSignataire,
    required String fonctionSignataire,
    required String signatureImage,
  }) async {
    final updated = await _repository.submitSavPvFormulaire(
      reference,
      descriptionIntervention: descriptionIntervention,
      piecesRemplacees: piecesRemplacees,
      photos: photos,
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
