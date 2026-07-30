import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../document_capture.dart';
import '../theme.dart';
import '../../data/models/chantier.dart';
import '../../state/chantier_state.dart';

/// Le PV est renseigné par le back-office (CA/Admin/Direction) — signataire +
/// PDF signé optionnel, transmis via la même route que l'ancienne signature
/// au doigt côté installateur (les deux flux coexistent). Partagé entre le
/// back-office web (BoChantierDetailScreen) et la fiche chantier mobile du CA
/// (CaChantierDetailScreen) — même logique, même route backend.
class RenseignerPvDialog extends StatefulWidget {
  final Chantier chantier;
  const RenseignerPvDialog({super.key, required this.chantier});

  @override
  State<RenseignerPvDialog> createState() => _RenseignerPvDialogState();
}

class _RenseignerPvDialogState extends State<RenseignerPvDialog> {
  final _signataireController = TextEditingController();
  String? _pdfDataUrl;
  String? _pdfName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _signataireController.dispose();
    super.dispose();
  }

  Future<void> _importerPdf() async {
    final picked = await DocumentCapture.pickFile(allowedExtensions: ['pdf']);
    if (picked == null) return;
    setState(() {
      _pdfDataUrl = picked.dataUrl;
      _pdfName = picked.fileName;
    });
  }

  Future<void> _enregistrer() async {
    if (_signataireController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await context.read<ChantierState>().submitPv(
            widget.chantier.reference,
            _signataireController.text.trim(),
            signatureImage: _pdfDataUrl,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Renseigner le PV — ${widget.chantier.reference}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _signataireController,
              decoration: const InputDecoration(labelText: 'Nom et fonction du signataire'),
            ),
            const SizedBox(height: 16),
            Row(
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
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _enregistrer,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Valider le PV'),
        ),
      ],
    );
  }
}
