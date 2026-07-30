import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../data/models/notification_item.dart';

class NotificationsState extends ChangeNotifier {
  final ApiClient _api;
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;

  NotificationsState(this._api);

  List<NotificationItem> get notifications => _notifications;
  int get nonLuesCount => _notifications.where((n) => !n.lue).length;
  bool get isLoading => _isLoading;

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.getNotifications();
      _notifications = data.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>)).toList();
    } catch (_) {
      // Droits insuffisants (installateur) ou serveur injoignable : la liste
      // reste telle quelle plutôt que de planter l'appel non attendu depuis BoShell.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Réagit à un événement temps réel "notification-created" (voir
  /// RealtimeService) — insère directement le payload reçu, sans refetch.
  void handleRealtimeNotification(Map<String, dynamic> json) {
    final notification = NotificationItem.fromJson(json);
    if (_notifications.any((n) => n.id == notification.id)) return;
    _notifications = [notification, ..._notifications];
    notifyListeners();
  }

  Future<void> marquerLue(String id) async {
    await _api.marquerNotificationLue(id);
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final n = _notifications[index];
    _notifications = [..._notifications];
    _notifications[index] = NotificationItem(
      id: n.id,
      type: n.type,
      message: n.message,
      lue: true,
      createdAt: n.createdAt,
      chantierReference: n.chantierReference,
    );
    notifyListeners();
  }
}
