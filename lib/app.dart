import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/realtime_service.dart';
import 'data/api_client.dart';
import 'data/local/app_database.dart';
import 'data/models/user.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/chantier_repository.dart';
import 'data/sync/sync_engine.dart';
import 'state/auth_state.dart';
import 'state/network_state.dart';
import 'state/chantier_state.dart';
import 'state/comptes_state.dart';
import 'state/admin_state.dart';
import 'state/notifications_state.dart';

class VerticalApp extends StatelessWidget {
  const VerticalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => ApiClient()),
        Provider(create: (_) => AppDatabase()),
        Provider(create: (_) => Connectivity()),
        ProxyProvider2<ApiClient, AppDatabase, AuthRepository>(
          update: (_, api, db, _) => AuthRepository(api, db),
        ),
        ProxyProvider2<ApiClient, AppDatabase, ChantierRepository>(
          update: (_, api, db, _) => ChantierRepository(api, db),
        ),
        ProxyProvider2<AppDatabase, ApiClient, SyncEngine>(
          update: (_, db, api, _) => SyncEngine(db, api),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthState(context.read<AuthRepository>()),
        ),
        ChangeNotifierProxyProvider3<Connectivity, AppDatabase, SyncEngine, NetworkState>(
          create: (context) => NetworkState(
            context.read<Connectivity>(),
            context.read<AppDatabase>(),
            context.read<SyncEngine>(),
          ),
          update: (_, connectivity, db, syncEngine, state) => state!,
        ),
        ChangeNotifierProxyProvider<ChantierRepository, ChantierState>(
          create: (context) => ChantierState(context.read<ChantierRepository>()),
          update: (_, repo, state) => state!,
        ),
        ChangeNotifierProvider(
          create: (context) => ComptesState(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider(
          create: (context) => AdminState(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider(
          create: (context) => NotificationsState(context.read<ApiClient>()),
        ),
      ],
      child: const _RouterHost(),
    );
  }
}

/// Construit le GoRouter une seule fois (avec AuthState comme
/// refreshListenable) plutôt qu'à chaque build — recréer le routeur à chaque
/// changement d'état perdrait la pile de navigation.
class _RouterHost extends StatefulWidget {
  const _RouterHost();

  @override
  State<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends State<_RouterHost> {
  late final GoRouter _router = AppRouter.build(context.read<AuthState>());
  late final RealtimeService _realtime = RealtimeService(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    _realtime.onChantierChanged = (reference) => context.read<ChantierState>().handleRealtimeChange(reference);
    _realtime.onChantierDeleted = (reference) => context.read<ChantierState>().handleRealtimeDelete(reference);
    _realtime.onNotificationCreated = (json) => context.read<NotificationsState>().handleRealtimeNotification(json);
    // Le canal notifications est réservé CA/Admin (voir RealtimeService) —
    // le rôle courant n'est pas forcément connu dès ce premier appel
    // (restauration de session asynchrone au démarrage, voir AuthState._init),
    // d'où ce ré-appel à chaque changement plutôt qu'une lecture unique ici.
    context.read<AuthState>().addListener(_syncRealtime);
    _syncRealtime();
  }

  void _syncRealtime() {
    final role = context.read<AuthState>().currentUser?.role;
    _realtime.connect(isCaOuAdmin: role == UserRole.chargeAffaires || role == UserRole.admin);
  }

  @override
  void dispose() {
    context.read<AuthState>().removeListener(_syncRealtime);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vertical App',
      theme: AppTheme.lightTheme,
      scrollBehavior: AppScrollBehavior(),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      // Beaucoup de textes du back-office (tableaux denses) utilisent des
      // tailles fixes assez petites (9.5-11.5px) — un boost global du texte
      // (au lieu de retoucher chaque style un par un) les rend plus lisibles
      // partout d'un coup. Multiplie l'échelle système plutôt que de la
      // remplacer, pour respecter les réglages d'accessibilité de l'appareil.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final boosted = TextScaler.linear(mediaQuery.textScaler.scale(1.0) * 1.12);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: boosted),
          child: child!,
        );
      },
    );
  }
}
