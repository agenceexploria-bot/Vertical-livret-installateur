import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/coming_soon.dart';
import '../../core/document_capture.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_indicator.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../data/models/document_chantier.dart';
import '../../data/models/document_terrain.dart';
import '../../data/models/user.dart';
import '../../state/chantier_state.dart';
import '../../state/comptes_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';
import 'widgets/pv_signature_panel.dart';

class BoChantierDetailScreen extends StatelessWidget {
  const BoChantierDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = GoRouterState.of(context).pathParameters['ref'] ?? '—';
    final chantier = context.watch<ChantierState>().findByReference(ref);

    if (chantier == null) {
      return const BoShell(activeNav: 'chantiers', child: Text('Chantier introuvable'));
    }

    final livretOk = chantier.installateursRattaches.isNotEmpty &&
        chantier.installateursRattaches.every((u) => chantier.livretsOuverts.contains(u.id));

    return BoShell(
      activeNav: 'chantiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${chantier.reference} — ${chantier.client}, ${chantier.ville}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 10),
              StatusIndicator(
                label: livretOk ? 'Prêt' : 'En attente',
                type: livretOk ? StatusType.conforme : StatusType.enCours,
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => showComingSoon(context),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: const Text('Modifier', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final left = _buildLeftColumn(context, chantier);
              final right = _buildRightColumn(chantier);
              if (!isWide) return Column(children: [left, const SizedBox(height: 12), right]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 20),
                  Expanded(child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(BuildContext context, Chantier chantier) {
    return Column(
      children: [
        BoPanel(
          title: 'Installateurs rattachés',
          child: Column(
            children: [
              if (chantier.installateursRattaches.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Aucun installateur rattaché pour l\'instant.', style: TextStyle(fontSize: 11, color: AppColors.acierClair)),
                ),
              for (final u in chantier.installateursRattaches) _installateurRow(context, chantier, u),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _openRattacherDialog(context, chantier),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    child: const Text('+ Rattacher', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SMS de relance envoyé')),
                    ),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    child: const Text('Relancer par SMS', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const BoPanel(
          title: 'Filet de secours',
          child: Text(
            'PDF récapitulatif (fiche + consignes) envoyé automatiquement à chaque rattachement — lisible sans app ni compte.',
            style: TextStyle(fontSize: 10.5, color: AppColors.acier),
          ),
        ),
        BoPanel(
          title: 'Documents chantier (PPSPS, plans, notices...)',
          child: _buildDocumentsChantier(context, chantier),
        ),
        BoPanel(
          title: 'Documents terrain déposés par les installateurs (Module 8)',
          child: _buildDocsTerrain(chantier),
        ),
        if (chantier.pvSigne)
          BoPanel(
            title: 'Validation du PV',
            child: PvSignaturePanel(
              signataire: chantier.pvSigneur,
              signeAt: chantier.pvSigneAt,
              signatureImagePath: chantier.pvSignatureImagePath,
            ),
          ),
      ],
    );
  }

  Widget _buildDocumentsChantier(BuildContext context, Chantier chantier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chantier.documentsChantier.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Aucun document déposé pour l\'instant.', style: TextStyle(fontSize: 11, color: AppColors.acierClair)),
          ),
        for (final d in chantier.documentsChantier) _documentChantierRow(d),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _openAjouterDocumentDialog(context, chantier),
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14)),
          child: const Text('+ Ajouter un document', style: TextStyle(fontSize: 11.5)),
        ),
      ],
    );
  }

  Widget _buildDocsTerrain(Chantier chantier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chantier.docsTerrain.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Aucun document terrain déposé pour l\'instant.', style: TextStyle(fontSize: 11, color: AppColors.acierClair)),
          ),
        for (final d in chantier.docsTerrain.reversed) _docTerrainRow(d),
      ],
    );
  }

  Widget _docTerrainRow(DocumentTerrain d) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: InkWell(
        onTap: d.filePath == null ? null : () => launchUrl(Uri.parse('${ApiClient.baseUrl}${d.filePath}')),
        child: Row(
          children: [
            Icon(d.filePath != null ? Icons.description_outlined : Icons.image_outlined, size: 16, color: AppColors.acierClair),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.titre, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  Text(
                    '${d.categorieLabel} · ${DateFormat('dd/MM HH:mm').format(d.horodatage)} · ${d.auteur}',
                    style: const TextStyle(fontSize: 10, color: AppColors.acierClair),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentChantierRow(DocumentChantier d) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse('${ApiClient.baseUrl}${d.filePath}')),
        child: Row(
          children: [
            Icon(d.type == TypeDocumentChantier.securite ? Icons.shield_outlined : Icons.description_outlined,
                size: 16, color: AppColors.acierClair),
            const SizedBox(width: 8),
            Expanded(child: Text(d.nom, style: const TextStyle(fontSize: 11.5))),
            StatusIndicator(
              label: d.type == TypeDocumentChantier.securite ? 'Sécurité' : 'Technique',
              type: StatusType.factuel,
            ),
          ],
        ),
      ),
    );
  }

  void _openAjouterDocumentDialog(BuildContext context, Chantier chantier) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AjouterDocumentChantierDialog(reference: chantier.reference),
    );
  }

  Widget _installateurRow(BuildContext context, Chantier chantier, User u) {
    final ouvert = chantier.livretsOuverts.contains(u.id);
    final initials = '${u.prenom.isNotEmpty ? u.prenom[0] : ''}${u.nom.isNotEmpty ? u.nom[0] : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: Row(
        children: [
          CircleAvatar(radius: 10, backgroundColor: AppColors.acier, child: Text(initials, style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: Text('${u.fullName} (${u.status == UserStatus.sousTraitant ? 'sous-traitant' : 'salarié'})', style: const TextStyle(fontSize: 11.5))),
          StatusIndicator(
            label: ouvert ? 'Prêt hors-ligne' : 'Livret non ouvert',
            type: ouvert ? StatusType.conforme : StatusType.nonConforme,
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
                          context.read<ChantierState>().rattacher(chantier.reference, u.id);
                          Navigator.pop(dialogContext);
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

  Widget _buildRightColumn(Chantier chantier) {
    return BoPanel(
      title: 'Avancement des 8 modules',
      child: Column(
        children: [
          BoKv(
            label: '1-3 · Consultation',
            value: chantier.documentsChantier.isEmpty
                ? const Text('—', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
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
                : const Text('—', style: TextStyle(fontSize: 11, color: AppColors.acierClair)),
          ),
          BoKv(
            label: '7 · REX',
            value: chantier.rexValide
                ? const StatusIndicator(label: 'Envoyé', type: StatusType.conforme)
                : const Text('—', style: TextStyle(fontSize: 11, color: AppColors.acierClair)),
          ),
          BoKv(
            label: '8 · Docs terrain',
            value: chantier.docsTerrain.isEmpty
                ? const Text('—', style: TextStyle(fontSize: 11, color: AppColors.acierClair))
                : StatusIndicator(label: '${chantier.docsTerrain.length} déposé(s)', type: StatusType.enCours),
          ),
        ],
      ),
    );
  }
}

class _AjouterDocumentChantierDialog extends StatefulWidget {
  final String reference;
  const _AjouterDocumentChantierDialog({required this.reference});

  @override
  State<_AjouterDocumentChantierDialog> createState() => _AjouterDocumentChantierDialogState();
}

class _AjouterDocumentChantierDialogState extends State<_AjouterDocumentChantierDialog> {
  final _nomController = TextEditingController();
  TypeDocumentChantier _type = TypeDocumentChantier.securite;
  String? _file;
  String? _fileLabel;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  bool get _peutEnvoyer => _nomController.text.trim().isNotEmpty && _file != null;

  Future<void> _choisirFichier() async {
    final file = await DocumentCapture.pickFile();
    if (file == null) return;
    setState(() {
      _file = file;
      _fileLabel = file.startsWith('data:application/pdf') ? 'PDF sélectionné' : 'Image sélectionnée';
    });
  }

  Future<void> _envoyer() async {
    setState(() => _isSubmitting = true);
    await context.read<ChantierState>().addDocumentChantier(
          widget.reference,
          type: _type.name,
          nom: _nomController.text.trim(),
          file: _file!,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un document chantier'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nomController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Nom du document',
                hintText: 'PPSPS, Plan de coupe, Notice de montage...',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7))),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(border: Border.all(color: AppColors.lignes, width: 1.5), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: _typeButton('Sécurité', TypeDocumentChantier.securite)),
                  Expanded(child: _typeButton('Technique', TypeDocumentChantier.technique)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _choisirFichier,
              icon: const Icon(Icons.attach_file),
              label: Text(_fileLabel ?? 'Choisir un fichier (PDF ou image)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _peutEnvoyer && !_isSubmitting ? _envoyer : null,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ajouter'),
        ),
      ],
    );
  }

  Widget _typeButton(String label, TypeDocumentChantier type) {
    final isOn = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: isOn ? AppColors.encre : Colors.white),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isOn ? Colors.white : AppColors.acier)),
      ),
    );
  }
}
