import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../data/models/activity_feed.dart';
import '../data/models/user.dart';

class AdminState extends ChangeNotifier {
  final ApiClient _api;
  List<User> _comptesInternes = [];
  ActivityFeed? _activityFeed;
  bool _isLoading = false;

  AdminState(this._api);

  List<User> get comptesInternes => _comptesInternes;
  ActivityFeed? get activityFeed => _activityFeed;
  bool get isLoading => _isLoading;

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      final comptes = await _api.getComptesInternes();
      _comptesInternes = comptes.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
      final feed = await _api.getActivityFeed();
      _activityFeed = ActivityFeed.fromJson(feed);
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
}
