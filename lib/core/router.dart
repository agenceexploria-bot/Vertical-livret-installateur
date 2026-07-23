import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../data/models/user.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/pending_screen.dart';
import '../screens/installateur/home_screen.dart';
import '../screens/installateur/chantier_details_screen.dart';
import '../screens/installateur/profil_screen.dart';
import '../screens/installateur/modules/fiche_chantier_screen.dart';
import '../screens/installateur/modules/docs_admin_screen.dart';
import '../screens/installateur/modules/dossier_technique_screen.dart';
import '../screens/installateur/modules/reception_marchandises_screen.dart';
import '../screens/installateur/modules/auto_controle_screen.dart';
import '../screens/installateur/modules/rex_screen.dart';
import '../screens/installateur/modules/docs_terrain_screen.dart';
import '../screens/client/signature_screen.dart';
import '../screens/client/confirmation_screen.dart';
import '../screens/charge_affaires/ca_home_screen.dart';
import '../screens/charge_affaires/ca_validation_screen.dart';
import '../screens/backoffice/bo_login_screen.dart';
import '../screens/backoffice/bo_access_request_screen.dart';
import '../screens/backoffice/bo_ca_chantiers_screen.dart';
import '../screens/backoffice/bo_new_chantier_screen.dart';
import '../screens/backoffice/bo_chantier_detail_screen.dart';
import '../screens/backoffice/bo_comptes_screen.dart';
import '../screens/backoffice/bo_qualite_screen.dart';
import '../screens/backoffice/bo_admin_dashboard_screen.dart';

/// Espace back-office dédié à chaque rôle interne — utilisé par le garde de
/// redirection ci-dessous pour cloisonner strictement Admin / CA / Qualité.
/// `null` signifie "pas d'espace back-office" (ex. installateur).
String? _boHomeFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return '/backoffice/admin';
    case UserRole.chargeAffaires:
    case UserRole.direction:
      return '/backoffice/ca';
    case UserRole.qualite:
      return '/backoffice/qualite';
    case UserRole.installateur:
      return null;
  }
}

class AppRouter {
  /// Construit le routeur une seule fois, avec [authState] comme
  /// `refreshListenable` : sans ça, la redirection ne se ré-évalue jamais
  /// automatiquement quand la session se charge ou change (connexion,
  /// déconnexion, validation d'un compte) — l'écran affiché resterait figé.
  static GoRouter build(AuthState authState) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authState,
      redirect: (context, state) {
        if (state.matchedLocation.startsWith('/backoffice')) {
          // Admin Web : strictement inaccessible depuis une plateforme
          // mobile, même si l'app tourne en PWA — Flutter détecte l'OS hôte
          // via defaultTargetPlatform même sur le Web.
          final isMobilePlatform = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
          if (state.matchedLocation.startsWith('/backoffice/admin') && isMobilePlatform) {
            return '/backoffice/ca';
          }

          final isBoLogin = state.matchedLocation == '/backoffice/login';
          final isBoAcces = state.matchedLocation == '/backoffice/acces';
          if (isBoLogin || isBoAcces) return null;

          if (authState.isLoading) return null;
          if (!authState.isAuthenticated) return '/backoffice/login';

          // Cloisonnement strict des 3 espaces internes : un CA qui tape
          // /backoffice/admin (ou tout autre espace qui n'est pas le sien)
          // est renvoyé vers son propre espace, quelle que soit l'URL visée.
          final home = _boHomeFor(authState.currentUser!.role);
          if (home == null) return '/backoffice/login';
          if (!state.matchedLocation.startsWith(home)) return home;
          return null;
        }

        final isLoggingIn = state.matchedLocation == '/login';
        final isSigningUp = state.matchedLocation == '/signup';
        final isPending = state.matchedLocation == '/pending';

        // Tant que la session n'est pas encore résolue (vérification du jeton
        // au démarrage), on ne redirige nulle part — voir aussi le garde dans
        // le builder de '/' qui empêche d'afficher un écran avec un user nul.
        if (authState.isLoading) return null;

        if (!authState.isAuthenticated && !isLoggingIn && !isSigningUp) {
          return '/login';
        }

        if (authState.isAuthenticated) {
          // Redirection vers pending si compte non validé (EX-02)
          if (!authState.currentUser!.isActive && !isPending) {
            return '/pending';
          }

          // Redirection vers home si déjà connecté et on essaie d'aller sur login/signup/pending
          if (authState.currentUser!.isActive && (isLoggingIn || isSigningUp || isPending)) {
            return '/';
          }
        }

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
        GoRoute(path: '/pending', builder: (context, state) => const PendingScreen()),
        GoRoute(
          path: '/',
          builder: (context, state) {
            final authState = context.read<AuthState>();
            // Session pas encore résolue ou utilisateur non authentifié : ne
            // jamais construire un écran métier avec un user nul (c'était la
            // cause du "tableau de bord installateur" qui s'affichait avant
            // la page de connexion). Le redirect ci-dessus prendra le relais
            // dès que l'état sera connu.
            if (authState.isLoading || authState.currentUser == null) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (authState.currentUser!.role == UserRole.chargeAffaires) return const CaHomeScreen();
            return const InstallateurHomeScreen();
          },
        ),
        GoRoute(
          path: '/ca/validation',
          builder: (context, state) => const CaValidationScreen(),
        ),
        GoRoute(
          path: '/chantier/:ref',
          builder: (context, state) => const ChantierDetailsScreen(),
          routes: [
            GoRoute(path: 'fiche', builder: (context, state) => const FicheChantierScreen()),
            GoRoute(path: 'docs-admin', builder: (context, state) => const DocsAdminScreen()),
            GoRoute(path: 'tech', builder: (context, state) => const DossierTechniqueScreen()),
            GoRoute(path: 'reception', builder: (context, state) => const ReceptionMarchandisesScreen()),
            GoRoute(path: 'auto-controle', builder: (context, state) => const AutoControleScreen()),
            GoRoute(path: 'rex', builder: (context, state) => const RexScreen()),
            GoRoute(path: 'terrain', builder: (context, state) => const DocsTerrainScreen()),
          ],
        ),
        GoRoute(path: '/signature', builder: (context, state) => const SignatureScreen()),
        GoRoute(path: '/confirmation', builder: (context, state) => const ConfirmationScreen()),
        GoRoute(path: '/profil', builder: (context, state) => const ProfilScreen()),

        // Back-office web — 3 espaces cloisonnés (Admin / CA / Qualité), voir
        // le garde de redirection ci-dessus pour l'accès exclusif par rôle.
        GoRoute(path: '/backoffice/login', builder: (context, state) => const BoLoginScreen()),
        GoRoute(path: '/backoffice/acces', builder: (context, state) => const BoAccessRequestScreen()),

        // Espace Chargé d'Affaires : chantiers (création, suivi, PV) + validation des installateurs.
        GoRoute(path: '/backoffice/ca', builder: (context, state) => const BoCaChantiersScreen()),
        GoRoute(path: '/backoffice/ca/chantiers/nouveau', builder: (context, state) => const BoNewChantierScreen()),
        GoRoute(path: '/backoffice/ca/chantiers/:ref', builder: (context, state) => const BoChantierDetailScreen()),
        GoRoute(path: '/backoffice/ca/comptes', builder: (context, state) => const BoComptesScreen()),

        // Espace Qualité : auto-contrôles, REX, anomalies, habilitations.
        GoRoute(path: '/backoffice/qualite', builder: (context, state) => const BoQualiteScreen()),

        // Espace Administration : flux d'activité + validation des comptes internes.
        GoRoute(path: '/backoffice/admin', builder: (context, state) => const BoAdminDashboardScreen()),
      ],
    );
  }
}
