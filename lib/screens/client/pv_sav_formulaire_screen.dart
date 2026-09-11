import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/document_download.dart';
import '../../core/photo_capture.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/signature_pad.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../state/chantier_state.dart';

/// Formulaire du PV SAV (module SAV) — même principe que
/// [lib/screens/client/pv_formulaire_screen.dart] (accordéons repliables
/// plutôt qu'un Stepper, voir sa documentation pour la raison), mais bien
/// plus léger : pas de checklist du gabarit officiel, seulement 3 sections
/// (description + pièces remplacées, photos, signature). Le backend génère
/// le PDF final à partir de ces champs (voir backend/src/lib/savFormPdf.ts).
class PvSavFormulaireScreen extends StatefulWidget {
  const PvSavFormulaireScreen({super.key});

  @override
  State<PvSavFormulaireScreen> createState() => _PvSavFormulaireScreenState();
}

class _PvSavFormulaireScreenState extends State<PvSavFormulaireScreen> {
  final _descriptionCtrl = TextEditingController();
  final _piecesCtrl = TextEditingController();
  final _nomSignataireCtrl = TextEditingController();
  final _fonctionSignataireCtrl = TextEditingController();

  final List<String> _photos = [];
  bool _isCapturingPhoto = false;

  /// Une seule section ouverte à la fois — voir pv_formulaire_screen.dart.
  int? _openSection = 0;

  List<Offset?> _signaturePoints = [];
  Size? _signatureBoxSize;
  bool _isSubmitting = false;

  bool get _signatureVide => signaturePointsEmpty(_signaturePoints);

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _piecesCtrl.dispose();
    _nomSignataireCtrl.dispose();
    _fonctionSignataireCtrl.dispose();
    super.dispose();
  }

  String? get _raisonDescription => _descriptionCtrl.text.trim().isEmpty ? 'Description de l\'intervention requise' : null;

  String? get _raisonSignature {
    if (_signatureVide) return 'Signature du client manquante';
    if (_nomSignataireCtrl.text.trim().isEmpty) return 'Nom du signataire requis';
    if (_fonctionSignataireCtrl.text.trim().isEmpty) return 'Fonction du signataire requise';
    return null;
  }

  List<String> get _raisonsBlocage {
    final raisons = <String>[];
    final rd = _raisonDescription;
    if (rd != null) raisons.add(rd);
    final rs = _raisonSignature;
    if (rs != null) raisons.add(rs);
    return raisons;
  }

  bool get _peutValider => !_isSubmitting && _raisonsBlocage.isEmpty;

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier;

    // Verrou identique au PV de réception : un PV SAV déjà signé ne se
    // rouvre jamais en mode édition.
    if (chantier != null && chantier.pvSigne) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/confirmation');
      });
      return const ResponsiveLayout(child: Center(child: CircularProgressIndicator()));
    }

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Procès-verbal d\'intervention SAV'),
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
                    title: 'Description de l\'intervention',
                    incompleteHint: _raisonDescription,
                    content: _descriptionSectionContent(),
                  ),
                  _accordionSection(
                    index: 1,
                    title: 'Photos',
                    incompleteHint: null,
                    content: _photosSectionContent(),
                  ),
                  _accordionSection(
                    index: 2,
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
          _champLectureSeule('Chantier terminé', chantier.parentReference ?? '—'),
          _champLectureSeule('Client', chantier.client),
          _champLectureSeule('Adresse chantier', chantier.adresse),
          _champLectureSeule('Affaire n°', chantier.referenceAffaire),
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

  Widget _descriptionSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _descriptionCtrl,
          onChanged: (_) => setState(() {}),
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Description de l\'intervention', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _piecesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Pièces remplacées (optionnel)', alignLabelWithHint: true),
        ),
      ],
    );
  }

  Widget _photosSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_photos.isEmpty)
          const Text('Aucune photo ajoutée.', style: TextStyle(fontSize: 12, color: AppColors.acierClair)),
        if (_photos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _photos.length; i++) _photoThumbnail(i),
            ],
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isCapturingPhoto ? null : _ajouterPhoto,
          icon: _isCapturingPhoto
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_a_photo_outlined, size: 18),
          label: const Text('Ajouter une photo'),
        ),
      ],
    );
  }

  Widget _photoThumbnail(int index) {
    final dataUrl = _photos[index];
    final base64Data = dataUrl.substring(dataUrl.indexOf(',') + 1);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(base64Decode(base64Data), width: 84, height: 84, fit: BoxFit.cover),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(() => _photos.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _ajouterPhoto() async {
    setState(() => _isCapturingPhoto = true);
    try {
      final dataUrl = await PhotoCapture.captureCompressed(context);
      if (dataUrl != null) setState(() => _photos.add(dataUrl));
    } finally {
      if (mounted) setState(() => _isCapturingPhoto = false);
    }
  }

  Widget _signatureSectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          child: SignaturePad(
            points: _signaturePoints,
            onPointsChanged: (points, boxSize) => setState(() {
              _signaturePoints = points;
              if (!boxSize.isEmpty) _signatureBoxSize = boxSize;
            }),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isSubmitting ? null : () => setState(() => _signaturePoints = []),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Effacer la signature'),
          ),
        ),
      ],
    );
  }

  Future<void> _valider() async {
    if (!_peutValider) return;
    setState(() => _isSubmitting = true);
    try {
      final signatureBytes = await renderSignaturePng(_signaturePoints, _signatureBoxSize ?? const Size(300, 160));
      if (signatureBytes == null) throw Exception('Signature manquante.');
      final signatureDataUrl = 'data:image/png;base64,${base64Encode(signatureBytes)}';

      if (!mounted) return;
      await context.read<ChantierState>().submitSavPvFormulaire(
            chantier.reference,
            descriptionIntervention: _descriptionCtrl.text.trim(),
            piecesRemplacees: _piecesCtrl.text.trim().isEmpty ? null : _piecesCtrl.text.trim(),
            photos: _photos,
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
      debugPrint('PvSavFormulaireScreen._valider: $e\n$st');
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
        content: const Text('Le procès-verbal d\'intervention a bien été généré et envoyé.'),
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
