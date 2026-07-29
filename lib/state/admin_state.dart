import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../data/models/activity_feed.dart';
import '../data/models/user.dart';

class AdminState extends ChangeNotifier {
  final ApiClient _api;
  List<User> _comptesInternes = [];
  List<User> _tousLesComptes = [];
  ActivityFeed? _activityFeed;
  List<WeeklyStat> _weeklyStats = [];
  bool _isLoading = false;

  AdminState(this._api);

  List<User> get comptesInternes => _comptesInternes;

  /// Gestion globale des comptes (section "Gestion des comptes" du dashboard
  /// Admin) — tous les rôles sauf Admin, distinct de [comptesInternes] qui ne
  /// liste que les comptes CA/Qualité en attente de validation.
  List<User> get tousLesComptes => _tousLesComptes;
  ActivityFeed? get activityFeed => _activityFeed;
  List<WeeklyStat> get weeklyStats => _weeklyStats;
  bool get isLoading => _isLoading;

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      final comptes = await _api.getComptesInternes();
      _comptesInternes = comptes.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
      final tousLesComptes = await _api.getTousLesComptes();
      _tousLesComptes = tousLesComptes.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
      final feed = await _api.getActivityFeed();
      _activityFeed = ActivityFeed.fromJson(feed);
      final stats = await _api.getAdminStats();
      _weeklyStats = stats.map((w) => WeeklyStat.fromJson(w as Map<String, dynamic>)).toList();
    } catch (_) {
      // Droits insuffisants ou serveur injoignable : le tableau de bord reste
      // tel quel plutôt que de planter l'appel non attendu depuis l'écran.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> validerCompteInterne(User user) async {
    final data = await _api.validerCompteInterne(user.id);
    final updated = User.fromJson(data['user'] as Map<String, dynamic>);
    final index = _comptesInternes.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      _comptesInternes = [..._comptesInternes];
      _comptesInternes[index] = updated;
    }
    await fetch();
  }

  Future<void> suspendreCompte(User user) async {
    final data = await _api.suspendreCompteAdmin(user.id);
    _replaceCompte(User.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> reactiverCompte(User user) async {
    final data = await _api.reactiverCompteAdmin(user.id);
    _replaceCompte(User.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<void> reinitialiserMotDePasse(User user, String password) =>
      _api.reinitialiserMotDePasseAdmin(user.id, password);

  Future<void> supprimerCompte(User user) async {
    await _api.supprimerCompteAdmin(user.id);
    _tousLesComptes = _tousLesComptes.where((u) => u.id != user.id).toList();
    notifyListeners();
  }

  void _replaceCompte(User updated) {
    final index = _tousLesComptes.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      _tousLesComptes = [..._tousLesComptes];
      _tousLesComptes[index] = updated;
    }
    notifyListeners();
  }
}
