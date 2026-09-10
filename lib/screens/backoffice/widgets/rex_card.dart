import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/models/chantier.dart';
import 'rex_audio_controller.dart';
import 'rex_audio_player.dart';

/// Carte compacte pour une entrée REX (module Qualité, back-office) —
/// auteur + date, transcription (ou message de repli si absente), et
/// lecteur audio + téléchargement si [Rex.audioPath] est renseigné (masqués
/// tous les deux sinon, pas de lecteur vide). Voir bo_chantier_detail_screen.dart,
/// _buildRex. [audioController] est partagé par toutes les cartes REX d'une
/// même fiche (un seul lecteur, une seule lecture à la fois) — requis
/// seulement quand [Rex.audioPath] est renseigné.
class RexCard extends StatelessWidget {
  final Rex rex;
  final RexAudioController? audioController;
  final VoidCallback? onTelechargerAudio;
  final VoidCallback? onSupprimer;

  const RexCard({super.key, required this.rex, this.audioController, this.onTelechargerAudio, this.onSupprimer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.fond, borderRadius: BorderRadius.circular(9)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rex.auteur ?? 'Auteur inconnu'} · ${DateFormat('dd/MM/yyyy HH:mm').format(rex.soumisAt)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.acierClair),
                ),
                const SizedBox(height: 4),
                Text(
                  rex.transcription ?? '(note vocale sans transcription)',
                  style: const TextStyle(fontSize: 13, color: AppColors.acier),
                ),
                if (rex.audioPath != null && audioController != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RexAudioPlayer(rexId: rex.id, url: rex.audioPath!, controller: audioController!),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: onTelechargerAudio,
                        icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.acierClair),
                        tooltip: 'Télécharger l\'audio',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (onSupprimer != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.acierClair),
              tooltip: 'Supprimer ce REX',
              onPressed: onSupprimer,
            ),
          ],
        ],
      ),
    );
  }
}
