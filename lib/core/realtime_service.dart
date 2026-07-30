import 'dart:convert';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'realtime_config.dart';

/// Diffusion temps réel (Pusher Channels) : un seul channel public partagé
/// par toute l'app — le backend y publie un événement à chaque mutation
/// (voir backend/src/lib/pusher.ts), et ce service relaie l'événement aux
/// callbacks branchés par l'app (ChantierState/NotificationsState), qui
/// réagissent en rafraîchissant les données concernées.
class RealtimeService {
  static const String _channel = 'app-events';

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  bool _connected = false;

  void Function(String reference)? onChantierChanged;
  void Function(String reference)? onChantierDeleted;
  void Function(Map<String, dynamic> notification)? onNotificationCreated;

  Future<void> connect() async {
    if (_connected || !RealtimeConfig.isConfigured) return;
    try {
      await _pusher.init(
        apiKey: RealtimeConfig.pusherKey,
        cluster: RealtimeConfig.pusherCluster,
        onEvent: _handleEvent,
      );
      await _pusher.subscribe(channelName: _channel);
      await _pusher.connect();
      _connected = true;
    } catch (_) {
      // Le temps réel est une amélioration ; un échec de connexion (compte
      // Pusher pas encore prêt, réseau...) ne doit jamais bloquer l'app.
    }
  }

  void _handleEvent(PusherEvent event) {
    final raw = event.data;
    final Map<String, dynamic> payload;
    if (raw is String) {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } else if (raw is Map) {
      payload = Map<String, dynamic>.from(raw);
    } else {
      return;
    }

    switch (event.eventName) {
      case 'chantier-changed':
        final reference = payload['reference'] as String?;
        if (reference != null) onChantierChanged?.call(reference);
        break;
      case 'chantier-deleted':
        final reference = payload['reference'] as String?;
        if (reference != null) onChantierDeleted?.call(reference);
        break;
      case 'notification-created':
        final notification = payload['notification'] as Map<String, dynamic>?;
        if (notification != null) onNotificationCreated?.call(notification);
        break;
    }
  }
}
