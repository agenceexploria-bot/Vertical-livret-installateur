import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/document_download.dart';
import '../../core/theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/chantier.dart';
import '../../state/chantier_state.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final chantier = context.watch<ChantierState>().currentChantier;

    return ResponsiveLayout(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: AppColors.vert),
            const SizedBox(height: 32),
            const Text('PV signé et archivé', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (chantier != null)
              Text(
                'Signé par ${chantier.pvSigneur ?? 'le client'}'
                '${chantier.pvSigneAt != null ? ' le ${DateFormat('dd/MM/yyyy à HH:mm').format(chantier.pvSigneAt!)}' : ''}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.acier, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            const Text(
              'Téléchargez le PDF signé ci-dessous.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.acier),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.fond,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.lignes),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: AppColors.rouge),
                  const SizedBox(width: 16),
                  Expanded(child: Text('PV_${chantier?.reference ?? ''}_Reception.pdf', style: const TextStyle(fontSize: 13))),
                  _isDownloading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: chantier == null ? null : () => _telechargerPv(context, chantier),
                          icon: const Icon(Icons.download, size: 20),
                          tooltip: 'Télécharger le PDF',
                        ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Retour au livret'),
            ),
          ],
        ),
      ),
    );
  }

  /// Si le PV a été signé via l'import d'un PDF déjà signé, on le télécharge
  /// tel quel (aucune génération nécessaire, c'est déjà un vrai PDF). S'il a
  /// été signé au doigt (image PNG), on génère un PDF à la volée — infos du
  /// chantier + image de la signature — pour toujours proposer un vrai PDF,
  /// quel que soit le mode de signature utilisé.
  Future<void> _telechargerPv(BuildContext context, Chantier chantier) async {
    final imagePath = chantier.pvSignatureImagePath;
    if (imagePath != null && imagePath.toLowerCase().endsWith('.pdf')) {
      final ok = await launchUrl(forceDownloadUri(imagePath), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de télécharger le PDF.')),
        );
      }
      return;
    }

    setState(() => _isDownloading = true);
    try {
      pw.MemoryImage? signatureImage;
      if (imagePath != null) {
        try {
          final response = await http.get(Uri.parse(imagePath));
          if (response.statusCode == 200) signatureImage = pw.MemoryImage(response.bodyBytes);
        } catch (_) {
          // Image introuvable : le PDF est tout de même généré, sans elle,
          // plutôt que d'empêcher le téléchargement.
        }
      }

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (pdfContext) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Procès-verbal de réception', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Chantier : ${chantier.reference} — ${chantier.client}'),
              pw.Text('Adresse : ${chantier.adresse}, ${chantier.ville}'),
              pw.SizedBox(height: 24),
              pw.Text(
                'Signé par ${chantier.pvSigneur ?? 'le client'}'
                '${chantier.pvSigneAt != null ? ' le ${DateFormat('dd/MM/yyyy à HH:mm').format(chantier.pvSigneAt!)}' : ''}.',
              ),
              if (signatureImage != null) ...[
                pw.SizedBox(height: 16),
                pw.Image(signatureImage, height: 120),
              ],
            ],
          ),
        ),
      );

      await Printing.sharePdf(bytes: await doc.save(), filename: 'PV_${chantier.reference}_Reception.pdf');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
