import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'platform/mobile_detector.dart';
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
import '../screens/backoffice/bo_access_confirmation_screen.dart';
import '../screens/backoffice/bo_ca_chantiers_screen.dart';
import '../screens/backoffice/bo_new_chantier_screen.dart';
import '../screens/backoffice/bo_chantier_detail_screen.dart';
import '../screens/backoffice/bo_comptes_screen.dart';
import '../screens/backoffice/bo_installateur_detail_screen.dart';
import '../screens/backoffice/bo_admin_dashboard_screen.dart';

/// Préfixes de back-office accessibles à chaque rôle interne — utilisé par le
/// garde de redirection ci-dessous. Le premier élément est la destination par
/// défaut (atterrissage). Liste vide = pas d'espace back-office (installateur).
///
/// Il n'y a plus que deux espaces (CA et Admin) depuis la fusion du rôle
/// Qualité dans l'espace CA — un compte encore marqué `qualite` en base est
/// donc simplement redirigé vers `/backoffice/ca` comme un CA. L'Admin est
/// "super-CA" : il a accès à son propre tableau de bord ET à tout l'espace CA.
List<String> _boAllowedPrefixesFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return ['/backoffice/admin', '/backoffice/ca'];
    case UserRole.chargeAffaires:
    case UserRole.direction:
    case UserRole.qualite:
      return ['/backoffice/ca'];
    case UserRole.installateur:
      return [];
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
        // Le back-office Web (BoShell, tableaux denses, plusieurs colonnes)
        // n'est pas conçu pour un écran de téléphone — le CA y a sa propre
        // interface mobile dédiée (CaHomeScreen/CaValidationScreen, atteinte
        // via /login comme n'importe quel autre rôle), avec un jeu de
        // fonctionnalités volontairement réduit (suivi chantiers, relance des
        // livrets non ouverts, validation des inscriptions) plutôt qu'une
        // version rétrécie du dashboard web. isMobileDevice() se base sur le
        // vrai user-agent sur Web (voir mobile_detector.dart) plutôt que sur
        // defaultTargetPlatform, qui reflète l'OS hôte et non le navigateur.
        final isMobilePlatform = isMobileDevice();

        if (state.matchedLocation.startsWith('/backoffice')) {
          // Back-office Web : strictement inaccessible depuis une plateforme
          // mobile, même en PWA — ça inclut /login et /acces, un mobile n'a
          // aucune raison de voir ne serait-ce que l'écran de connexion.
          if (isMobilePlatform) return '/login';

          final isBoLogin = state.matchedLocation == '/backoffice/login';
          final isBoAcces = state.matchedLocation == '/backoffice/acces';
          final isBoAccesConfirmation = state.matchedLocation == '/backoffice/acces/confirmation';
          if (isBoLogin || isBoAcces || isBoAccesConfirmation) return null;

          if (authState.isLoading) return null;
          if (!authState.isAuthenticated) return '/backoffice/login';

          // Cloisonnement : un CA qui tape /backoffice/admin est renvoyé vers
          // son propre espace. L'Admin, lui, est autorisé sur les deux
          // préfixes (son tableau de bord + tout l'espace CA, voir
          // _boAllowedPrefixesFor) — il n'est donc jamais rejeté hors de /ca.
          final allowed = _boAllowedPrefixesFor(authState.currentUser!.role);
          if (allowed.isEmpty) return '/backoffice/login';
          final isAllowed = allowed.any((prefix) => state.matchedLocation.startsWith(prefix));
          if (!isAllowed) return allowed.first;
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

          // Sur Web, le CA est dirigé vers le back-office (interface riche) —
          // sur mobile, il reste sur '/' où le builder ci-dessous affiche sa
          // propre interface dédiée (CaHomeScreen).
          final role = authState.currentUser!.role;
          final isCaRole = role == UserRole.chargeAffaires || role == UserRole.direction;
          if (!isMobilePlatform && isCaRole && authState.currentUser!.isActive && state.matchedLocation == '/') {
            return '/backoffice/ca';
          }

          // /ca/validation est réservé au CA/Direction — un autre rôle qui
          // tape l'URL à la main est renvoyé sur son propre accueil. Le
          // backend impose déjà ce rôle sur les endpoints valider/suspendre
          // (voir comptes.ts), ce garde n'est qu'une défense en profondeur.
          if (state.matchedLocation.startsWith('/ca/validation') && !isCaRole) {
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
            // Sur Web, un CA/Direction ne construit jamais cet écran : le
            // garde de redirection ci-dessus l'envoie vers /backoffice/ca
            // avant même que ce builder ne s'exécute. Sur mobile, il reste
            // ici et voit sa propre interface (CaHomeScreen).
            final role = authState.currentUser!.role;
            if (role == UserRole.chargeAffaires || role == UserRole.direction) {
              return const CaHomeScreen();
            }
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

        // Back-office web — 2 espaces (CA et Admin, ce dernier ayant aussi
        // accès à l'espace CA), voir le garde de redirection ci-dessus.
        GoRoute(path: '/backoffice/login', builder: (context, state) => const BoLoginScreen()),
        GoRoute(path: '/backoffice/acces', builder: (context, state) => const BoAccessRequestScreen()),
        GoRoute(path: '/backoffice/acces/confirmation', builder: (context, state) => const BoAccessConfirmationScreen()),

        // Espace Chargé d'Affaires : chantiers (création, suivi, PV), auto-
        // contrôles/REX/anomalies/habilitations (ex-espace Qualité, fusionné
        // ici) + validation des installateurs. Accessible aussi à l'Admin.
        GoRoute(path: '/backoffice/ca', builder: (context, state) => const BoCaChantiersScreen()),
        GoRoute(path: '/backoffice/ca/chantiers/nouveau', builder: (context, state) => const BoNewChantierScreen()),
        GoRoute(path: '/backoffice/ca/chantiers/:ref', builder: (context, state) => const BoChantierDetailScreen()),
        GoRoute(path: '/backoffice/ca/comptes', builder: (context, state) => const BoComptesScreen()),
        GoRoute(path: '/backoffice/ca/comptes/:id', builder: (context, state) => const BoInstallateurDetailScreen()),

        // Espace Administration : flux d'activité + validation des comptes
        // internes — en plus de l'espace CA ci-dessus, auquel l'Admin a aussi accès.
        GoRoute(path: '/backoffice/admin', builder: (context, state) => const BoAdminDashboardScreen()),
      ],
    );
  }
}
