import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/password_field.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/status_indicator.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/api_client.dart';
import '../../data/models/user.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_panel.dart';
import 'widgets/bo_responsive_table.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_table_row.dart';

class BoComptesScreen extends StatefulWidget {
  const BoComptesScreen({super.key});

  @override
  State<BoComptesScreen> createState() => _BoComptesScreenState();
}

class _BoComptesScreenState extends State<BoComptesScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Exécute une action serveur (valider/suspendre/réactiver/supprimer un
  /// compte) et affiche un message clair en cas d'échec — sans ça, un clic
  /// qui échoue (droits insuffisants, réseau...) ne montrait strictement
  /// rien à l'utilisateur (exception non attendue, silencieuse).
  Future<void> _handleAction(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Une erreur est survenue. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthState>().currentUser?.role == UserRole.admin;

    // L'Admin a le contrôle total sur TOUS les comptes du système (voir la
    // refonte des rôles) — accessible uniquement via cet onglet 'Comptes',
    // pas depuis le tableau de bord. Le CT/Direction ne voit lui que ses
    // installateurs ci-dessous, inchangé.
    if (isAdmin) {
      final adminState = context.watch<AdminState>();
      if (adminState.tousLesComptes.isEmpty && !adminState.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.read<AdminState>().fetch();
        });
      }
      return BoShell(
        activeNav: 'comptes',
        child: _buildGestionComptes(context, adminState),
      );
    }

    final comptesState = context.watch<ComptesState>();
    final chantiers = context.watch<ChantierState>().chantiers;

    final query = _search.trim().toLowerCase();
    final installateurs = query.isEmpty
        ? comptesState.installateurs
        : comptesState.installateurs
            .where((u) => u.nom.toLowerCase().contains(query) || u.prenom.toLowerCase().contains(query))
            .toList();

    return BoShell(
      activeNav: 'comptes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Comptes installateurs', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (installateurs.isEmpty)
            BoPanel(
              child: EmptyState(
                icon: Icons.groups_outlined,
                message: query.isEmpty ? 'Aucun compte installateur pour l\'instant.' : 'Aucun résultat pour « ${_search.trim()} ».',
              ),
            )
          else
            BoResponsiveTable(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.blanc,
                  border: Border.all(color: AppColors.lignes),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: AppColors.encre.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _headerRow(),
                    for (final (i, u) in installateurs.indexed) _dataRow(context, u, chantiers, comptesState, i),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Ordre d'affichage des groupes — du plus "back-office" au plus nombreux,
  // Qualité en dernier car legacy (fusionné dans l'espace CT, voir ailleurs).
  static const _ordreGroupes = [UserRole.coordinateurTravaux, UserRole.direction, UserRole.installateur, UserRole.qualite];

  /// Gestion globale des comptes (Admin uniquement) : contrairement à la table
  /// ci-dessous (réservée aux installateurs, utilisée aussi par le CT), cette
  /// vue couvre tous les rôles sauf Admin (exclus côté backend) — seul
  /// l'Admin peut supprimer, réinitialiser le mot de passe ou
  /// suspendre/réactiver un compte. Regroupés par rôle plutôt qu'un seul
  /// grand tableau, pour rester lisible à mesure que les comptes s'accumulent.
  Widget _buildGestionComptes(BuildContext context, AdminState adminState) {
    final tousLesComptes = adminState.tousLesComptes;

    final query = _search.trim().toLowerCase();
    final comptes = query.isEmpty
        ? tousLesComptes
        : tousLesComptes
            .where((u) =>
                u.nom.toLowerCase().contains(query) ||
                u.prenom.toLowerCase().contains(query) ||
                (u.email?.toLowerCase().contains(query) ?? false))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Gestion des comptes (${tousLesComptes.length})', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  hintText: 'Nom, prénom ou email...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tous les comptes installateurs et chargés d\'affaires du système.',
          style: TextStyle(fontSize: 12.5, color: AppColors.acierClair),
        ),
        const SizedBox(height: 18),
        if (comptes.isEmpty)
          BoPanel(
            child: EmptyState(
              icon: Icons.groups_outlined,
              message: query.isEmpty ? 'Aucun compte enregistré pour l\'instant.' : 'Aucun compte trouvé pour « ${_search.trim()} ».',
            ),
          ),
        for (final role in _ordreGroupes) ...[
          () {
            final groupe = comptes.where((u) => u.role == role).toList();
            if (groupe.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BoPanel(
                title: '${_roleLabelPluriel(role)} (${groupe.length})',
                child: BoResponsiveTable(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.blanc,
                      border: Border.all(color: AppColors.lignes),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _comptesHeaderRow(),
                        for (final (i, u) in groupe.indexed) _comptesDataRow(context, adminState, u, i),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }(),
        ],
      ],
    );
  }

  String _roleLabelPluriel(UserRole role) {
    switch (role) {
      case UserRole.installateur:
        return 'Installateurs';
      case UserRole.coordinateurTravaux:
        return 'Coordinateurs travaux';
      case UserRole.qualite:
        return 'Qualité';
      case UserRole.direction:
        return 'Direction';
      case UserRole.admin:
        return 'Admins';
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.installateur:
        return 'Installateur';
      case UserRole.coordinateurTravaux:
        return 'Coordinateur travaux';
      case UserRole.qualite:
        return 'Qualité';
      case UserRole.direction:
        return 'Direction';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Widget _comptesHeaderRow() {
    const style = TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.acier, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFFEDF0F2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('COMPTE', style: style)),
          Expanded(flex: 2, child: Text('RÔLE', style: style)),
          Expanded(flex: 3, child: Text('EMAIL', style: style)),
          Expanded(flex: 2, child: Text('STATUT', style: style)),
          Expanded(flex: 2, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  Widget _comptesDataRow(BuildContext context, AdminState adminState, User u, int index) {
    final (statutLabel, statutType) = u.suspendu
        ? ('Suspendu', StatusType.attente)
        : !u.isActive
            ? ('En attente', StatusType.enCours)
            : ('Actif', StatusType.conforme);

    return BoTableRow(
      onTap: () => context.push('/backoffice/admin/comptes/${u.id}'),
      border: const Border(top: BorderSide(color: AppColors.lignes)),
      backgroundColor: index.isOdd ? const Color(0xFFF7F8F9) : null,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                UserAvatar(user: u, radius: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    u.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(_roleLabel(u.role), style: const TextStyle(fontSize: 12.5, color: AppColors.acier))),
          Expanded(flex: 3, child: Text(u.email ?? '—', style: const TextStyle(fontSize: 12.5, color: AppColors.acier))),
          Expanded(flex: 2, child: StatusBadge(label: statutLabel, type: statutType)),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Validation d'un compte fraîchement inscrit — deux routes
                // backend distinctes selon le rôle : comptes-internes/:id/valider
                // (CT/Qualité, voir AdminState.validerCompteInterne) ou
                // comptes/:id/valider (installateur uniquement, voir
                // AdminState.validerCompte) ; direction/admin ne passent
                // jamais par cet état "en attente" (créés déjà actifs).
                if (!u.isActive && !u.suspendu && (u.role == UserRole.coordinateurTravaux || u.role == UserRole.qualite))
                  ElevatedButton.icon(
                    onPressed: () => _handleAction(context, () => adminState.validerCompteInterne(u)),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                if (!u.isActive && !u.suspendu && u.role == UserRole.installateur)
                  ElevatedButton.icon(
                    onPressed: () => _handleAction(context, () => adminState.validerCompte(u)),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                if (u.suspendu)
                  OutlinedButton.icon(
                    onPressed: () => _handleAction(context, () => adminState.reactiverCompte(u)),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Réactiver'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.acierClair),
                  onSelected: (value) => _onComptesMenuAction(context, adminState, u, value),
                  itemBuilder: (context) => [
                    if (!u.suspendu) const PopupMenuItem(value: 'suspendre', child: Text('Suspendre')),
                    const PopupMenuItem(value: 'reinit', child: Text('Réinitialiser le mot de passe')),
                    const PopupMenuItem(value: 'supprimer', child: Text('Supprimer le compte')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onComptesMenuAction(BuildContext context, AdminState adminState, User u, String value) {
    switch (value) {
      case 'suspendre':
        _handleAction(context, () => adminState.suspendreCompte(u));
        break;
      case 'reinit':
        _openAdminReinitDialog(context, adminState, u);
        break;
      case 'supprimer':
        _confirmerAdminSuppression(context, adminState, u);
        break;
    }
  }

  void _openAdminReinitDialog(BuildContext context, AdminState adminState, User u) {
    final controller = TextEditingController();
    bool isSubmitting = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Réinitialiser le mot de passe de ${u.fullName}'),
          content: SizedBox(
            width: 320,
            child: PasswordField(
              controller: controller,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe', hintText: 'Au moins 6 caractères'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: controller.text.trim().length < 6 || isSubmitting
                  ? null
                  : () async {
                      setState(() => isSubmitting = true);
                      try {
                        await adminState.reinitialiserMotDePasse(u, controller.text.trim());
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } on ApiException catch (e) {
                        if (!dialogContext.mounted) return;
                        setState(() => isSubmitting = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(e.message)));
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        setState(() => isSubmitting = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Une erreur est survenue. Réessayez.')),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Réinitialiser'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmerAdminSuppression(BuildContext context, AdminState adminState, User u) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text('Le compte de ${u.fullName} sera supprimé définitivement. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleAction(context, () => adminState.supprimerCompte(u));
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  void _onMenuAction(BuildContext context, ComptesState comptesState, User u, String value) {
    switch (value) {
      case 'suspendre':
        _handleAction(context, () => comptesState.suspendre(u));
        break;
      case 'reinit':
        _openReinitDialog(context, comptesState, u);
        break;
    }
  }

  void _openReinitDialog(BuildContext context, ComptesState comptesState, User u) {
    final controller = TextEditingController();
    bool isSubmitting = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Réinitialiser le mot de passe de ${u.fullName}'),
          content: SizedBox(
            width: 320,
            child: PasswordField(
              controller: controller,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe', hintText: 'Au moins 6 caractères'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: controller.text.trim().length < 6 || isSubmitting
                  ? null
                  : () async {
                      setState(() => isSubmitting = true);
                      try {
                        await comptesState.reinitialiserMotDePasse(u, controller.text.trim());
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } on ApiException catch (e) {
                        if (!dialogContext.mounted) return;
                        setState(() => isSubmitting = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(e.message)));
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        setState(() => isSubmitting = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Une erreur est survenue. Réessayez.')),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Réinitialiser'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow() {
    const style = TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.acier, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFFEDF0F2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('INSTALLATEUR', style: style)),
          Expanded(flex: 3, child: Text('STATUT', style: style)),
          Expanded(flex: 2, child: Text('COMPTE', style: style)),
          Expanded(flex: 3, child: Text('HABILITATIONS', style: style)),
          Expanded(flex: 2, child: Text('CHANTIERS', style: style)),
          Expanded(flex: 2, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }

  Widget _dataRow(BuildContext context, User u, List chantiers, ComptesState comptesState, int index) {
    final (compteLabel, compteType) = u.suspendu
        ? ('Suspendu', StatusType.attente)
        : !u.isActive
            ? ('En attente', StatusType.enCours)
            : ('Actif', StatusType.conforme);

    final expired = u.habilitations.where((h) => h.isExpired).toList();
    final expiringSoon = u.habilitations.where((h) => !h.isExpired && h.expiresSoon).toList();
    final (habLabel, habType) = u.habilitations.isEmpty
        ? ('—', StatusType.factuel)
        : expired.isNotEmpty || expiringSoon.isNotEmpty
            ? ('${expiringSoon.isNotEmpty ? expiringSoon.first.titre.split(' ').first : expired.first.titre.split(' ').first} — à surveiller', StatusType.nonConforme)
            : ('À jour', StatusType.conforme);

    final mesChantiers = chantiers.where((c) => c.installateursRattaches.any((r) => r.id == u.id)).map((c) => c.reference).join(', ');

    final statutLabel = u.status == UserStatus.sousTraitant ? 'Sous-traitant${u.societe != null ? ' · ${u.societe}' : ''}' : 'Salarié';

    Widget? primaryAction;
    if (!u.isActive) {
      primaryAction = ElevatedButton.icon(
        onPressed: () => _handleAction(context, () => comptesState.valider(u)),
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Valider'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
      );
    } else if (u.suspendu) {
      primaryAction = OutlinedButton.icon(
        onPressed: () => _handleAction(context, () => comptesState.reactiver(u)),
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Réactiver'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
      );
    }

    final action = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?primaryAction,
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.acierClair),
          onSelected: (value) => _onMenuAction(context, comptesState, u, value),
          itemBuilder: (context) => [
            if (u.isActive && !u.suspendu) const PopupMenuItem(value: 'suspendre', child: Text('Suspendre')),
            const PopupMenuItem(value: 'reinit', child: Text('Réinitialiser le mot de passe')),
          ],
        ),
      ],
    );

    return BoTableRow(
      onTap: () => context.push('/backoffice/ct/comptes/${u.id}'),
      border: const Border(top: BorderSide(color: AppColors.lignes)),
      backgroundColor: index.isOdd ? const Color(0xFFF7F8F9) : null,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                UserAvatar(user: u, radius: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    u.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 3, child: Text(statutLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.acier))),
          Expanded(flex: 2, child: StatusBadge(label: compteLabel, type: compteType)),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: u.habilitations.any((h) => h.filePath != null)
                  ? () => launchUrl(Uri.parse(u.habilitations.firstWhere((h) => h.filePath != null).filePath!))
                  : null,
              child: StatusIndicator(label: habLabel, type: habType),
            ),
          ),
          Expanded(flex: 2, child: Text(mesChantiers.isEmpty ? '—' : mesChantiers, style: const TextStyle(fontSize: 12.5))),
          Expanded(flex: 2, child: action),
        ],
      ),
    );
  }
}
