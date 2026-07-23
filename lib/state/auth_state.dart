import 'dart:async';
import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';

class AuthState extends ChangeNotifier {
  final AuthRepository _repository;
  User? _currentUser;
  DateTime? _offlineExpiry;
  bool _isLoading = true;
  String? _lastError;

  AuthState(this._repository) {
    _init();
  }

  User? get currentUser => _currentUser;
  DateTime? get offlineExpiry => _offlineExpiry;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get lastError => _lastError;

  Future<void> _init() async {
    _currentUser = await _repository.tryAutoLogin();
    if (_currentUser != null) _offlineExpiry = await _repository.getSessionExpiry();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      _currentUser = await _repository.login(identifier, password);
      _offlineExpiry = await _repository.getSessionExpiry();
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      return false;
    } catch (e, st) {
      debugPrint('AuthState.login: $e\n$st');
      _lastError = 'Impossible de contacter le serveur';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signup({
    required String nom,
    required String prenom,
    required String mobile,
    required String password,
    required String email,
    bool sousTraitant = false,
    String? societe,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      _currentUser = await _repository.signup(
        nom: nom,
        prenom: prenom,
        mobile: mobile,
        password: password,
        email: email,
        sousTraitant: sousTraitant,
        societe: societe,
      );
      _offlineExpiry = await _repository.getSessionExpiry();
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      return false;
    } catch (e, st) {
      debugPrint('AuthState.signup: $e\n$st');
      _lastError = 'Impossible de contacter le serveur';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signupInterne({
    required String nom,
    required String prenom,
    required String mobile,
    required String password,
    required String email,
    required String role,
  }) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      _currentUser = await _repository.signupInterne(
        nom: nom,
        prenom: prenom,
        mobile: mobile,
        password: password,
        email: email,
        role: role,
      );
      _offlineExpiry = await _repository.getSessionExpiry();
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      return false;
    } catch (e, st) {
      debugPrint('AuthState.signupInterne: $e\n$st');
      _lastError = 'Impossible de contacter le serveur';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ajoute un certificat au profil connecté. Optimiste : la liste locale est
  /// mise à jour immédiatement (fonctionne hors-ligne), un rafraîchissement
  /// réseau est tenté en tâche de fond pour rester en phase avec le serveur.
  Future<void> addHabilitation({required String titre, required DateTime dateExpiration, required String file}) async {
    await _repository.addHabilitation(titre: titre, dateExpiration: dateExpiration, file: file);
    if (_currentUser != null) {
      _currentUser!.habilitations.add(Habilitation(titre: titre, dateExpiration: dateExpiration));
      notifyListeners();
    }
    unawaited(refreshCurrentUser());
  }

  /// Recharge le profil depuis le serveur — utilisé sur l'écran d'attente pour
  /// détecter qu'un chargé d'affaires a validé le compte (EX-02).
  Future<void> refreshCurrentUser() async {
    final user = await _repository.refreshCurrentUser();
    if (user != null) {
      _currentUser = user;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    _offlineExpiry = null;
    notifyListeners();
  }
}
