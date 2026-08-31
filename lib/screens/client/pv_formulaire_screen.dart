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

  int _currentStep = 0;
  DateTime _dateReception = DateTime.now();
  bool _signatureVide = true;
  bool _isSubmitting = false;

  static const _sections = [
    (pvSection1Titre, pvSection1),
    (pvSection2Titre, pvSection2),
    (pvSection3Titre, pvSection3),
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

  bool get _peutValider =>
      !_isSubmitting &&
      !_signatureVide &&
      _nomSignataireCtrl.text.trim().isNotEmpty &&
      _fonctionSignataireCtrl.text.trim().isNotEmpty &&
      _reponses.checklistComplete;

  /// Petite pastille rouge accolée au titre d'une étape dont au moins une
  /// question Oui/Non n'a pas encore de réponse — guide l'installateur vers
  /// les étapes à compléter avant de pouvoir valider (voir _peutValider et le
  /// message sous le bouton dans _buildControls).
  Widget _titreEtape(String label, {required bool incomplete}) {
    if (!incomplete) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.rouge, shape: BoxShape.circle)),
      ],
    );
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
          : Stepper(
              currentStep: _currentStep,
              onStepTapped: _isSubmitting ? null : (step) => setState(() => _currentStep = step),
              onStepContinue: _stepSuivant,
              onStepCancel: _stepPrecedent,
              controlsBuilder: (context, details) => _buildControls(context, details),
              steps: [
                _stepIdentite(chantier),
                _stepSection(0),
                _stepSection(1),
                _stepServicesEtTextes(),
                _stepSignature(chantier),
              ],
            ),
    );
  }

  Widget _buildControls(BuildContext context, ControlsDetails details) {
    final estDerniere = _currentStep == 4;
    final questionsSansReponse = _reponses.nombreQuestionsSansReponse;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              if (_currentStep > 0)
                TextButton(onPressed: _isSubmitting ? null : details.onStepCancel, child: const Text('Précédent')),
              const Spacer(),
              if (!estDerniere)
                ElevatedButton(onPressed: details.onStepContinue, child: const Text('Suivant'))
              else
                ElevatedButton(
                  onPressed: _peutValider ? _valider : null,
                  child: _isSubmitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Valider le procès-verbal'),
                ),
            ],
          ),
          if (estDerniere && questionsSansReponse > 0) ...[
            const SizedBox(height: 6),
            Text(
              '$questionsSansReponse question${questionsSansReponse > 1 ? 's' : ''} sans réponse — voir les étapes marquées d\'un point rouge.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.rouge),
            ),
          ],
        ],
      ),
    );
  }

  void _stepSuivant() {
    if (_currentStep < 4) setState(() => _currentStep++);
  }

  void _stepPrecedent() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Step _stepIdentite(Chantier chantier) {
    return Step(
      title: const Text('Identité'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
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
  /// La section 3 (services) est traitée à part (voir [_stepServicesEtTextes])
  /// car elle partage l'étape avec la nature de pose et les textes libres.
  Step _stepSection(int sectionIndex) {
    final (titre, defs) = _sections[sectionIndex];
    final reponses = sectionIndex == 0 ? _reponses.receptionInstallation : _reponses.documentsRemis;
    return Step(
      title: _titreEtape('Section ${sectionIndex + 1}', incomplete: reponses.any((r) => r.reponse == null)),
      isActive: _currentStep >= sectionIndex + 1,
      state: _currentStep > sectionIndex + 1 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.encre)),
          const SizedBox(height: 12),
          for (final def in defs) _checklistItem(def, reponses.firstWhere((r) => r.id == def.id)),
        ],
      ),
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

  Step _stepServicesEtTextes() {
    final servicesItem = _reponses.servicesSupplementaires.first;
    final def = pvSection3.first;
    return Step(
      title: _titreEtape('Services', incomplete: servicesItem.reponse == null),
      isActive: _currentStep >= 3,
      state: _currentStep > 3 ? StepState.complete : StepState.indexed,
      content: Column(
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
          const SizedBox(height: 20),
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
      ),
    );
  }

  Step _stepSignature(Chantier chantier) {
    return Step(
      title: const Text('Signature'),
      isActive: _currentStep >= 4,
      state: StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date de réception'),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(_dateReception)),
            trailing: const Icon(Icons.calendar_today_outlined, size: 18),
            onTap: _choisirDate,
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
      ),
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
