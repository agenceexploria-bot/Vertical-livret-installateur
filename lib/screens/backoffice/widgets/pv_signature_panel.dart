import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';

/// Affichage du PV signé (signataire, horodatage, image de signature
/// cliquable) — partagé entre CA, Qualité et Admin, qui ont tous besoin de
/// voir la même preuve de validation avant facturation ou audit.
class PvSignaturePanel extends StatelessWidget {
  final String? signataire;
  final DateTime? signeAt;
  final String? signatureImagePath;

  const PvSignaturePanel({super.key, this.signataire, this.signeAt, this.signatureImagePath});

  @override
  Widget build(BuildContext context) {
    final signataireLabel = signataire ?? 'le client';
    final horodatage = signeAt != null ? DateFormat('dd/MM/yyyy à HH:mm').format(signeAt!) : null;
    final caption = Text(
      'Signé par $signataireLabel${horodatage != null ? ' le $horodatage' : ''}.',
      style: const TextStyle(fontSize: 11, color: AppColors.acier),
    );

    final imagePath = signatureImagePath;
    if (imagePath == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          caption,
          const SizedBox(height: 4),
          const Text('Aucune image de signature disponible.', style: TextStyle(fontSize: 10.5, color: AppColors.acierClair)),
        ],
      );
    }

    final imageUrl = imagePath;
    // Le PV peut être signé au doigt (image PNG) ou importé sous forme de PDF
    // déjà signé — ce dernier ne peut pas s'afficher via Image.network.
    if (imageUrl.toLowerCase().endsWith('.pdf')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          caption,
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(imageUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Ouvrir le PV signé (PDF)'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        caption,
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openSignatureDialog(context, imageUrl),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.lignes), borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.all(8),
            child: Image.network(
              imageUrl,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Text('Impossible de charger l\'image de signature.', style: TextStyle(fontSize: 10.5, color: AppColors.acierClair)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text('Cliquer sur l\'image pour l\'agrandir.', style: TextStyle(fontSize: 10, color: AppColors.acierClair)),
      ],
    );
  }

  static void _openSignatureDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(imageUrl, fit: BoxFit.contain),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
            ],
          ),
        ),
      ),
    );
  }
}
