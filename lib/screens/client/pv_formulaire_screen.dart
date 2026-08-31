import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/document_download.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/signature_pad.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../data/models/pv_reponses.dart';
import '../../state/chantier_state.dart';

/// Formulaire interactif du PV de réception, basé sur le gabarit officiel
/// Vertical — remplace l'ancienne signature directe sur un PDF importé pour
/// tout chantier qui n'a PAS de gabarit déjà déposé (voir la bascule dans
/// chantier_details_screen.dart : `pvPdfPath == null` route ici, sinon vers
/// [SignatureScreen] pour les chantiers restés sur l'ancien flux). À la
/// validation, le backend génère le PDF final de toutes pièces à partir des
/// réponses + la signature (voir backend/src/lib/pvFormPdf.ts).
///
/// Tout l'écran tient dans un seul SingleChildScrollView — les 5 sections
/// (checklists, réserves, signature) sont des accordéons repliables plutôt
/// qu'un Stepper : un Step.content est rendu dans une colonne à hauteur non
/// bornée à l'intérieur du Stepper, ce qui rend tout footer fixe fragile et
/// a déjà causé plusieurs régressions de visibilité (bouton de validation,
/// pavé de signature). Ici, rien n'est jamais poussé hors d'une zone
/// scrollable : tout le contenu est toujours atteignable en faisant défiler
/// la page, sur mobile comme sur desktop.
class PvFormulaireScreen extends StatefulWidget {
  const PvFormulaireScreen({super.key});

  @override
  State<PvFormulaireScreen> createState() => _PvFormulaireScreenState();
}

class _PvFormulaireScreenState extends State<PvFormulaireScreen> {
  final _reponses = PvFormReponses();
  final _maitreOeuvreCtrl = TextEditingController();
  final _operationCtrl = TextEditingController();
  final _lotCtrl = TextEditingController();
  final _quantiteCtrl = TextEditingController();
  final _reservesCtrl = TextEditingController();
  final _remarquesCtrl = TextEditingController();
  final _temoignageCtrl = TextEditingController();
  final _nomSignataireCtrl = TextEditingController();
  final _fonctionSignataireCtrl = TextEditingController();
  late final Map<String, TextEditingController> _observationCtrls;
  final _signatureKey = GlobalKey<SignaturePadState>();

  /// Index (0-4) de la section actuellement dépliée — `null` si toutes sont
  /// repliées. Une seule ouverte à la fois (voir _accordionSection) ; fermer
  /// une section ne réinitialise jamais ses données, seulement l'affichage.
  int? _openSection = 0;

  DateTime _dateReception = DateTime.now();
  bool _signatureVide = true;
  bool _isSubmitting = false;

  static const _checklistSections = [
    (pvSection1Titre, pvSection1),
    (pvSection2Titre, pvSection2),
  ];

  @override
  void initState() {
    super.initState();
    _observationCtrls = {
      for (final item in [...pvSection1, ...pvSection2, ...pvSection3]) item.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    _maitreOeuvreCtrl.dispose();
    _operationCtrl.dispose();
    _lotCtrl.dispose();
    _quantiteCtrl.dispose();
    _reservesCtrl.dispose();
    _remarquesCtrl.dispose();
    _temoignageCtrl.dispose();
    _nomSignataireCtrl.dispose();
    _fonctionSignataireCtrl.dispose();
    for (final c in _observationCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _peutValider => !_isSubmitting && _raisonsBlocage.isEmpty;

  String? _hintPourSection(List<PvChecklistReponse> reponses) {
    final n = reponses.where((r) => r.reponse == null).length;
    if (n == 0) return null;
    return '$n question${n > 1 ? 's' : ''} sans réponse';
  }

  /// `null` si signature/nom/fonction sont renseignés — sinon la première
  /// raison manquante, dans l'ordre où l'installateur les rencontre.
  String? get _raisonSignature {
    if (_signatureVide) return 'Signature du client manquante';
    if (_nomSignataireCtrl.text.trim().isEmpty) return 'Nom du signataire requis';
    if (_fonctionSignataireCtrl.text.trim().isEmpty) return 'Fonction du signataire requise';
    return null;
  }

  /// Toutes les raisons pour lesquelles le bouton de validation est
  /// désactivé, affichées ensemble sous le bouton (voir _buildValidationFooter)
  /// — l'installateur voit d'un coup tout ce qu'il reste à compléter, plutôt
  /// que de découvrir les blocages un par un.
  List<String> get _raisonsBlocage {
    final raisons = <String>[];
    final h1 = _hintPourSection(_reponses.receptionInstallation);
    if (h1 != null) raisons.add('Section 1 : $h1');
    final h2 = _hintPourSection(_reponses.documentsRemis);
    if (h2 != null) raisons.add('Section 2 : $h2');
    final h3 = _hintPourSection(_reponses.servicesSupplementaires);
    if (h3 != null) raisons.add('Section 3 : $h3');
    final hs = _raisonSignature;
    if (hs != null) raisons.add(hs);
    return raisons;
  }

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier;

    // Verrou identique à l'ancien flux : un PV déjà signé ne se rouvre
    // jamais en mode édition (voir signature_screen.dart).
    if (chantier != null && chantier.pvSigne) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/confirmation');
      });
      return const ResponsiveLayout(child: Center(child: CircularProgressIndicator()));
    }

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Procès-verbal de réception'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: chantier == null
          ? const Center(child: Text('Chantier introuvable'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderIdentite(chantier),
                  const SizedBox(height: 20),
                  _accordionSection(
                    index: 0,
                    title: 'Section 1 — Réception de l\'installation',
                    incompleteHint: _hintPourSection(_reponses.receptionInstallation),
                    content: _checklistSectionContent(0),
                  ),
                  _accordionSection(
                    index: 1,
                    title: 'Section 2 — Documents remis au client',
                    incompleteHint: _hintPourSection(_reponses.documentsRemis),
                    content: _checklistSectionContent(1),
                  ),
                  _accordionSection(
                    index: 2,
                    title: 'Section 3 — Services et nature de pose',
                    incompleteHint: _hintPourSection(_reponses.servicesSupplementaires),
                    content: _servicesSectionContent(),
                  ),
                  _accordionSection(
                    index: 3,
                    title: 'Réserves, remarques et témoignage',
                    incompleteHint: null,
                    content: _reservesSectionContent(),
                  ),
                  _accordionSection(
                    index: 4,
                    title: 'Signature',
                    incompleteHint: _raisonSignature,
                    content: _signatureSectionContent(),
                  ),
                  const SizedBox(height: 24),
                  _buildValidationFooter(),
                ],
              ),
            ),
    );
  }

  /// Un accordéon "maison" plutôt qu'[ExpansionTile] : même comportement
  /// (titre cliquable, une seule section ouverte à la fois, contenu jamais
  /// démonté — juste caché — donc aucune perte de saisie), mais avec le
  /// contrôle total du style nécessaire pour la pastille de complétude.
  Widget _accordionSection({
    required int index,
    required String title,
    required String? incompleteHint,
    required Widget content,
  }) {
    final isOpen = _openSection == index;
    final complete = incompleteHint == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lignes),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _openSection = isOpen ? null : index),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    complete ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: complete ? AppColors.vert : AppColors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.encre)),
                        if (!complete) ...[
                          const SizedBox(height: 2),
                          Text(incompleteHint, style: const TextStyle(fontSize: 11.5, color: AppColors.orange)),
                        ],
                      ],
                    ),
                  ),
                  Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: AppColors.acierClair),
                ],
              ),
            ),
          ),
          // Le contenu reste MONTÉ dans l'arbre même replié (juste absent du
          // rendu) plutôt que d'être recréé à chaque ouverture — inutile ici
          // vu que l'état vit déjà dans _reponses/les controllers (jamais
          // perdu), mais évite aussi de redémarrer inutilement les widgets
          // enfants (TextField...) à chaque bascule.
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
        ],
      ),
    );
  }

  Widget _buildValidationFooter() {
    final raisons = _raisonsBlocage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (raisons.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Avant de valider :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.orange)),
                const SizedBox(height: 4),
                for (final raison in raisons)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('•  $raison', style: const TextStyle(fontSize: 12, color: AppColors.acier)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Toujours rendu, jamais masqué — seul son état actif/grisé change
        // (voir _peutValider) : l'installateur voit toujours le bout de son
        // parcours et pourquoi il est bloqué (voir le bloc ci-dessus).
        ElevatedButton.icon(
          onPressed: _peutValider ? _valider : null,
          icon: _isSubmitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Valider le procès-verbal'),
        ),
      ],
    );
  }

  Widget _buildHeaderIdentite(Chantier chantier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lignes),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _champLectureSeule('Client / Maître d\'ouvrage', chantier.client),
          _champLectureSeule('Adresse chantier', chantier.adresse),
          _champLectureSeule('Affaire n°', chantier.referenceAffaire),
          _champLectureSeule('Contact client', chantier.contactNom),
          const SizedBox(height: 12),
          TextField(controller: _maitreOeuvreCtrl, decoration: const InputDecoration(labelText: 'Maître d\'œuvre')),
          const SizedBox(height: 12),
          TextField(controller: _operationCtrl, decoration: const InputDecoration(labelText: 'Opération')),
          const SizedBox(height: 12),
          TextField(controller: _lotCtrl, decoration: const InputDecoration(labelText: 'Lot')),
        ],
      ),
    );
  }

  Widget _champLectureSeule(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.acierClair)),
          Text(valeur, style: const TextStyle(fontSize: 14, color: AppColors.encre)),
        ],
      ),
    );
  }

  /// [sectionIndex] : 0 = section 1 (réception), 1 = section 2 (documents).
  /// La section 3 (services) a son propre contenu (voir
  /// [_servicesSectionContent]) car elle partage l'accordéon avec la nature
  /// de pose et la quantité.
  Widget _checklistSectionContent(int sectionIndex) {
    final (titre, defs) = _checklistSections[sectionIndex];
    final reponses = sectionIndex == 0 ? _reponses.receptionInstallation : _reponses.documentsRemis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.encre)),
        const SizedBox(height: 12),
        for (final def in defs) _checklistItem(def, reponses.firstWhere((r) => r.id == def.id)),
      ],
    );
  }

  Widget _checklistItem(PvChecklistItemDef def, PvChecklistReponse reponse) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('${def.id}  ${def.libelle}', style: const TextStyle(fontSize: 13, color: AppColors.encre, height: 1.3)),
              ),
              const SizedBox(width: 10),
              SegmentedButton<PvReponseValue>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: PvReponseValue.oui, label: Text('Oui')),
                  ButtonSegment(value: PvReponseValue.non, label: Text('Non')),
                ],
                selected: reponse.reponse == null ? const {} : {reponse.reponse!},
                onSelectionChanged: (selection) => setState(() => reponse.reponse = selection.isEmpty ? null : selection.first),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _observationCtrls[def.id],
            onChanged: (v) => reponse.observation = v,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(labelText: 'Observations (optionnel)', isDense: true),
          ),
        ],
      ),
    );
  }

  Widget _servicesSectionContent() {
    final servicesItem = _reponses.servicesSupplementaires.first;
    final def = pvSection3.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pvSection3Titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.encre)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('${def.id}  ${def.libelle}', style: const TextStyle(fontSize: 13, color: AppColors.encre))),
            const SizedBox(width: 10),
            SegmentedButton<PvReponseValue>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: PvReponseValue.oui, label: Text('Oui')),
                ButtonSegment(value: PvReponseValue.non, label: Text('Non')),
              ],
              selected: servicesItem.reponse == null ? const {} : {servicesItem.reponse!},
              onSelectionChanged: (s) => setState(() => servicesItem.reponse = s.isEmpty ? null : s.first),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Nature de la pose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.encre)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: pvNatureDePoseOptions.map((option) {
            final selectionne = _reponses.natureDePose.contains(option);
            return FilterChip(
              label: Text(option, style: const TextStyle(fontSize: 12)),
              selected: selectionne,
              onSelected: (v) => setState(() => v ? _reponses.natureDePose.add(option) : _reponses.natureDePose.remove(option)),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(controller: _quantiteCtrl, decoration: const InputDecoration(labelText: 'Quantité(s)')),
      ],
    );
  }

  Widget _reservesSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _reservesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Réserves', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remarquesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Remarques', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        const Text(pvTemoignageMention, style: TextStyle(fontSize: 11.5, color: AppColors.acier, fontStyle: FontStyle.italic)),
        const SizedBox(height: 6),
        TextField(
          controller: _temoignageCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Témoignage client', alignLabelWithHint: true),
        ),
      ],
    );
  }

  Widget _signatureSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Material(color: transparent) : sans ça, l'encre/le fond du ListTile
        // se peint sur le Material le plus proche, qui est celui du Scaffold
        // — masqué par le fond blanc opaque de la carte d'accordéon
        // (_accordionSection) entre les deux. Purement cosmétique (retour
        // visuel du tap), aucun changement de comportement.
        Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date de réception'),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(_dateReception)),
            trailing: const Icon(Icons.calendar_today_outlined, size: 18),
            onTap: _choisirDate,
          ),
        ),
        const SizedBox(height: 8),
        TextField(controller: _nomSignataireCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Nom du signataire (client)')),
        const SizedBox(height: 12),
        TextField(controller: _fonctionSignataireCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Fonction du signataire')),
        const SizedBox(height: 20),
        const Text('Cachet et signature Vertical', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.acierClair)),
        const SizedBox(height: 6),
        Container(
          height: 70,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: AppColors.lignes), borderRadius: BorderRadius.circular(8)),
          child: const VerticalLogo(height: 40),
        ),
        const SizedBox(height: 16),
        const Text('Cachet et signature du client', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.acierClair)),
        const SizedBox(height: 6),
        Container(
          height: 160,
          decoration: BoxDecoration(border: Border.all(color: AppColors.lignes), borderRadius: BorderRadius.circular(8)),
          child: SignaturePad(key: _signatureKey, onChanged: (vide) => setState(() => _signatureVide = vide)),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isSubmitting ? null : () => setState(() => _signatureKey.currentState?.clear()),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Effacer la signature'),
          ),
        ),
      ],
    );
  }

  Future<void> _choisirDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateReception,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _dateReception = picked);
  }

  Future<void> _valider() async {
    if (!_peutValider) return;
    setState(() => _isSubmitting = true);
    try {
      final signatureBytes = await _signatureKey.currentState?.capturePng();
      if (signatureBytes == null) throw Exception('Signature manquante.');
      final signatureDataUrl = 'data:image/png;base64,${base64Encode(signatureBytes)}';

      _reponses.maitreOeuvre = _maitreOeuvreCtrl.text;
      _reponses.operation = _operationCtrl.text;
      _reponses.lot = _lotCtrl.text;
      _reponses.quantite = _quantiteCtrl.text;
      _reponses.reserves = _reservesCtrl.text;
      _reponses.remarques = _remarquesCtrl.text;
      _reponses.temoignageClient = _temoignageCtrl.text;

      if (!mounted) return;
      await context.read<ChantierState>().submitPvFormulaire(
            chantier.reference,
            reponses: _reponses,
            dateReception: _dateReception,
            nomSignataire: _nomSignataireCtrl.text.trim(),
            fonctionSignataire: _fonctionSignataireCtrl.text.trim(),
            signatureImage: signatureDataUrl,
          );

      if (!mounted) return;
      await _afficherSucces();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, st) {
      debugPrint('PvFormulaireScreen._valider: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une erreur est survenue lors de la validation du PV. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Chantier get chantier => context.read<ChantierState>().currentChantier!;

  Future<void> _afficherSucces() async {
    if (!mounted) return;
    final pdfUrl = context.read<ChantierState>().currentChantier?.pvSignatureImagePath;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.vert, size: 40),
        title: const Text('PV validé avec succès'),
        content: const Text('Le procès-verbal a bien été généré et envoyé.'),
        actions: [
          if (pdfUrl != null)
            TextButton.icon(
              onPressed: () => launchUrl(forceDownloadUri(pdfUrl), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Télécharger le PDF'),
            ),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Terminer')),
        ],
      ),
    );
    if (!mounted) return;
    context.go('/confirmation');
  }
}
