import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/document_capture.dart';
import '../../core/document_download.dart';
import '../../core/theme.dart';
import '../../core/widgets/ajouter_document_chantier_dialog.dart';
import '../../core/widgets/renseigner_pv_dialog.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../data/models/document_chantier.dart';
import '../../data/models/document_terrain.dart';
import '../../data/models/point_controle.dart';
import '../../data/models/user.dart';
import '../../state/auth_state.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_back_button.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';
import 'widgets/bo_table_row.dart';
import 'widgets/pv_signature_panel.dart';

class BoChantierDetailScreen extends StatefulWidget {
  const BoChantierDetailScreen({super.key});

  @override
  State<BoChantierDetailScreen> createState() => _BoChantierDetailScreenState();
}

/// Fiche chantier regroupée en onglets (Vue d'ensemble / Documents / Qualité
/// / PV) plutôt qu'un long empilement vertical de sections — un
/// [TabController] gère l'onglet actif ; le contenu de chaque onglet est
/// construit à la demande (pas de [TabBarView], qui exige une hauteur bornée
/// incompatible avec le [SingleChildScrollView] de [BoShell]).
class _BoChantierDetailScreenState extends State<BoChantierDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this)..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Affiche un message clair en cas d'échec d'une action serveur — sans ça,
  /// un clic qui échoue (droits insuffisants, réseau...) ne montrait
  /// strictement rien à l'utilisateur (exception non attendue, silencieuse).
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
    final ref = GoRouterState.of(context).pathParameters['ref'] ?? '—';
    final chantier = context.watch<ChantierState>().findByReference(ref);

    if (chantier == null) {
      return const BoShell(activeNav: 'chantiers', child: Text('Chantier introuvable'));
    }

    final livretOk = chantier.installateursRattaches.isNotEmpty &&
        chantier.installateursRattaches.every((u) => chantier.livretsOuverts.contains(u.id));
    // Modifier un chantier est ouvert au CA et à l'Admin ; la suppression
    // reste réservée à l'Admin (capacité destructive supplémentaire).
    final role = context.watch<AuthState>().currentUser?.role;
    final isAdmin = role == UserRole.admin;
    final canModifier = isAdmin || role == UserRole.chargeAffaires || role == UserRole.direction;
    final canRenseignerPv = role == UserRole.admin || role == UserRole.chargeAffaires || role == UserRole.direction;
    // Suppression réservée au CA/Admin, comme côté backend (DELETE .../pv) —
    // Direction peut renseigner le PV mais pas le supprimer.
    final canSupprimerPv = role == UserRole.admin || role == UserRole.chargeAffaires;

    return BoShell(
      activeNav: 'chantiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BoBackButton(),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('${chantier.reference} — ${chantier.client}, ${chantier.ville}', style: Theme.of(context).textTheme.titleMedium),
              StatusBadge(
                label: livretOk ? 'Prêt' : 'En attente',
                type: livretOk ? StatusType.conforme : StatusType.enCours,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              if (canModifier) ...[
                OutlinedButton.icon(
                  onPressed: () => _openModifierDialog(context, chantier),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
                ),
                const SizedBox(width: 10),
              ],
              if (isAdmin)
                OutlinedButton.icon(
                  onPressed: () => _confirmerSuppression(context, chantier),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Supprimer'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    foregroundColor: AppColors.rouge,
                    side: const BorderSide(color: AppColors.rouge),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: AppColors.blanc,
              border: Border.all(color: AppColors.lignes),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.orange,
              unselectedLabelColor: AppColors.acier,
              indicatorColor: AppColors.orange,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Vue d\'ensemble'),
                Tab(text: 'Documents'),
                Tab(text: 'Qualité'),
                Tab(text: 'PV'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          switch (_tabController.index) {
            0 => _buildVueEnsembleTab(context, chantier),
            1 => _buildDocumentsTab(context, chantier),
            2 => _buildQualiteTab(context, chantier, role),
            _ => _buildPvTab(context, chantier, canRenseignerPv: canRenseignerPv, canSupprimerPv: canSupprimerPv),
          },
        ],
      ),
    );
  }

  Widget _buildVueEnsembleTab(BuildContext context, Chantier chantier) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final left = Column(children: [_buildInstallateursPanel(context, chantier), _buildFiletSecoursPanel()]);
        final right = _buildAvancementPanel(chantier);
        if (!isWide) return Column(children: [left, const SizedBox(height: 4), right]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 24),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildDocumentsTab(BuildContext context, Chantier chantier) {
    return Column(
      children: [
        BoPanel(
          title: 'Documents chantier — Modules 1 à 3',
          child: _buildDocumentsChantier(context, chantier),
        ),
        BoPanel(
          title: 'Documents terrain déposés par les installateurs (Module 8)',
          child: _buildDocsTerrain(context, chantier),
        ),
      ],
    );
  }

  Widget _buildQualiteTab(BuildContext context, Chantier chantier, UserRole? role) {
    return Column(
      children: [
        _buildAutoControle(chantier),
        _buildRex(context, chantier, role),
      ],
    );
  }

  Widget _buildPvTab(BuildContext context, Chantier chantier, {required bool canRenseignerPv, required bool canSupprimerPv}) {
    return BoPanel(
      title: 'Procès-verbal de réception',
      child: _buildPvPanel(context, chantier, canRenseignerPv: canRenseignerPv, canSupprimerPv: canSupprimerPv),
    );
  }

  Widget _buildAutoControle(Chantier chantier) {
    final total = chantier.autoControle.length;
    final done = chantier.autoControle.where((p) => p.isComplete).length;
    return BoPanel(
      title: 'Auto-contrôle & qualité (${(chantier.progressionAutoControle * 100).toInt()}%)',
      child: chantier.autoControle.isEmpty
          ? const Text('Aucun point d\'auto-contrôle pour ce chantier.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      StatusBadge(
                        label: '$done/$total conforme(s)',
                        type: done == total ? StatusType.conforme : done > 0 ? StatusType.enCours : StatusType.attente,
                      ),
                    ],
                  ),
                ),
                for (final p in chantier.autoControle) _autoControlePointRow(p),
              ],
            ),
    );
  }

  Widget _autoControlePointRow(PointControle p) {
    final (label, type) = switch (p.status) {
      PointStatus.conforme => ('Conforme', StatusType.conforme),
      PointStatus.nonConforme => ('Non conforme', StatusType.nonConforme),
      PointStatus.vide => ('À faire', StatusType.attente),
    };
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${p.libelle}${p.critique ? ' (sécurité)' : ''}',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          StatusIndicator(label: label, type: type),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              p.validePar != null && p.valideAt != null
                  ? '${p.validePar} · ${DateFormat('dd/MM HH:mm').format(p.valideAt!)}'
                  : '—',
              style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRex(BuildContext context, Chantier chantier, UserRole? role) {
    final peutSupprimer = role == UserRole.chargeAffaires || role == UserRole.admin;
    return BoPanel(
      title: 'Retour d\'expérience (REX)',
      child: !chantier.rexValide
          ? const Text('Aucun REX soumis pour l\'instant.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    chantier.rexTranscription ?? '(note vocale sans transcription)',
                    style: const TextStyle(fontSize: 13, color: AppColors.acier),
                  ),
                ),
                if (peutSupprimer) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.acierClair),
                    tooltip: 'Supprimer ce REX',
                    onPressed: () => _confirmerSuppressionRex(context, chantier),
                  ),
                ],
              ],
            ),
    );
  }

  // Seule façon de débloquer l'installateur pour qu'il puisse soumettre un
  // nouveau REX — voir le contrôle rexValide côté backend (POST .../rex).
  void _confirmerSuppressionRex(BuildContext context, Chantier chantier) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce REX ?'),
        content: Text(
          'Le REX du chantier ${chantier.reference} sera supprimé définitivement, y compris la note vocale. L\'installateur pourra ensuite en soumettre un nouveau. Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleAction(context, () => context.read<ChantierState>().deleteRex(chantier.reference));
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  void _confirmerSuppressionPv(BuildContext context, Chantier chantier) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce PV ?'),
        content: Text(
          'Le PV du chantier ${chantier.reference} sera supprimé définitivement, y compris la signature/le PDF associé. Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleAction(context, () => context.read<ChantierState>().deletePv(chantier.reference));
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallateursPanel(BuildContext context, Chantier chantier) {
    return BoPanel(
      title: 'Installateurs rattachés',
      child: Column(
        children: [
          if (chantier.installateursRattaches.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('Aucun installateur rattaché pour l\'instant.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair)),
            ),
          for (final u in chantier.installateursRattaches) _installateurRow(context, chantier, u),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => _openRattacherDialog(context, chantier),
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('Rattacher un installateur'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildFiletSecoursPanel() {
    return const BoPanel(
      title: 'Filet de secours',
      child: Text(
        'PDF récapitulatif (fiche + consignes) envoyé automatiquement à chaque rattachement — lisible sans app ni compte.',
        style: TextStyle(fontSize: 12, color: AppColors.acier),
      ),
    );
  }

  Widget _buildAvancementPanel(Chantier chantier) {
    return BoPanel(
      title: 'Avancement des 8 modules',
      child: Column(
        children: [
          BoKv(
            label: '1-3 · Consultation',
            value: chantier.documentsChantier.isEmpty
                ? const Text('—', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
                : StatusIndicator(label: '${chantier.documentsChantier.length} document(s)', type: StatusType.conforme),
          ),
          BoKv(
            label: '4 · Réception',
            value: StatusIndicator(
              label: '${(chantier.progressionReception * 100).toInt()}%',
              type: chantier.progressionReception == 0
                  ? StatusType.attente
                  : chantier.progressionReception == 1
                      ? StatusType.conforme
                      : StatusType.enCours,
            ),
          ),
          BoKv(
            label: '5 · Auto-contrôle',
            value: StatusIndicator(
              label: '${(chantier.progressionAutoControle * 100).toInt()}%',
              type: chantier.progressionAutoControle == 0
                  ? StatusType.attente
                  : chantier.progressionAutoControle == 1
                      ? StatusType.conforme
                      : StatusType.enCours,
            ),
          ),
          BoKv(
            label: '6 · PV',
            value: chantier.pvSigne
                ? const StatusIndicator(label: 'Signé', type: StatusType.conforme)
                : const Text('—', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair)),
          ),
          BoKv(
            label: '7 · REX',
            value: chantier.rexValide
                ? const StatusIndicator(label: 'Envoyé', type: StatusType.conforme)
                : const Text('—', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair)),
          ),
          BoKv(
            label: '8 · Docs terrain',
            value: chantier.docsTerrain.isEmpty
                ? const Text('—', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair))
                : StatusIndicator(label: '${chantier.docsTerrain.length} déposé(s)', type: StatusType.enCours),
          ),
        ],
      ),
    );
  }

  void _openRenseignerPvDialog(BuildContext context, Chantier chantier) {
    showDialog(
      context: context,
      builder: (dialogContext) => RenseignerPvDialog(chantier: chantier),
    );
  }

  /// Trois états : validé (signé par le client), en attente de signature
  /// (gabarit déposé mais pas encore signé), ou aucun PV déposé.
  Widget _buildPvPanel(BuildContext context, Chantier chantier, {required bool canRenseignerPv, required bool canSupprimerPv}) {
    if (chantier.pvSigne) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PvSignaturePanel(
            signataire: chantier.pvSigneur,
            fonction: chantier.pvFonctionSignataire,
            signeAt: chantier.pvSigneAt,
            signatureImagePath: chantier.pvSignatureImagePath,
          ),
          if (canSupprimerPv) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _confirmerSuppressionPv(context, chantier),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Supprimer le PV'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                foregroundColor: AppColors.rouge,
                side: const BorderSide(color: AppColors.rouge),
              ),
            ),
          ],
        ],
      );
    }

    if (chantier.pvEnAttenteSignature) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'En attente de signature par le client — l\'installateur consulte le PDF déposé et le fait signer sur place.',
            style: TextStyle(fontSize: 12.5, color: AppColors.acier),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(chantier.pvPdfPath!), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Ouvrir le PV déposé'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
          ),
          if (canRenseignerPv || canSupprimerPv) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (canRenseignerPv)
                  OutlinedButton.icon(
                    onPressed: () => _openRenseignerPvDialog(context, chantier),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Remplacer le PV'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
                  ),
                if (canRenseignerPv && canSupprimerPv) const SizedBox(width: 10),
                if (canSupprimerPv)
                  OutlinedButton.icon(
                    onPressed: () => _confirmerSuppressionPv(context, chantier),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Annuler'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      foregroundColor: AppColors.rouge,
                      side: const BorderSide(color: AppColors.rouge),
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    }

    if (canRenseignerPv) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Déposez le PDF du PV — l\'installateur le fera signer par le client sur place.',
            style: TextStyle(fontSize: 12.5, color: AppColors.acier),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openRenseignerPvDialog(context, chantier),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Déposer le PV'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
          ),
        ],
      );
    }

    return const Text('En attente du back-office.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair));
  }

  static const _modulesDocuments = [
    (TypeDocumentChantier.ficheChantier, 'Module 1 - Fiche chantier'),
    (TypeDocumentChantier.securite, 'Module 2 - Sécurité'),
    (TypeDocumentChantier.technique, 'Module 3 - Technique'),
  ];

  Widget _buildDocumentsChantier(BuildContext context, Chantier chantier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (type, label) in _modulesDocuments) ...[
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.acier)),
          const SizedBox(height: 6),
          () {
            final docs = chantier.documentsChantier.where((d) => d.type == type).toList();
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text('Aucun document.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair)),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(children: [for (final d in docs) _documentChantierRow(context, chantier, d)]),
            );
          }(),
        ],
        ElevatedButton.icon(
          onPressed: () => _openAjouterDocumentDialog(context, chantier),
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text('Ajouter un document'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
        ),
      ],
    );
  }

  Widget _buildDocsTerrain(BuildContext context, Chantier chantier) {
    if (chantier.docsTerrain.isEmpty) {
      return const Text('Aucun document terrain déposé pour l\'instant.', style: TextStyle(fontSize: 12.5, color: AppColors.acierClair));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final d in chantier.docsTerrain.reversed) _docTerrainRow(context, d)],
    );
  }

  /// Aperçu : ouvre le document dans un nouvel onglet du navigateur (rendu
  /// natif — PDF/image affichés directement), sans forcer de téléchargement.
  Future<void> _ouvrirDocument(BuildContext context, String filePath) async {
    final ok = await launchUrl(Uri.parse(filePath), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir ce document.')),
      );
    }
  }

  Future<void> _telechargerDocument(BuildContext context, String filePath) async {
    final ok = await launchUrl(forceDownloadUri(filePath), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de télécharger ce document.')),
      );
    }
  }

  Widget _docTerrainRow(BuildContext context, DocumentTerrain d) {
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      onTap: d.filePath == null ? null : () => _ouvrirDocument(context, d.filePath!),
      child: Row(
        children: [
          Icon(d.filePath != null ? Icons.description_outlined : Icons.image_outlined, size: 18, color: AppColors.acierClair),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.titre, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(
                  '${d.categorieLabel} · ${DateFormat('dd/MM HH:mm').format(d.horodatage)} · ${d.auteur}',
                  style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
                ),
              ],
            ),
          ),
          if (d.filePath != null)
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.acierClair),
              tooltip: 'Télécharger',
              onPressed: () => _telechargerDocument(context, d.filePath!),
            ),
        ],
      ),
    );
  }

  Widget _documentChantierRow(BuildContext context, Chantier chantier, DocumentChantier d) {
    final icon = switch (d.type) {
      TypeDocumentChantier.securite => Icons.shield_outlined,
      TypeDocumentChantier.ficheChantier => Icons.assignment_outlined,
      TypeDocumentChantier.technique => Icons.description_outlined,
    };
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      onTap: () => _ouvrirDocument(context, d.filePath),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.acierClair),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.nom, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      if (d.nomFichierOriginal != null && d.nomFichierOriginal != d.nom)
                        Text(
                          d.nomFichierOriginal!,
                          style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.acierClair),
            tooltip: 'Télécharger',
            onPressed: () => _telechargerDocument(context, d.filePath),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.acierClair),
            onSelected: (value) => _onDocumentChantierAction(context, chantier, d, value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'remplacer', child: Text('Remplacer le fichier')),
              PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    );
  }

  void _onDocumentChantierAction(BuildContext context, Chantier chantier, DocumentChantier d, String value) {
    switch (value) {
      case 'remplacer':
        _remplacerFichier(context, chantier, d);
        break;
      case 'supprimer':
        _confirmerSuppressionDocument(context, chantier, d);
        break;
    }
  }

  Future<void> _remplacerFichier(BuildContext context, Chantier chantier, DocumentChantier d) async {
    final picked = await DocumentCapture.pickFile();
    if (picked == null || !context.mounted) return;
    try {
      await context.read<ChantierState>().replaceDocumentChantier(
            chantier.reference,
            d.id,
            file: picked.dataUrl,
            nomFichierOriginal: picked.fileName,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fichier de « ${d.nom} » remplacé.')),
        );
      }
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Une erreur est survenue. Réessayez.')));
    }
  }

  void _confirmerSuppressionDocument(BuildContext context, Chantier chantier, DocumentChantier d) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text('« ${d.nom} » sera supprimé définitivement, y compris le fichier stocké. Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleAction(context, () => context.read<ChantierState>().deleteDocumentChantier(chantier.reference, d.id));
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  void _openAjouterDocumentDialog(BuildContext context, Chantier chantier) {
    showDialog(
      context: context,
      builder: (dialogContext) => AjouterDocumentChantierDialog(reference: chantier.reference),
    );
  }

  Widget _installateurRow(BuildContext context, Chantier chantier, User u) {
    final ouvert = chantier.livretsOuverts.contains(u.id);
    final initials = '${u.prenom.isNotEmpty ? u.prenom[0] : ''}${u.nom.isNotEmpty ? u.nom[0] : ''}';
    return BoTableRow(
      padding: const EdgeInsets.symmetric(vertical: 9),
      border: const Border(bottom: BorderSide(color: Color(0xFFEEF1F3))),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: AppColors.acier, child: Text(initials, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Text('${u.fullName} (${u.status == UserStatus.sousTraitant ? 'sous-traitant' : 'salarié'})', style: const TextStyle(fontSize: 12.5))),
          StatusIndicator(
            label: ouvert ? 'Prêt hors-ligne' : 'Livret non ouvert',
            type: ouvert ? StatusType.conforme : StatusType.nonConforme,
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _confirmerDetachement(context, chantier, u),
            icon: const Icon(Icons.link_off, size: 16, color: AppColors.acierClair),
            tooltip: 'Détacher ${u.fullName} de ce chantier',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _confirmerDetachement(BuildContext context, Chantier chantier, User u) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Détacher cet installateur ?'),
        content: Text('${u.fullName} ne sera plus rattaché au chantier ${chantier.reference}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleAction(context, () => context.read<ChantierState>().detacher(chantier.reference, u.id));
            },
            child: const Text('Détacher'),
          ),
        ],
      ),
    );
  }

  void _openRattacherDialog(BuildContext context, Chantier chantier) {
    final comptesState = context.read<ComptesState>();
    final disponibles = comptesState.installateurs
        .where((u) => u.isActive && !u.suspendu && !chantier.installateursRattaches.any((r) => r.id == u.id))
        .toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rattacher un installateur'),
        content: SizedBox(
          width: 320,
          child: disponibles.isEmpty
              ? const Text('Aucun compte validé disponible.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: disponibles.map((u) => ListTile(
                        title: Text(u.fullName),
                        subtitle: Text(u.societe ?? (u.status == UserStatus.sousTraitant ? 'Sous-traitant' : 'Salarié')),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _handleAction(context, () => context.read<ChantierState>().rattacher(chantier.reference, u.id));
                        },
                      )).toList(),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _openModifierDialog(BuildContext context, Chantier chantier) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ModifierChantierDialog(chantier: chantier),
    );
  }

  void _confirmerSuppression(BuildContext context, Chantier chantier) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce chantier ?'),
        content: Text(
          'Le chantier ${chantier.reference} (${chantier.client}) sera supprimé définitivement, avec tous ses points de contrôle, documents et rattachements. Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rouge),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await context.read<ChantierState>().deleteChantier(chantier.reference);
                if (context.mounted) context.go('/backoffice/ca');
              } on ApiException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Une erreur est survenue. Réessayez.')),
                );
              }
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }
}

/// Modification des informations d'un chantier — réservée à l'Admin (voir la
/// refonte des rôles back-office). Couvre les champs descriptifs principaux ;
/// les dates et consignes ne sont pas éditables ici pour l'instant.
class _ModifierChantierDialog extends StatefulWidget {
  final Chantier chantier;
  const _ModifierChantierDialog({required this.chantier});

  @override
  State<_ModifierChantierDialog> createState() => _ModifierChantierDialogState();
}

class _ModifierChantierDialogState extends State<_ModifierChantierDialog> {
  late final _clientController = TextEditingController(text: widget.chantier.client);
  late final _adresseController = TextEditingController(text: widget.chantier.adresse);
  late final _villeController = TextEditingController(text: widget.chantier.ville);
  late final _contactNomController = TextEditingController(text: widget.chantier.contactNom);
  late final _contactTelController = TextEditingController(text: widget.chantier.contactTel);
  late final _horairesController = TextEditingController(text: widget.chantier.horaires);
  late final _typeMonteChargeController = TextEditingController(text: widget.chantier.typeMonteCharge);
  late final _capaciteController = TextEditingController(text: widget.chantier.capacite);
  late final _referenceAffaireController = TextEditingController(text: widget.chantier.referenceAffaire);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _clientController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _contactNomController.dispose();
    _contactTelController.dispose();
    _horairesController.dispose();
    _typeMonteChargeController.dispose();
    _capaciteController.dispose();
    _referenceAffaireController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    setState(() => _isSubmitting = true);
    try {
      await context.read<ChantierState>().updateChantier(widget.chantier.reference, {
        'client': _clientController.text.trim(),
        'adresse': _adresseController.text.trim(),
        'ville': _villeController.text.trim(),
        'contactNom': _contactNomController.text.trim(),
        'contactTel': _contactTelController.text.trim(),
        'horaires': _horairesController.text.trim(),
        'typeMonteCharge': _typeMonteChargeController.text.trim(),
        'capacite': _capaciteController.text.trim(),
        'referenceAffaire': _referenceAffaireController.text.trim(),
      });
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Une erreur est survenue. Réessayez.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modifier ${widget.chantier.reference}'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _clientController, decoration: const InputDecoration(labelText: 'Client')),
              const SizedBox(height: 10),
              TextField(controller: _adresseController, decoration: const InputDecoration(labelText: 'Adresse')),
              const SizedBox(height: 10),
              TextField(controller: _villeController, decoration: const InputDecoration(labelText: 'Ville')),
              const SizedBox(height: 10),
              TextField(controller: _contactNomController, decoration: const InputDecoration(labelText: 'Contact — nom')),
              const SizedBox(height: 10),
              TextField(controller: _contactTelController, decoration: const InputDecoration(labelText: 'Contact — téléphone')),
              const SizedBox(height: 10),
              TextField(controller: _horairesController, decoration: const InputDecoration(labelText: 'Horaires')),
              const SizedBox(height: 10),
              TextField(controller: _typeMonteChargeController, decoration: const InputDecoration(labelText: 'Type de monte-charge')),
              const SizedBox(height: 10),
              TextField(controller: _capaciteController, decoration: const InputDecoration(labelText: 'Capacité')),
              const SizedBox(height: 10),
              TextField(controller: _referenceAffaireController, decoration: const InputDecoration(labelText: 'Référence affaire (ERP)')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _enregistrer,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
