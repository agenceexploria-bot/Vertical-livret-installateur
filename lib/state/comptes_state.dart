import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../data/models/user.dart';

class ComptesState extends ChangeNotifier {
  final ApiClient _api;
  List<User> _installateurs = [];
  bool _isLoading = false;

  ComptesState(this._api);

  List<User> get installateurs => _installateurs;
  bool get isLoading => _isLoading;

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.getComptes();
      _installateurs = data.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
    } catch (_) {
      // Droits insuffisants ou serveur injoignable : la liste reste telle
      // quelle plutôt que de planter l'appel non attendu depuis BoShell.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> valider(User user) async {
    final data = await _api.validerCompte(user.id);
    _replace(User.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> suspendre(User user) async {
    final data = await _api.suspendreCompte(user.id);
    _replace(User.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> reactiver(User user) async {
    final data = await _api.reactiverCompte(user.id);
    _replace(User.fromJson(data['user'] as Map<String, dynamic>));
  }

  /// Suppression définitive (Admin uniquement — voir la refonte des rôles).
  /// Optimistic UI : le compte disparaît immédiatement de la liste, avec
  /// réaffichage en cas d'échec réseau réel.
  Future<void> supprimer(User user) async {
    final previous = _installateurs;
    _installateurs = _installateurs.where((u) => u.id != user.id).toList();
    notifyListeners();
    try {
      await _api.supprimerCompte(user.id);
    } catch (e) {
      _installateurs = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reinitialiserMotDePasse(User user, String password) => _api.reinitialiserMotDePasse(user.id, password);

  Future<void> modifierProfil(User user, {String? nom, String? prenom, String? email, String? mobile, String? societe}) async {
    final data = await _api.updateCompte(user.id, nom: nom, prenom: prenom, email: email, mobile: mobile, societe: societe);
    _replace(User.fromJson(data['user'] as Map<String, dynamic>));
  }

  void _replace(User updated) {
    final index = _installateurs.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      _installateurs = [..._installateurs];
      _installateurs[index] = updated;
    } else {
      _installateurs = [..._installateurs, updated];
    }
    notifyListeners();
  }
}
