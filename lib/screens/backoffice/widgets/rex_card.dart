import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/models/chantier.dart';
import 'rex_audio_controller.dart';
import 'rex_audio_player.dart';

/// Carte compacte pour une entrée REX (module Qualité, back-office) —
/// disposée en 3 lignes : auteur/date + actions (ligne 1), lecteur audio
/// (ligne 2, si audio), transcription sélectionnable ou message de repli
/// (ligne 3). Plafonnée à 600px de large sur desktop, pleine largeur
/// disponible sur mobile. Voir bo_chantier_detail_screen.dart, _buildRex.
/// [audioController] est partagé par toutes les cartes REX d'une même fiche
/// (un seul lecteur, une seule lecture à la fois) — requis seulement quand
/// [Rex.audioPath] est renseigné. [onTranscrire], s'il est fourni, déclenche
/// la transcription automatique côté serveur (bouton visible seulement si le
/// REX a un audio et pas encore de transcription).
class RexCard extends StatefulWidget {
  final Rex rex;
  final RexAudioController? audioController;
  final VoidCallback? onTelechargerAudio;
  final VoidCallback? onSupprimer;
  final Future<void> Function()? onTranscrire;

  const RexCard({
    super.key,
    required this.rex,
    this.audioController,
    this.onTelechargerAudio,
    this.onSupprimer,
    this.onTranscrire,
  });

  @override
  State<RexCard> createState() => _RexCardState();
}

class _RexCardState extends State<RexCard> {
  bool _transcribing = false;

  Future<void> _handleTranscrire() async {
    if (_transcribing || widget.onTranscrire == null) return;
    setState(() => _transcribing = true);
    try {
      await widget.onTranscrire!();
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _handleCopier(BuildContext context) async {
    final texte = widget.rex.transcription;
    if (texte == null || texte.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texte));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcription copiée')),
    );
  }

  static const _actionIconConstraints = BoxConstraints(minWidth: 30, minHeight: 30);

  @override
  Widget build(BuildContext context) {
    final rex = widget.rex;
    final hasTranscription = rex.transcription != null && rex.transcription!.isNotEmpty;
    final peutTranscrire = widget.onTranscrire != null && rex.audioPath != null && !hasTranscription;

    return LayoutBuilder(
      builder: (context, constraints) {
        final waveformWidth = (constraints.maxWidth * 0.6).clamp(100.0, 320.0);
        return Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.fond, borderRadius: BorderRadius.circular(9)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '${rex.auteur ?? 'Auteur inconnu'} · ${DateFormat('dd/MM/yyyy HH:mm').format(rex.soumisAt)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.acierClair),
                      ),
                    ),
                  ),
                  if (hasTranscription)
                    IconButton(
                      onPressed: () => _handleCopier(context),
                      icon: const Icon(Icons.copy_outlined, size: 16, color: AppColors.acierClair),
                      tooltip: 'Copier la transcription',
                      visualDensity: VisualDensity.compact,
                      constraints: _actionIconConstraints,
                      padding: EdgeInsets.zero,
                    ),
                  if (peutTranscrire)
                    _transcribing
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange),
                            ),
                          )
                        : IconButton(
                            onPressed: _handleTranscrire,
                            icon: const Icon(Icons.spellcheck, size: 16, color: AppColors.acierClair),
                            tooltip: 'Transcrire',
                            visualDensity: VisualDensity.compact,
                            constraints: _actionIconConstraints,
                            padding: EdgeInsets.zero,
                          ),
                  if (rex.audioPath != null && widget.onTelechargerAudio != null)
                    IconButton(
                      onPressed: widget.onTelechargerAudio,
                      icon: const Icon(Icons.download_outlined, size: 16, color: AppColors.acierClair),
                      tooltip: 'Télécharger l\'audio',
                      visualDensity: VisualDensity.compact,
                      constraints: _actionIconConstraints,
                      padding: EdgeInsets.zero,
                    ),
                  if (widget.onSupprimer != null)
                    IconButton(
                      onPressed: widget.onSupprimer,
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.acierClair),
                      tooltip: 'Supprimer ce REX',
                      visualDensity: VisualDensity.compact,
                      constraints: _actionIconConstraints,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              if (rex.audioPath != null && widget.audioController != null) ...[
                const SizedBox(height: 4),
                RexAudioPlayer(
                  rexId: rex.id,
                  url: rex.audioPath!,
                  controller: widget.audioController!,
                  waveformMaxWidth: waveformWidth,
                ),
              ],
              const SizedBox(height: 6),
              if (hasTranscription)
                SelectableText(
                  rex.transcription!,
                  style: const TextStyle(fontSize: 13, color: AppColors.acier),
                )
              else
                const Text(
                  '(note vocale sans transcription)',
                  style: TextStyle(fontSize: 13, color: AppColors.acier),
                ),
            ],
          ),
        );
      },
    );
  }
}
