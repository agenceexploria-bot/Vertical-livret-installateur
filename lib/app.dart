import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'data/api_client.dart';
import 'data/local/app_database.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/chantier_repository.dart';
import 'data/sync/sync_engine.dart';
import 'state/auth_state.dart';
import 'state/network_state.dart';
import 'state/chantier_state.dart';
import 'state/comptes_state.dart';
import 'state/admin_state.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vertical App',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
