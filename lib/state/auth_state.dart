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
  String? _pendingVerificationTicket;

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

  /// Étape 1→2 de l'inscription (EX-2FA) : déclenche l'envoi du code par
  /// email. Une 409 (email déjà utilisé) remonte via [ApiException] pour que
  /// l'écran reste à l'étape 1 avec un message clair.
  Future<bool> requestEmailCode(String email) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await _repository.requestEmailCode(email);
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      return false;
    } catch (e, st) {
      debugPrint('AuthState.requestEmailCode: $e\n$st');
      _lastError = 'Impossible de contacter le serveur';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Étape 2→3 : vérifie le code saisi et conserve le ticket obtenu, transmis
  /// ensuite à [signup] pour prouver que l'email a bien été vérifié.
  Future<bool> verifyEmailCode(String email, String code) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      _pendingVerificationTicket = await _repository.verifyEmailCode(email, code);
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      return false;
    } catch (e, st) {
      debugPrint('AuthState.verifyEmailCode: $e\n$st');
      _lastError = 'Impossible de contacter le serveur';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Étape 1/2 du "mot de passe oublié" : déclenche l'envoi du code par email.
  /// Répond toujours succès côté serveur, même si l'email n'existe pas (voir
  /// authRouter) — seule une vraie erreur réseau/serveur fait échouer ici.
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await _repository.requestPasswordReset(email);
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      return false;
    } catch (e, st) {
      debugPrint('AuthState.requestPasswordReset: $e\n$st');
      _lastError = 'Impossible de contacter le serveur';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Étape 2/2 : vérifie le code reçu par email et remplace le mot de passe.
  Future<bool> resetPassword({required String email, required String code, required String password}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await _repository.resetPassword(email: email, code: code, password: password);
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      return false;
    } catch (e, st) {
      debugPrint('AuthState.resetPassword: $e\n$st');
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
    String? mobile,
    required String password,
    required String email,
    bool sousTraitant = false,
    String? societe,
  }) async {
    final ticket = _pendingVerificationTicket;
    if (ticket == null) {
      _lastError = 'Vérification email requise avant de terminer l\'inscription.';
      notifyListeners();
      return false;
    }

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
        verificationTicket: ticket,
        sousTraitant: sousTraitant,
        societe: societe,
      );
      _pendingVerificationTicket = null;
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

  /// Modifie les informations de profil (nom/prénom/email/mobile/société) —
  /// pas de changement de mot de passe ni de rôle ici, hors sujet.
  Future<bool> updateProfile({String? nom, String? prenom, String? email, String? mobile, String? societe}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      _currentUser = await _repository.updateProfile(nom: nom, prenom: prenom, email: email, mobile: mobile, societe: societe);
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
      return false;
    } catch (e, st) {
      debugPrint('AuthState.updateProfile: $e\n$st');
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
