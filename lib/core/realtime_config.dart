/// Clé et cluster Pusher (Channels) — valeurs PUBLIQUES (jamais l'App ID ni
/// le secret, qui restent côté serveur dans backend/.env). À remplir une fois
/// l'app créée sur https://dashboard.pusher.com, avec les MÊMES valeurs que
/// PUSHER_KEY / PUSHER_CLUSTER dans backend/.env — voir lib/core/realtime_service.dart.
class RealtimeConfig {
  static const String pusherKey = 'REPLACE_WITH_PUSHER_KEY';
  static const String pusherCluster = 'eu';

  static bool get isConfigured => pusherKey != 'REPLACE_WITH_PUSHER_KEY' && pusherKey.isNotEmpty;
}
