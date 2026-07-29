import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/vertical_logo.dart';
import '../../../data/models/user.dart';
import '../../../state/auth_state.dart';
import '../../../state/chantier_state.dart';
import '../../../state/comptes_state.dart';

class _BoNavTab {
  final String label;
  final String route;
  final String key;
  const _BoNavTab(this.label, this.route, this.key);
}

class _BoSpace {
  final String name;
  final List<_BoNavTab> tabs;
  const _BoSpace(this.name, this.tabs);
}

const _caTabs = [
  _BoNavTab('Chantiers', '/backoffice/ca', 'chantiers'),
  _BoNavTab('Comptes', '/backoffice/ca/comptes', 'comptes'),
];
const _caSpace = _BoSpace('Espace Chargé d\'Affaires', _caTabs);

/// Un espace back-office par rôle, utilisé pour le nom affiché et les onglets
/// de navigation (le garde côté routeur empêche déjà la navigation croisée —
/// voir router.dart / _boAllowedPrefixesFor). L'Admin est "super-CA" : en plus
/// de son propre tableau de bord, il a aussi les onglets Chantiers/Comptes de
/// l'espace CA. Le rôle Qualité n'a plus d'espace dédié depuis sa fusion dans
/// l'espace CA — l'entrée reste ici en filet de sécurité si un compte encore
/// marqué `qualite` en base atteint malgré tout cet écran.
const _spaces = <UserRole, _BoSpace>{
  UserRole.admin: _BoSpace('Espace Administration', [
    _BoNavTab('Tableau de bord', '/backoffice/admin', 'admin'),
    ..._caTabs,
  ]),
  UserRole.chargeAffaires: _caSpace,
  UserRole.direction: _caSpace,
  UserRole.qualite: _caSpace,
};

class BoShell extends StatelessWidget {
  final String activeNav;
  final Widget child;

  const BoShell({super.key, required this.activeNav, required this.child});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    if (!authState.isLoading && !authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/backoffice/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final user = authState.currentUser;
    final space = user == null ? null : _spaces[user.role];

    // Le mobile installateur et le back-office partagent la même session :
    // sans cette vérification, une session installateur déjà ouverte laisse
    // passer l'écran mais tous les appels internes échouent en 403
    // silencieusement, donnant l'impression d'un back-office vide. Le
    // routeur bloque déjà ce cas en amont — ceci n'est qu'un filet de sécurité.
    if (!authState.isLoading && user != null && space == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await context.read<AuthState>().logout();
        if (context.mounted) context.go('/backoffice/login');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final initials = user == null
        ? '?'
        : '${user.prenom.isNotEmpty ? user.prenom[0] : ''}${user.nom.isNotEmpty ? user.nom[0] : ''}';

    // L'Admin a maintenant aussi accès aux chantiers et aux comptes
    // installateurs (voir la refonte des rôles : l'Admin a toutes les
    // fonctionnalités du CA en plus des siennes), donc il précharge les mêmes
    // données que le CA/Direction.
    final needsChantiers = user?.role == UserRole.chargeAffaires ||
        user?.role == UserRole.direction ||
        user?.role == UserRole.admin;
    final needsComptes = needsChantiers;

    if (needsChantiers) {
      final chantierState = context.watch<ChantierState>();
      if (user != null && chantierState.chantiers.isEmpty && !chantierState.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.read<ChantierState>().fetchChantiers(user);
        });
      }
    }
    if (needsComptes) {
      final comptesState = context.watch<ComptesState>();
      if (comptesState.installateurs.isEmpty && !comptesState.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.read<ComptesState>().fetch();
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Column(
        children: [
          _TopBar(activeNav: activeNav, initials: initials, space: space ?? const _BoSpace('', [])),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String activeNav;
  final String initials;
  final _BoSpace space;

  const _TopBar({required this.activeNav, required this.initials, required this.space});

  @override
  Widget build(BuildContext context) {
    // Logo + badge d'espace + onglets défilent horizontalement s'ils ne
    // tiennent pas (viewport téléphone) — notification et avatar restent
    // toujours visibles à droite, jamais coupés par le défilement.
    final leftCluster = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 46, child: VerticalLogo(height: 46, onDarkBackground: true)),
        const SizedBox(width: 20),
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFB9C4CE)),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            space.name,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 16),
        for (final tab in space.tabs) ...[
          _NavLink(label: tab.label, route: tab.route, isActive: activeNav == tab.key),
          const SizedBox(width: 18),
        ],
      ],
    );

    return Container(
      color: AppColors.encre,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: leftCluster,
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.acierClair, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 16),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(99)),
                  child: const Text('3', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profil') context.push('/profil');
              if (value == 'logout') context.read<AuthState>().logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profil',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: AppColors.acier, size: 18),
                    SizedBox(width: 10),
                    Text('Profil'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.rouge, size: 18),
                    SizedBox(width: 10),
                    Text('Déconnexion', style: TextStyle(color: AppColors.rouge)),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.acier,
              child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final String route;
  final bool isActive;

  const _NavLink({required this.label, required this.route, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(6),
        // Fond sombre de la barre : la teinte de survol globale (claire, voir
        // ThemeData.hoverColor) y serait quasi invisible.
        hoverColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Container(
            decoration: isActive
                ? const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 2)))
                : null,
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFFB9C4CE),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
