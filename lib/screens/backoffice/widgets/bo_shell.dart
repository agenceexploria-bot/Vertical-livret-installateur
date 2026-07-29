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
  final IconData icon;
  const _BoNavTab(this.label, this.route, this.key, this.icon);
}

class _BoSpace {
  final String name;
  final List<_BoNavTab> tabs;
  const _BoSpace(this.name, this.tabs);
}

const _caTabs = [
  _BoNavTab('Chantiers', '/backoffice/ca', 'chantiers', Icons.apartment_outlined),
  _BoNavTab('Comptes', '/backoffice/ca/comptes', 'comptes', Icons.groups_outlined),
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
    _BoNavTab('Tableau de bord', '/backoffice/admin', 'admin', Icons.space_dashboard_outlined),
    ..._caTabs,
  ]),
  UserRole.chargeAffaires: _caSpace,
  UserRole.direction: _caSpace,
  UserRole.qualite: _caSpace,
};

/// En dessous de cette largeur, la navigation bascule d'un rail latéral
/// déployable au survol vers un tiroir (Drawer) standard — le back-office est
/// déjà bloqué sur mobile natif par le routeur (voir router.dart), ce seuil
/// ne sert donc qu'aux fenêtres de navigateur étroites (redimensionnement,
/// tablette).
const _kMobileBreakpoint = 860.0;

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

    final effectiveSpace = space ?? const _BoSpace('', []);
    final isNarrow = MediaQuery.sizeOf(context).width < _kMobileBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.fond,
      drawer: isNarrow ? _BoDrawer(activeNav: activeNav, space: effectiveSpace) : null,
      appBar: _BoAppBar(
        initials: initials,
        space: effectiveSpace,
        showMenuButton: isNarrow,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isNarrow) _HoverSidebar(activeNav: activeNav, space: effectiveSpace),
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

class _BoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String initials;
  final _BoSpace space;
  final bool showMenuButton;

  const _BoAppBar({required this.initials, required this.space, required this.showMenuButton});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.encre,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      automaticallyImplyLeading: showMenuButton,
      titleSpacing: showMenuButton ? 0 : 24,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40, child: VerticalLogo(height: 40, onDarkBackground: true)),
          if (space.name.isNotEmpty) ...[
            const SizedBox(width: 16),
            Container(
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
          ],
        ],
      ),
      actions: [
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
        const SizedBox(width: 24),
      ],
    );
  }
}

/// Rail de navigation latéral, replié par défaut, qui se déploie avec une
/// animation fluide au survol de la souris pour révéler les libellés — pas de
/// barre latérale fixe qui grignoterait en permanence l'espace du contenu.
class _HoverSidebar extends StatefulWidget {
  final String activeNav;
  final _BoSpace space;

  const _HoverSidebar({required this.activeNav, required this.space});

  @override
  State<_HoverSidebar> createState() => _HoverSidebarState();
}

class _HoverSidebarState extends State<_HoverSidebar> {
  static const _collapsedWidth = 72.0;
  static const _expandedWidth = 236.0;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _expanded = true),
      onExit: (_) => setState(() => _expanded = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        width: _expanded ? _expandedWidth : _collapsedWidth,
        color: AppColors.encre,
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              for (final tab in widget.space.tabs)
                _SidebarLink(tab: tab, isActive: widget.activeNav == tab.key, expanded: _expanded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  final _BoNavTab tab;
  final bool isActive;
  final bool expanded;

  const _SidebarLink({required this.tab, required this.isActive, required this.expanded});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Tooltip(
        message: expanded ? '' : tab.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            // Fond sombre du rail : la teinte de survol globale (claire, voir
            // ThemeData.hoverColor) y serait quasi invisible.
            hoverColor: Colors.white.withValues(alpha: 0.08),
            onTap: () => context.go(tab.route),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withValues(alpha: 0.12) : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(tab.icon, color: isActive ? Colors.white : const Color(0xFFB9C4CE), size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ClipRect(
                      child: AnimatedOpacity(
                        opacity: expanded ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          tab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isActive ? Colors.white : const Color(0xFFB9C4CE),
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiroir de navigation standard pour les fenêtres étroites (voir
/// [_kMobileBreakpoint]) — mêmes onglets que le rail latéral.
class _BoDrawer extends StatelessWidget {
  final String activeNav;
  final _BoSpace space;

  const _BoDrawer({required this.activeNav, required this.space});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.encre,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(height: 36, child: VerticalLogo(height: 36, onDarkBackground: true)),
            ),
            if (space.name.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  space.name,
                  style: const TextStyle(color: Color(0xFFB9C4CE), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(color: Colors.white24, height: 1),
            for (final tab in space.tabs)
              ListTile(
                leading: Icon(tab.icon, color: activeNav == tab.key ? Colors.white : const Color(0xFFB9C4CE)),
                title: Text(
                  tab.label,
                  style: TextStyle(
                    color: activeNav == tab.key ? Colors.white : const Color(0xFFB9C4CE),
                    fontWeight: activeNav == tab.key ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: activeNav == tab.key,
                selectedTileColor: Colors.white.withValues(alpha: 0.08),
                // Fond sombre : la teinte de survol globale (gris clair, voir
                // ThemeData.hoverColor) y serait quasi invisible — surchargée
                // ici en blanc translucide.
                hoverColor: Colors.white.withValues(alpha: 0.06),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(tab.route);
                },
              ),
          ],
        ),
      ),
    );
  }
}
