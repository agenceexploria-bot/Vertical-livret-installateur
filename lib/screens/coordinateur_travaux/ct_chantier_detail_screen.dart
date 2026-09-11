import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/chantier_link.dart';
import '../../core/document_download.dart';
import '../../core/theme.dart';
import '../../core/widgets/ajouter_document_chantier_dialog.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/vertical_app_bar.dart';
import '../../core/widgets/renseigner_pv_dialog.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../data/models/document_chantier.dart';
import '../../data/models/user.dart';
import '../../state/chantier_state.dart';

/// Fiche chantier mobile pour le CT — consultation de l'avancement, des
/// installateurs rattachés et dépôt de documents de référence (Modules 1 à 3),
/// avec accès à la modification (voir [CtEditChantierScreen] atteint via
/// l'icône crayon). Version réduite de BoChantierDetailScreen (Web).
class CtChantierDetailScreen extends StatelessWidget {
  const CtChantierDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = GoRouterState.of(context).pathParameters['ref'] ?? '—';
    final chantier = context.watch<ChantierState>().findByReference(ref);

    if (chantier == null) {
      return ResponsiveLayout(
        appBar: VerticalAppBar(title: const Text('Chantier'), backgroundColor: AppColors.encre, foregroundColor: Colors.white),
        child: const Center(child: Text('Chantier introuvable')),
      );
    }

    final (livretLabel, livretType) = _livretStatus(chantier);
    final (pvLabel, pvType) = chantier.pvSigne
        ? ('Signé le ${DateFormat('dd/MM/yyyy').format(chantier.pvSigneAt ?? chantier.dateFin)}', StatusType.conforme)
        : chantier.pvEnAttenteSignature
            ? ('En attente de signature', StatusType.enCours)
            : ('Non déposé', StatusType.attente);

    return ResponsiveLayout(
      appBar: VerticalAppBar(
        title: Text(chantier.reference),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _copierLien(context, chantier),
            icon: const Icon(Icons.link),
            tooltip: 'Copier le lien de ce chantier',
          ),
          IconButton(
            onPressed: () => context.push('/ct/chantier/${chantier.reference}/modifier'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier ce chantier',
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chantier.client, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${chantier.adresse}, ${chantier.ville}', style: const TextStyle(color: AppColors.acier, fontSize: 13)),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _kv('Pose', '${DateFormat('dd/MM').format(chantier.dateDebut)} au ${DateFormat('dd/MM').format(chantier.dateFin)} · ${chantier.horaires}'),
                _kv(
                  'Contact',
                  chantier.contactEmail != null
                      ? '${chantier.contactNom} · ${chantier.contactTel} · ${chantier.contactEmail}'
                      : '${chantier.contactNom} · ${chantier.contactTel}',
                ),
                _kv('Matériel', '${chantier.typeMonteCharge} · ${chantier.capacite} · ${chantier.niveaux} niveau(x)'),
                _kv('Réf. affaire ERP', chantier.referenceAffaire),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Module SAV — une intervention SAV n'a jamais de réception/auto-
          // contrôle (aucun point de contrôle créé côté backend, voir POST
          // .../sav) : afficher "0% avancement auto-contrôle" y serait
          // dénué de sens. Résumé dédié à la place, comme sur la fiche
          // back-office Web (voir bo_chantier_detail_screen.dart, _buildSavPanel).
          if (chantier.type == ChantierType.sav) _buildSavCard(context, chantier) else _buildLivretCard(livretLabel, livretType, chantier),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PV de réception', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _pvDownloadButton(chantier),
                        StatusIndicator(label: pvLabel, type: pvType),
                      ],
                    ),
                  ],
                ),
                if (!chantier.pvSigne) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (dialogContext) => RenseignerPvDialog(chantier: chantier),
                      ),
                      child: Text(chantier.pvEnAttenteSignature ? 'Remplacer le PV' : 'Déposer le PV'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDocuments(context, chantier),
          const SizedBox(height: 16),
          Text('Installateurs rattachés (${chantier.installateursRattaches.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (chantier.installateursRattaches.isEmpty)
            const Text('Aucun installateur rattaché.', style: TextStyle(color: AppColors.acierClair, fontSize: 12))
          else
            for (final u in chantier.installateursRattaches) ...[
              _installateurCard(context, chantier, u),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  /// Téléchargement du PV signé — jusqu'ici absent de la fiche mobile CT
  /// (seul un badge de statut "Signé" y figurait, sans aucun moyen d'accéder
  /// au PDF) alors que la fiche back-office Web l'a toujours proposé (voir
  /// PvSignaturePanel). `forceDownloadUri` force Content-Disposition:
  /// attachment côté Vercel Blob, comme sur le Web.
  Widget _pvDownloadButton(Chantier chantier) {
    final url = pvSignatureDownloadUrl(chantier);
    if (url == null) return const SizedBox.shrink();
    return IconButton(
      onPressed: () => launchUrl(forceDownloadUri(url), mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.download_outlined, size: 20, color: AppColors.acier),
      tooltip: 'Télécharger le PV (PDF)',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _buildLivretCard(String livretLabel, StatusType livretType, Chantier chantier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Livret installateur', style: TextStyle(fontWeight: FontWeight.bold)),
              StatusIndicator(label: livretLabel, type: livretType),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: chantier.progressionAutoControle, color: AppColors.orange, backgroundColor: AppColors.lignes),
          const SizedBox(height: 6),
          Text(
            '${(chantier.progressionAutoControle * 100).toInt()}% avancement auto-contrôle',
            style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
          ),
        ],
      ),
    );
  }

  /// Module SAV — équivalent mobile de _buildSavPanel (back-office Web) :
  /// chantier d'origine, date d'intervention, PV et REX plutôt qu'un
  /// avancement auto-contrôle sans objet pour une intervention SAV.
  Widget _buildSavCard(BuildContext context, Chantier chantier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_outlined, size: 16, color: AppColors.orange),
              const SizedBox(width: 6),
              const Text('Intervention SAV', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange)),
            ],
          ),
          const SizedBox(height: 10),
          _kv('Chantier terminé', chantier.parentReference ?? '—'),
          _kv('Date d\'intervention', chantier.savDate != null ? DateFormat('dd/MM/yyyy').format(chantier.savDate!) : '—'),
          if (chantier.descriptionIntervention != null) _kv('Problème signalé', chantier.descriptionIntervention!),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('PV', style: TextStyle(fontSize: 11.5, color: AppColors.acierClair)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pvDownloadButton(chantier),
                  StatusIndicator(
                    label: chantier.pvSigne ? 'Signé' : '—',
                    type: chantier.pvSigne ? StatusType.conforme : StatusType.attente,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocuments(BuildContext context, Chantier chantier) {
    final docs = chantier.documentsChantier;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Documents chantier (Modules 1-3)', style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (dialogContext) => AjouterDocumentChantierDialog(reference: chantier.reference),
                ),
                icon: const Icon(Icons.add_circle_outline, color: AppColors.orange),
                tooltip: 'Ajouter un document',
              ),
            ],
          ),
          if (docs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Aucun document déposé pour l\'instant.', style: TextStyle(color: AppColors.acierClair, fontSize: 12)),
            )
          else
            for (final d in docs) ...[
              const SizedBox(height: 8),
              _documentRow(context, chantier, d),
            ],
        ],
      ),
    );
  }

  Widget _documentRow(BuildContext context, Chantier chantier, DocumentChantier d) {
    final icon = switch (d.type) {
      TypeDocumentChantier.securite => Icons.shield_outlined,
      TypeDocumentChantier.ficheChantier => Icons.assignment_outlined,
      TypeDocumentChantier.technique => Icons.description_outlined,
    };
    return InkWell(
      onTap: () => launchUrl(Uri.parse(d.filePath)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.acier),
          const SizedBox(width: 8),
          Expanded(child: Text(d.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          IconButton(
            onPressed: () => _confirmerSuppressionDocument(context, chantier, d),
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.acierClair),
            tooltip: 'Supprimer',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
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

  (String, StatusType) _livretStatus(Chantier chantier) {
    final ok = chantier.installateursRattaches.isNotEmpty &&
        chantier.installateursRattaches.every((u) => chantier.livretsOuverts.contains(u.id));
    return ok ? ('Ouvert', StatusType.conforme) : ('Non ouvert', StatusType.nonConforme);
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.acierClair))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _installateurCard(BuildContext context, Chantier chantier, User u) {
    final ouvert = chantier.livretsOuverts.contains(u.id);
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.acier,
            child: Text(
              '${u.prenom.isNotEmpty ? u.prenom[0] : ''}${u.nom.isNotEmpty ? u.nom[0] : ''}',
              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                StatusIndicator(
                  label: ouvert ? 'Livret ouvert' : 'Livret non ouvert',
                  type: ouvert ? StatusType.conforme : StatusType.nonConforme,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _appeler(context, u),
            icon: const Icon(Icons.phone_outlined, color: AppColors.acier),
            tooltip: 'Appeler ${u.fullName}',
          ),
        ],
      ),
    );
  }

  /// Lien direct vers la fiche installateur de ce chantier (route
  /// /chantier/:ref, voir router.dart) — copié dans le presse-papier pour
  /// être transmis par WhatsApp/SMS. Contrairement à la version Web du
  /// back-office (toujours servie depuis une vraie page, voir
  /// bo_chantier_detail_screen.dart), cet écran tourne aussi en natif
  /// mobile — Uri.base n'y reflète aucune origine web utilisable, d'où le
  /// repli sur le domaine de production (déjà en dur côté backend, voir
  /// PROD_ORIGIN dans backend/src/app.ts).
  Future<void> _copierLien(BuildContext context, Chantier chantier) async {
    final origin = kIsWeb ? Uri.base.origin : 'https://vertical-livret-installateur.vercel.app';
    final url = chantierLinkUrl(origin: origin, reference: chantier.reference);
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien copié — transmettez-le à l\'installateur.')),
    );
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

  Future<void> _appeler(BuildContext context, User u) async {
    if (u.mobile == null || u.mobile!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun numéro de mobile enregistré pour ${u.fullName}.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: u.mobile);
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lancer l\'appel sur cet appareil.')),
      );
    }
  }
}

/// URL du PDF du PV signé à proposer au téléchargement, ou `null` si aucun
/// bouton ne doit être affiché (PV non signé, ou fichier non-PDF —
/// signature au doigt seul, ancien flux, voir PvSignaturePanel). Fonction
/// pure extraite pour être testable sans monter tout l'écran
/// (Provider/GoRouter) — voir ct_chantier_detail_screen_test.dart.
String? pvSignatureDownloadUrl(Chantier chantier) {
  final path = chantier.pvSignatureImagePath;
  if (!chantier.pvSigne || path == null || !path.toLowerCase().endsWith('.pdf')) return null;
  return path;
}
