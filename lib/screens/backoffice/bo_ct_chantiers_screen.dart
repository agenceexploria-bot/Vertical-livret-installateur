import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/dashboard_stat_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/models/chantier.dart';
import '../../data/models/point_controle.dart';
import '../../data/models/user.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';
import 'widgets/bo_responsive_table.dart';
import 'widgets/bo_table_row.dart';
import 'widgets/creer_sav_dialog.dart';

/// Espace Coordinateur travaux — gestion des chantiers (création, suivi, PV
/// signés pour facturation), validation des installateurs, et — depuis la
/// fusion du rôle Qualité dans cet espace — auto-contrôles, REX à qualifier,
/// anomalies et habilitations.
class BoCtChantiersScreen extends StatefulWidget {
  const BoCtChantiersScreen({super.key});

  @override
  State<BoCtChantiersScreen> createState() => _BoCtChantiersScreenState();
}

enum _TableauSegment { enCours, termines, tous }

/// Un installateur rattaché n'a pas encore ouvert son livret pour ce
/// chantier (vérification de la veille, EX-22) — la seule partie de
/// l'ancien panneau "À traiter" qui concerne un chantier précis (une
/// inscription à valider ne l'est pas, voir bo_comptes_screen.dart, déjà
/// l'écran approprié pour ça).
bool _aLivretNonOuvert(Chantier c) => c.installateursRattaches.any((u) => !c.livretsOuverts.contains(u.id));

class _BoCtChantiersScreenState extends State<BoCtChantiersScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  _TableauSegment _segment = _TableauSegment.enCours;
  bool _aTraiterOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chantierState = context.watch<ChantierState>();
    final tous = chantierState.chantiers;
    final enCours = chantierState.chantiersEnCoursList;
    final termines = chantierState.chantiersTerminesList;
    final segmentList = switch (_segment) {
      _TableauSegment.enCours => enCours,
      _TableauSegment.termines => termines,
      _TableauSegment.tous => tous,
    };
    // Compté sur l'ensemble des chantiers (pas seulement le segment actif) :
    // le badge du chip reste stable quel que soit le filtre principal
    // sélectionné, plutôt que de changer de sens selon l'onglet.
    final aTraiterCount = tous.where(_aLivretNonOuvert).length;
    final afterATraiter = _aTraiterOnly ? segmentList.where(_aLivretNonOuvert).toList() : segmentList;

    final query = _search.trim().toLowerCase();
    final filteredChantiers = query.isEmpty
        ? afterATraiter
        : afterATraiter.where((c) => c.reference.toLowerCase().contains(query) || c.client.toLowerCase().contains(query)).toList();

    return BoShell(
      activeNav: 'chantiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(context, tous),
          const SizedBox(height: 20),
          _buildFiltersRow(
            context,
            enCoursCount: enCours.length,
            terminesCount: termines.length,
            tousCount: tous.length,
            aTraiterCount: aTraiterCount,
          ),
          const SizedBox(height: 16),
          _buildTable(context, filteredChantiers, query.isNotEmpty),
          const SizedBox(height: 20),
          _buildAnomalies(tous),
          const SizedBox(height: 16),
          _buildHabilitations(context),
        ],
      ),
    );
  }

  /// Vue d'ensemble en un coup d'œil, au-dessus du détail — les compteurs
  /// urgents (anomalies, éléments à traiter) sont mis en évidence par un
  /// point orange (voir [DashboardStatCard.urgent]). [Wrap] plutôt qu'une
  /// grille à ratio fixe : chaque carte garde une hauteur fixe raisonnable
  /// quel que soit le nombre de colonnes (2 sur mobile étroit, jusqu'à 4 en
  /// large), sans jamais dépendre d'un childAspectRatio qui écraserait le
  /// contenu à une largeur donnée.
  Widget _buildStatsGrid(BuildContext context, List<Chantier> chantiers) {
    final comptesState = context.watch<ComptesState>();
    final enCours = chantiers.where((c) => !c.pvSigne).length;
    final pvSignes = chantiers.where((c) => c.pvSigne).length;
    final anomalies = chantiers
        .expand((c) => [...c.receptionMarchandises, ...c.autoControle])
        .where((p) => p.status == PointStatus.nonConforme)
        .length;
    final aTraiter = comptesState.installateurs.where((u) => !u.isActive).length + chantiers.where(_aLivretNonOuvert).length;

    final cards = [
      DashboardStatCard(icon: Icons.construction_outlined, value: '$enCours', label: 'Chantiers en cours', color: AppColors.acier),
      DashboardStatCard(icon: Icons.verified_outlined, value: '$pvSignes', label: 'PV signés', color: AppColors.vert),
      DashboardStatCard(
        icon: Icons.warning_amber_rounded,
        value: '$anomalies',
        label: 'Anomalies signalées',
        color: AppColors.rouge,
        urgent: anomalies > 0,
      ),
      DashboardStatCard(
        icon: Icons.pending_actions_outlined,
        value: '$aTraiter',
        label: 'Éléments à traiter',
        color: AppColors.orange,
        urgent: aTraiter > 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 480 ? 2 : 1);
        const spacing = 16.0;
        final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final card in cards) SizedBox(width: cardWidth, height: 88, child: card)],
        );
      },
    );
  }

  /// Filtre principal (En cours / Terminés / Tous, mutuellement exclusifs)
  /// + filtre additionnel (À traiter, cumulable) + recherche + action —
  /// [Wrap] pour que chaque élément retombe sur sa propre ligne dès que la
  /// largeur manque, plutôt qu'un débordement horizontal (voir l'ancien
  /// Row rigide, remplacé).
  Widget _buildFiltersRow(
    BuildContext context, {
    required int enCoursCount,
    required int terminesCount,
    required int tousCount,
    required int aTraiterCount,
  }) {
    const chipTextStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: Text('En cours ($enCoursCount)', style: chipTextStyle),
          visualDensity: VisualDensity.compact,
          selected: _segment == _TableauSegment.enCours,
          onSelected: (_) => setState(() => _segment = _TableauSegment.enCours),
        ),
        ChoiceChip(
          label: Text('Terminés ($terminesCount)', style: chipTextStyle),
          visualDensity: VisualDensity.compact,
          selected: _segment == _TableauSegment.termines,
          onSelected: (_) => setState(() => _segment = _TableauSegment.termines),
        ),
        ChoiceChip(
          label: Text('Tous ($tousCount)', style: chipTextStyle),
          visualDensity: VisualDensity.compact,
          selected: _segment == _TableauSegment.tous,
          onSelected: (_) => setState(() => _segment = _TableauSegment.tous),
        ),
        FilterChip(
          label: Text('À traiter ($aTraiterCount)', style: chipTextStyle),
          visualDensity: VisualDensity.compact,
          avatar: aTraiterCount > 0 ? const Icon(Icons.pending_actions_outlined, size: 16) : null,
          selected: _aTraiterOnly,
          selectedColor: AppColors.orange.withValues(alpha: 0.18),
          checkmarkColor: AppColors.orange,
          onSelected: (value) => setState(() => _aTraiterOnly = value),
        ),
        SizedBox(
          width: 220,
          height: 36,
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: const InputDecoration(
              hintText: 'Réf. ERP ou client...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: _buildNouveauMenu(context),
        ),
      ],
    );
  }

  /// Point d'entrée "Nouveau" — un menu plutôt qu'un lien direct vers la
  /// création de chantier, pour que la création d'une intervention SAV soit
  /// aussi facile à trouver que celle d'un chantier d'installation (retour
  /// testeur : la SAV était cherchée ici, pas seulement depuis une fiche
  /// chantier existante). Le flux "Nouveau chantier" lui-même est inchangé.
  Widget _buildNouveauMenu(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => context.push('/backoffice/ct/chantiers/nouveau'),
          leadingIcon: const Icon(Icons.construction_outlined, size: 18),
          child: const Text('Nouveau chantier'),
        ),
        MenuItemButton(
          onPressed: () => _openCreerSavDialog(context),
          leadingIcon: const Icon(Icons.build_outlined, size: 18),
          child: const Text('Intervention SAV'),
        ),
      ],
      builder: (context, controller, child) {
        return ElevatedButton.icon(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.add, size: 18),
          label: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nouveau', style: TextStyle(fontSize: 13)),
              Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
        );
      },
    );
  }

  void _openCreerSavDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => CreerSavDialog(
        chantierDetailPath: (ref) => '/backoffice/ct/chantiers/$ref',
      ),
    );
  }

  /// Module SAV — distingue une intervention SAV dans la liste unifiée
  /// (installations + SAV) sans ajouter de nouvelle dimension de filtre :
  /// une intervention SAV peut être aussi bien "en cours" que "terminée",
  /// un badge la marque plutôt qu'un segment mutuellement exclusif de plus.
  Widget _savTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: const Text('SAV', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.orange)),
    );
  }

  (String, StatusType) _livretBadge(Chantier c) {
    if (c.pvSigne) return ('Terminé', StatusType.conforme);
    if (c.progressionAutoControle > 0 || c.progressionReception > 0) return ('Pose en cours', StatusType.enCours);
    if (c.installateursRattaches.isEmpty) return ('Non rattaché', StatusType.nonConforme);
    return ('Prêt', StatusType.conforme);
  }

  (String, StatusType) _pvBadge(Chantier c) {
    if (c.pvSigne) return ('Signé — facturer dans l\'ERP', StatusType.conforme);
    return ('—', StatusType.factuel);
  }

  /// Un seul tableau/liste, quel que soit le filtre actif — voir
  /// [_buildFiltersRow] pour le choix du segment, ici seulement l'affichage
  /// du résultat déjà filtré. En dessous de [_cardBreakpoint], remplace les
  /// colonnes (qui devraient sinon défiler horizontalement, voir
  /// BoResponsiveTable) par une liste de cartes compactes verticales —
  /// aucune largeur minimale à respecter, donc aucun débordement possible.
  static const _cardBreakpoint = 700.0;

  Widget _buildTable(BuildContext context, List<Chantier> chantiers, bool isSearching) {
    final emptyIcon = _aTraiterOnly
        ? Icons.check_circle_outline
        : _segment == _TableauSegment.termines
            ? Icons.check_circle_outline
            : Icons.construction_outlined;
    final emptyMessage = isSearching
        ? 'Aucun résultat pour « ${_search.trim()} ».'
        : _aTraiterOnly
            ? 'Rien à traiter pour ce filtre.'
            : switch (_segment) {
                _TableauSegment.enCours => 'Aucun chantier en cours pour l\'instant.',
                _TableauSegment.termines => 'Aucun chantier terminé pour l\'instant.',
                _TableauSegment.tous => 'Aucun chantier pour l\'instant.',
              };
    final canCreer = !isSearching && !_aTraiterOnly && _segment != _TableauSegment.termines;

    if (chantiers.isEmpty) {
      return BoPanel(
        child: EmptyState(
          icon: emptyIcon,
          message: emptyMessage,
          actionLabel: canCreer ? 'Créer un nouveau chantier' : null,
          onAction: canCreer ? () => context.push('/backoffice/ct/chantiers/nouveau') : null,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _cardBreakpoint) {
          return Column(
            children: [for (final c in chantiers) _buildCompactCard(context, c)],
          );
        }
        return BoResponsiveTable(
          minWidth: 600,
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
                for (final (i, c) in chantiers.indexed) _dataRow(context, c, i),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _headerRow() {
    const style = TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.acier, letterSpacing: 0.5);
    return Container(
      color: const Color(0xFFEDF0F2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('AFFAIRE (RÉF. ERP)', style: style)),
          Expanded(flex: 3, child: Text('CLIENT', style: style)),
          Expanded(flex: 2, child: Text('POSE', style: style)),
          Expanded(flex: 4, child: Text('LIVRET', style: style)),
          Expanded(flex: 4, child: Text('PV', style: style)),
        ],
      ),
    );
  }

  Widget _dataRow(BuildContext context, Chantier c, int index) {
    final livret = _livretBadge(c);
    final pv = _pvBadge(c);
    return BoTableRow(
      onTap: () => context.push('/backoffice/ct/chantiers/${c.reference}'),
      border: const Border(top: BorderSide(color: AppColors.lignes)),
      backgroundColor: index.isOdd ? const Color(0xFFF7F8F9) : null,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(child: Text(c.reference, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                if (c.type == ChantierType.sav) ...[const SizedBox(width: 6), _savTag()],
              ],
            ),
          ),
          Expanded(flex: 3, child: Text(c.client, style: const TextStyle(fontSize: 13))),
          Expanded(flex: 2, child: Text(DateFormat('dd/MM').format(c.dateDebut), style: const TextStyle(fontSize: 13))),
          Expanded(flex: 4, child: StatusBadge(label: livret.$1, type: livret.$2)),
          Expanded(flex: 4, child: StatusBadge(label: pv.$1, type: pv.$2)),
        ],
      ),
    );
  }

  /// Équivalent de [_dataRow] pour les écrans étroits — même informations,
  /// empilées verticalement plutôt qu'en colonnes qui n'ont plus la place
  /// de respirer sous [_cardBreakpoint].
  Widget _buildCompactCard(BuildContext context, Chantier c) {
    final livret = _livretBadge(c);
    final pv = _pvBadge(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/backoffice/ct/chantiers/${c.reference}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${c.reference} — ${c.client}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.type == ChantierType.sav) ...[_savTag(), const SizedBox(width: 6)],
                const Icon(Icons.chevron_right, size: 18, color: AppColors.acierClair),
              ],
            ),
            const SizedBox(height: 4),
            Text('Pose du ${DateFormat('dd/MM').format(c.dateDebut)}', style: const TextStyle(fontSize: 12, color: AppColors.acier)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusBadge(label: livret.$1, type: livret.$2),
                StatusBadge(label: pv.$1, type: pv.$2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomalies(List<Chantier> chantiers) {
    final anomalies = <(Chantier, PointControle)>[];
    for (final c in chantiers) {
      for (final p in [...c.receptionMarchandises, ...c.autoControle]) {
        if (p.status == PointStatus.nonConforme) anomalies.add((c, p));
      }
    }

    return BoPanel(
      title: 'Anomalies signalées (${anomalies.length})',
      child: anomalies.isEmpty
          ? const Text('Aucune anomalie en cours.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(children: [for (final (c, p) in anomalies) _anomalieRow(c, p)]),
    );
  }

  Widget _anomalieRow(Chantier c, PointControle p) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.rouge, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.reference} · ${c.client} — ${p.libelle}${p.critique ? ' (sécurité)' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.acier, fontWeight: FontWeight.w600),
                ),
                if (p.validePar != null && p.valideAt != null)
                  Text(
                    'Signalé par ${p.validePar} · ${DateFormat('dd/MM HH:mm').format(p.valideAt!)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabilitations(BuildContext context) {
    final installateurs = context.watch<ComptesState>().installateurs;
    final rows = <(User, Habilitation)>[
      for (final u in installateurs)
        for (final h in u.habilitations) (u, h),
    ];

    return BoPanel(
      title: 'Habilitations (${rows.length})',
      child: rows.isEmpty
          ? const Text('Aucune habilitation enregistrée.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(children: [for (final (u, h) in rows) _habilitationRow(u, h)]),
    );
  }

  Widget _habilitationRow(User u, Habilitation h) {
    final (label, type) = h.isExpired
        ? ('Expirée', StatusType.nonConforme)
        : h.expiresSoon
            ? ('Expire bientôt', StatusType.enCours)
            : ('À jour', StatusType.conforme);

    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(u.fullName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${h.titre} · ${DateFormat('dd/MM/yyyy').format(h.dateExpiration)}',
              style: const TextStyle(fontSize: 12, color: AppColors.acier),
            ),
          ),
          StatusIndicator(label: label, type: type),
          if (h.filePath != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => launchUrl(Uri.parse(h.filePath!)),
              style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Voir', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
