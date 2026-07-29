import 'package:flutter/material.dart';
import '../data/models/chantier.dart';
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

  Future<void> fetchChantiers(User user) async {
    _isLoading = true;
    notifyListeners();
    _chantiers = await _repository.getMyChantiers(user);
    // Vérification de la veille (EX-22) : ouvrir la liste de ses chantiers
    // marque le livret comme consulté pour cet installateur.
    if (user.role == UserRole.installateur) {
      for (final c in _chantiers) {
        c.livretsOuverts.add(user.id);
      }
      await Future.wait(_chantiers.map((c) => _repository.markLivretOuvert(c.reference)));
    }
    _isLoading = false;
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

  Future<void> detacher(String reference, String userId) async {
    final updated = await _repository.detacher(reference, userId);
    _replaceInList(updated);
  }

  /// Modification et suppression d'un chantier (Admin uniquement — voir la
  /// refonte des rôles back-office).
  Future<void> updateChantier(String reference, Map<String, dynamic> body) async {
    final updated = await _repository.updateChantier(reference, body);
    _replaceInList(updated);
  }

  Future<void> deleteChantier(String reference) async {
    await _repository.deleteChantier(reference);
    _chantiers = _chantiers.where((c) => c.reference != reference).toList();
    if (_currentChantier?.reference == reference) _currentChantier = null;
    notifyListeners();
  }

  Future<void> addDocumentChantier(String reference,
      {required String type, required String nom, String? nomFichierOriginal, required String file}) async {
    final updated = await _repository.addDocumentChantier(reference,
        type: type, nom: nom, nomFichierOriginal: nomFichierOriginal, file: file);
    _replaceInList(updated);
  }

  Future<void> deleteDocumentChantier(String reference, String docId) async {
    final updated = await _repository.deleteDocumentChantier(reference, docId);
    _replaceInList(updated);
  }

  Future<void> replaceDocumentChantier(String reference, String docId,
      {required String file, String? nomFichierOriginal}) async {
    final updated = await _repository.replaceDocumentChantier(reference, docId, file: file, nomFichierOriginal: nomFichierOriginal);
    _replaceInList(updated);
  }

  Future<void> updatePoint(String reference, String pointId, {String? status, String? photo, String? validatedByName}) async {
    await _repository.updatePoint(reference, pointId, status: status, photo: photo, validatedByName: validatedByName);
    final updated = await _repository.getChantier(reference);
    _replaceInList(updated);
  }

  Future<void> submitRex(String reference, {String? transcription, String? audio}) async {
    final updated = await _repository.submitRex(reference, transcription: transcription, audio: audio);
    _replaceInList(updated);
  }

  Future<void> submitPv(String reference, String signataire, {String? signatureImage}) async {
    final updated = await _repository.submitPv(reference, signataire, signatureImage: signatureImage);
    _replaceInList(updated);
  }

  Future<void> addDocument(String reference, {required String titre, required String categorie, required String file, String? auteurName}) async {
    await _repository.addDocument(reference, titre: titre, categorie: categorie, file: file, auteurName: auteurName);
    final updated = await _repository.getChantier(reference);
    _replaceInList(updated);
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
