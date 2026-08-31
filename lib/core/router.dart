import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'platform/mobile_detector.dart';
import '../state/auth_state.dart';
import '../data/models/user.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
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
import '../screens/client/pv_formulaire_screen.dart';
import '../screens/client/confirmation_screen.dart';
import '../screens/coordinateur_travaux/ct_home_screen.dart';
import '../screens/coordinateur_travaux/ct_validation_screen.dart';
import '../screens/coordinateur_travaux/ct_chantier_detail_screen.dart';
import '../screens/coordinateur_travaux/ct_edit_chantier_screen.dart';
import '../screens/coordinateur_travaux/ct_new_chantier_screen.dart';
import '../screens/backoffice/bo_login_screen.dart';
import '../screens/backoffice/bo_access_request_screen.dart';
import '../screens/backoffice/bo_access_confirmation_screen.dart';
import '../screens/backoffice/bo_ct_chantiers_screen.dart';
import '../screens/backoffice/bo_auto_controle_detail_screen.dart';
import '../screens/backoffice/bo_new_chantier_screen.dart';
import '../screens/backoffice/bo_chantier_detail_screen.dart';
import '../screens/backoffice/bo_comptes_screen.dart';
import '../screens/backoffice/bo_installateur_detail_screen.dart';
import '../screens/backoffice/bo_admin_compte_detail_screen.dart';
import '../screens/backoffice/bo_admin_dashboard_screen.dart';
import '../screens/backoffice/bo_admin_checklists_screen.dart';

/// Préfixes de back-office accessibles à chaque rôle interne — utilisé par le
/// garde de redirection ci-dessous. Le premier élément est la destination par
/// défaut (atterrissage). Liste vide = pas d'espace back-office (installateur).
///
/// Il n'y a plus que deux espaces (CT et Admin) depuis la fusion du rôle
/// Qualité dans l'espace CT — un compte encore marqué `qualite` en base est
/// donc simplement redirigé vers `/backoffice/ct` comme un CT. L'Admin est
/// "super-CT" : il a accès à son propre tableau de bord ET à tout l'espace CT.
List<String> _boAllowedPrefixesFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return ['/backoffice/admin', '/backoffice/ct'];
    case UserRole.coordinateurTravaux:
    case UserRole.direction:
    case UserRole.qualite:
      return ['/backoffice/ct'];
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
      // isMobileDevice() couvre à la fois le natif (Android/iOS) et le mobile
      // Web (PWA Safari sur iPhone comprise, via le vrai user-agent — voir
      // mobile_detector.dart) : c'est le même critère déjà utilisé plus bas
      // pour distinguer back-office Web vs interface mobile, donc l'écran de
      // lancement suit exactement la même définition de "mobile" que le reste
      // du routeur.
      initialLocation: isMobileDevice() ? '/splash' : '/',
      refreshListenable: authState,
      redirect: (context, state) {
        // L'écran de lancement gère lui-même sa temporisation puis appelle
        // context.go('/') — sans cette sortie précoce, le moindre changement
        // d'état de authState (ex. fin du chargement de la session) le
        // court-circuiterait immédiatement via refreshListenable.
        if (state.matchedLocation == '/splash') return null;

        // Le back-office Web (BoShell, tableaux denses, plusieurs colonnes)
        // n'est pas conçu pour un écran de téléphone — le CT y a sa propre
        // interface mobile dédiée (CtHomeScreen/CtValidationScreen, atteinte
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

          // Cloisonnement : un CT qui tape /backoffice/admin est renvoyé vers
          // son propre espace. L'Admin, lui, est autorisé sur les deux
          // préfixes (son tableau de bord + tout l'espace CT, voir
          // _boAllowedPrefixesFor) — il n'est donc jamais rejeté hors de /ct.
          final allowed = _boAllowedPrefixesFor(authState.currentUser!.role);
          if (allowed.isEmpty) return '/backoffice/login';
          final isAllowed = allowed.any((prefix) => state.matchedLocation.startsWith(prefix));
          if (!isAllowed) return allowed.first;
          return null;
        }

        final isLoggingIn = state.matchedLocation == '/login';
        final isSigningUp = state.matchedLocation == '/signup';
        final isPending = state.matchedLocation == '/pending';
        final isForgotPassword = state.matchedLocation == '/forgot-password';
        final isResetPassword = state.matchedLocation == '/reset-password';

        // Tant que la session n'est pas encore résolue (vérification du jeton
        // au démarrage), on ne redirige nulle part — voir aussi le garde dans
        // le builder de '/' qui empêche d'afficher un écran avec un user nul.
        if (authState.isLoading) return null;

        if (!authState.isAuthenticated && !isLoggingIn && !isSigningUp && !isForgotPassword && !isResetPassword) {
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

          // Sur Web, le CT est dirigé vers le back-office (interface riche) —
          // sur mobile, il reste sur '/' où le builder ci-dessous affiche sa
          // propre interface dédiée (CtHomeScreen).
          final role = authState.currentUser!.role;
          final isCtRole = role == UserRole.coordinateurTravaux || role == UserRole.direction;
          if (!isMobilePlatform && isCtRole && authState.currentUser!.isActive && state.matchedLocation == '/') {
            return '/backoffice/ct';
          }

          // /ct/validation et /ct/chantier sont réservés au CT/Direction — un
          // autre rôle qui tape l'URL à la main est renvoyé sur son propre
          // accueil. Le backend impose déjà ce rôle sur les endpoints
          // concernés (voir comptes.ts / chantiers.ts), ces gardes ne sont
          // qu'une défense en profondeur.
          if (state.matchedLocation.startsWith('/ct/validation') && !isCtRole) {
            return '/';
          }
          if (state.matchedLocation.startsWith('/ct/chantier') && !isCtRole) {
            return '/';
          }
        }

        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
        GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => ResetPasswordScreen(email: state.extra as String? ?? ''),
        ),
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
            // Sur Web, un CT/Direction ne construit jamais cet écran : le
            // garde de redirection ci-dessus l'envoie vers /backoffice/ct
            // avant même que ce builder ne s'exécute. Sur mobile, il reste
            // ici et voit sa propre interface (CtHomeScreen).
            final role = authState.currentUser!.role;
            if (role == UserRole.coordinateurTravaux || role == UserRole.direction) {
              return const CtHomeScreen();
            }
            return const InstallateurHomeScreen();
          },
        ),
        GoRoute(
          path: '/ct/validation',
          builder: (context, state) => const CtValidationScreen(),
        ),
        // Mobile CT — consultation, création et modification de chantier
        // (interface volontairement réduite par rapport au back-office Web,
        // voir CtHomeScreen). '/ct/chantier/nouveau' est un chemin littéral :
        // il prend priorité sur le paramètre ':ref' ci-dessous, comme
        // '/backoffice/ct/chantiers/nouveau' le fait déjà côté Web.
        GoRoute(
          path: '/ct/chantier/nouveau',
          builder: (context, state) => const CtNewChantierScreen(),
        ),
        GoRoute(
          path: '/ct/chantier/:ref',
          builder: (context, state) => const CtChantierDetailScreen(),
          routes: [
            GoRoute(path: 'modifier', builder: (context, state) => const CtEditChantierScreen()),
          ],
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
        // Formulaire PV interactif (gabarit officiel Vertical) — remplace la
        // signature directe sur PDF pour tout chantier sans gabarit déjà
        // déposé (voir la bascule dans chantier_details_screen.dart).
        GoRoute(path: '/pv-formulaire', builder: (context, state) => const PvFormulaireScreen()),
        GoRoute(path: '/confirmation', builder: (context, state) => const ConfirmationScreen()),
        GoRoute(path: '/profil', builder: (context, state) => const ProfilScreen()),

        // Back-office web — 2 espaces (CT et Admin, ce dernier ayant aussi
        // accès à l'espace CT), voir le garde de redirection ci-dessus.
        GoRoute(path: '/backoffice/login', builder: (context, state) => const BoLoginScreen()),
        GoRoute(path: '/backoffice/acces', builder: (context, state) => const BoAccessRequestScreen()),
        GoRoute(path: '/backoffice/acces/confirmation', builder: (context, state) => const BoAccessConfirmationScreen()),

        // Espace Coordinateur travaux : chantiers (création, suivi, PV), auto-
        // contrôles/REX/anomalies/habilitations (ex-espace Qualité, fusionné
        // ici) + validation des installateurs. Accessible aussi à l'Admin.
        GoRoute(path: '/backoffice/ct', builder: (context, state) => const BoCtChantiersScreen()),
        GoRoute(path: '/backoffice/ct/auto-controle', builder: (context, state) => const BoAutoControleDetailScreen()),
        GoRoute(path: '/backoffice/ct/chantiers/nouveau', builder: (context, state) => const BoNewChantierScreen()),
        GoRoute(path: '/backoffice/ct/chantiers/:ref', builder: (context, state) => const BoChantierDetailScreen()),
        GoRoute(path: '/backoffice/ct/comptes', builder: (context, state) => const BoComptesScreen()),
        GoRoute(path: '/backoffice/ct/comptes/:id', builder: (context, state) => const BoInstallateurDetailScreen()),

        // Espace Administration : flux d'activité + validation des comptes
        // internes — en plus de l'espace CT ci-dessus, auquel l'Admin a aussi accès.
        GoRoute(path: '/backoffice/admin', builder: (context, state) => const BoAdminDashboardScreen()),
        // Fiche détaillée d'un compte, tous rôles confondus (sauf Admin) — voir
        // BoAdminCompteDetailScreen, distincte de /backoffice/ct/comptes/:id
        // (BoInstallateurDetailScreen) qui ne couvre que les installateurs.
        GoRoute(path: '/backoffice/admin/comptes/:id', builder: (context, state) => const BoAdminCompteDetailScreen()),
        // Listes de réception/contrôle appliquées aux nouveaux chantiers —
        // voir BoAdminChecklistsScreen / checklistTemplates.ts.
        GoRoute(path: '/backoffice/admin/checklists', builder: (context, state) => const BoAdminChecklistsScreen()),
      ],
    );
  }
}
