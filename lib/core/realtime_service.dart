import 'dart:convert';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../data/api_client.dart';
import 'realtime_config.dart';

/// Diffusion temps réel (Pusher Channels), sur deux canaux PRIVÉS (voir
/// backend/src/lib/pusher.ts et routes/pusherAuth.ts pour l'autorisation
/// côté serveur, seule source de vérité du contrôle d'accès) :
/// - `private-app-events` (chantier-changed/chantier-deleted) : ouvert à
///   tout utilisateur authentifié, y compris installateur (doit être notifié
///   des changements sur SES chantiers).
/// - `private-notifications` (notification-created) : réservé CA/Admin, pour
///   rester cohérent avec la restriction déjà en place sur GET /notifications
///   — un installateur qui tenterait quand même de s'y abonner se ferait
///   simplement refuser (403) par /pusher/auth.
class RealtimeService {
  static const String _chantierChangesChannel = 'private-app-events';
  static const String _notificationsChannel = 'private-notifications';

  final ApiClient _apiClient;
  RealtimeService(this._apiClient);

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  bool _initialized = false;
  bool _notificationsSubscribed = false;

  void Function(String reference)? onChantierChanged;
  void Function(String reference)? onChantierDeleted;
  void Function(Map<String, dynamic> notification)? onNotificationCreated;

  /// Initialise la connexion une seule fois (au premier appel) puis
  /// ajoute l'abonnement `private-notifications` selon [isCaOuAdmin] — à
  /// rappeler à chaque fois que le rôle de l'utilisateur connecté est
  /// susceptible d'avoir changé (connexion, restauration de session
  /// asynchrone au démarrage), pas seulement une fois au lancement de l'app :
  /// [AuthState.currentUser] n'est pas encore connu au tout premier appel
  /// (auto-login asynchrone), d'où le ré-appel depuis un listener côté
  /// [VerticalApp] plutôt qu'un unique appel dans initState.
  Future<void> connect({required bool isCaOuAdmin}) async {
    if (!RealtimeConfig.isConfigured) return;

    if (!_initialized) {
      try {
        await _pusher.init(
          apiKey: RealtimeConfig.pusherKey,
          cluster: RealtimeConfig.pusherCluster,
          onEvent: _handleEvent,
          onAuthorizer: _authorizer,
        );
        await _pusher.subscribe(channelName: _chantierChangesChannel);
        await _pusher.connect();
        _initialized = true;
      } catch (_) {
        // Le temps réel est une amélioration ; un échec de connexion (compte
        // Pusher pas encore prêt, réseau...) ne doit jamais bloquer l'app.
        return;
      }
    }

    if (isCaOuAdmin && !_notificationsSubscribed) {
      try {
        await _pusher.subscribe(channelName: _notificationsChannel);
        _notificationsSubscribed = true;
      } catch (_) {
        // Idem : un canal en moins ne doit jamais bloquer l'app.
      }
    }
  }

  /// Appelé par le client Pusher (natif et Web, voir le plugin) à chaque
  /// tentative de souscription à un canal privé — délègue au backend
  /// (POST /pusher/auth, avec le JWT courant via [ApiClient]) qui seul
  /// détient le secret Pusher nécessaire pour signer. Toute erreur (403 rôle
  /// non autorisé, 401 session expirée...) remonte telle quelle : le plugin
  /// la transforme en échec de souscription pour ce canal, sans planter l'app.
  Future<Map<String, dynamic>> _authorizer(String channelName, String socketId, dynamic options) async {
    final data = await _apiClient.pusherAuth(socketId: socketId, channelName: channelName);
    return {'auth': data['auth'] as String};
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
