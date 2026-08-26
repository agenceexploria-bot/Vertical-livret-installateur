import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/vertical_logo.dart';
import 'package:intl/intl.dart';
import '../../../data/models/user.dart';
import '../../../state/auth_state.dart';
import '../../../state/chantier_state.dart';
import '../../../state/comptes_state.dart';
import '../../../state/notifications_state.dart';

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

const _ctTabs = [
  _BoNavTab('Chantiers', '/backoffice/ct', 'chantiers'),
  _BoNavTab('Comptes', '/backoffice/ct/comptes', 'comptes'),
];
const _ctSpace = _BoSpace('Espace Coordinateur travaux', _ctTabs);

/// Un espace back-office par rôle, utilisé pour le nom affiché et les onglets
/// de navigation (le garde côté routeur empêche déjà la navigation croisée —
/// voir router.dart / _boAllowedPrefixesFor). L'Admin est "super-CT" : en plus
/// de son propre tableau de bord, il a aussi les onglets Chantiers/Comptes de
/// l'espace CT. Le rôle Qualité n'a plus d'espace dédié depuis sa fusion dans
/// l'espace CT — l'entrée reste ici en filet de sécurité si un compte encore
/// marqué `qualite` en base atteint malgré tout cet écran.
const _spaces = <UserRole, _BoSpace>{
  UserRole.admin: _BoSpace('Espace Administration', [
    _BoNavTab('Tableau de bord', '/backoffice/admin', 'admin'),
    _BoNavTab('Listes', '/backoffice/admin/checklists', 'checklists'),
    ..._ctTabs,
  ]),
  UserRole.coordinateurTravaux: _ctSpace,
  UserRole.direction: _ctSpace,
  UserRole.qualite: _ctSpace,
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

    // L'Admin a maintenant aussi accès aux chantiers et aux comptes
    // installateurs (voir la refonte des rôles : l'Admin a toutes les
    // fonctionnalités du CT en plus des siennes), donc il précharge les mêmes
    // données que le CT/Direction.
    final needsChantiers = user?.role == UserRole.coordinateurTravaux ||
        user?.role == UserRole.direction ||
        user?.role == UserRole.admin;
    final needsComptes = needsChantiers;
    // Les notifications de prévention (auto-contrôle à 80%) ne concernent que
    // le CT et l'Admin côté backend (voir notificationsRouter) — Direction
    // n'y a pas droit.
    final needsNotifications = user?.role == UserRole.coordinateurTravaux || user?.role == UserRole.admin;

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
    if (needsNotifications) {
      final notificationsState = context.watch<NotificationsState>();
      if (notificationsState.notifications.isEmpty && !notificationsState.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.read<NotificationsState>().fetch();
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Column(
        children: [
          _TopBar(activeNav: activeNav, user: user, space: space ?? const _BoSpace('', [])),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
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
  final User? user;
  final _BoSpace space;

  const _TopBar({required this.activeNav, required this.user, required this.space});

  @override
  Widget build(BuildContext context) {
    final notifState = context.watch<NotificationsState>();
    final notifCount = notifState.nonLuesCount;

    // Logo + badge d'espace + onglets défilent horizontalement s'ils ne
    // tiennent pas (viewport téléphone) — notification et avatar restent
    // toujours visibles à droite, jamais coupés par le défilement.
    final leftCluster = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const VerticalLogo(height: 56, bubble: true),
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
          IconButton(
            onPressed: () => context.push('/backoffice/ct/auto-controle'),
            icon: const Icon(Icons.ios_share_outlined, color: Colors.white, size: 18),
            tooltip: 'Exports Qualité (PDF/CSV)',
            style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.acierClair, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              minimumSize: const Size(30, 30),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: () => _openNotifications(context, notifState),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.acierClair, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 16),
                ),
              ),
              if (notifCount > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(99)),
                      child: Text('$notifCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
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
            child: UserAvatar(user: user, radius: 15),
          ),
        ],
      ),
    );
  }

  static void _openNotifications(BuildContext context, NotificationsState notifState) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: 380,
          child: notifState.notifications.isEmpty
              ? const Text('Aucune notification.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: notifState.notifications
                        .map((n) => ListTile(
                              leading: Icon(Icons.warning_amber_rounded, color: n.lue ? AppColors.acierClair : AppColors.orange),
                              title: Text(n.message, style: const TextStyle(fontSize: 12.5)),
                              subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(n.createdAt), style: const TextStyle(fontSize: 10.5)),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                if (!n.lue) context.read<NotificationsState>().marquerLue(n.id);
                                context.go('/backoffice/ct/chantiers/${n.chantierReference}');
                              },
                            ))
                        .toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
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
