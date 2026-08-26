import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../document_capture.dart';
import '../theme.dart';
import 'drop_zone.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../state/chantier_state.dart';

/// Dépôt (ou remplacement) du gabarit PV par le back-office (CT/Admin/
/// Direction) — un PDF, rien de plus. Ça NE valide PAS le PV : celui-ci reste
/// "en attente de signature" tant que l'installateur n'a pas fait signer le
/// client (voir signature_screen.dart, seul endroit qui fait passer le PV à
/// "validé"). Partagé entre le back-office web (BoChantierDetailScreen) et la
/// fiche chantier mobile du CT (CtChantierDetailScreen).
class RenseignerPvDialog extends StatefulWidget {
  final Chantier chantier;
  const RenseignerPvDialog({super.key, required this.chantier});

  @override
  State<RenseignerPvDialog> createState() => _RenseignerPvDialogState();
}

class _RenseignerPvDialogState extends State<RenseignerPvDialog> {
  String? _pdfDataUrl;
  String? _pdfName;
  bool _isSubmitting = false;

  Future<void> _importerPdf() async {
    final picked = await DocumentCapture.pickFile(allowedExtensions: ['pdf']);
    if (picked == null) return;
    setState(() {
      _pdfDataUrl = picked.dataUrl;
      _pdfName = picked.fileName;
    });
  }

  /// Glisser-déposer (Web) — même logique que [_importerPdf] ; seul un PDF
  /// est accepté ici (gabarit PV), le premier fichier déposé qui en est un.
  Future<void> _deposerPdf(List<XFile> files) async {
    final pdf = files.firstWhere(
      (f) => f.name.toLowerCase().endsWith('.pdf'),
      orElse: () => files.first,
    );
    if (!pdf.name.toLowerCase().endsWith('.pdf')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seul un fichier PDF est accepté pour le PV.')),
      );
      return;
    }
    final picked = (await DocumentCapture.fromDroppedFiles([pdf])).firstOrNull;
    if (picked == null || !mounted) return;
    setState(() {
      _pdfDataUrl = picked.dataUrl;
      _pdfName = picked.fileName;
    });
  }

  Future<void> _enregistrer() async {
    if (_pdfDataUrl == null) return;
    setState(() => _isSubmitting = true);
    try {
      await context.read<ChantierState>().uploadPvDocument(widget.chantier.reference, _pdfDataUrl!);
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
    final remplace = widget.chantier.pvPdfPath != null;
    return AlertDialog(
      title: Text('${remplace ? 'Remplacer' : 'Déposer'} le PV — ${widget.chantier.reference}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ce PDF sera envoyé à l\'installateur, qui le fera signer par le client sur place. '
              '${remplace ? 'Le remplacer effacera la signature déjà apposée le cas échéant.' : ''}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.acier),
            ),
            const SizedBox(height: 16),
            DropZone(
              onFilesDropped: _deposerPdf,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _pdfName ?? 'Aucun PDF importé.',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.acier),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _importerPdf,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Importer un PDF'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: (_isSubmitting || _pdfDataUrl == null) ? null : _enregistrer,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Envoyer'),
        ),
      ],
    );
  }
}
