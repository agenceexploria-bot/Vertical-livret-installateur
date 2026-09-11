import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/models/chantier.dart';
import 'rex_audio_controller.dart';
import 'rex_audio_player.dart';

/// Carte compacte pour une entrée REX (module Qualité, back-office) —
/// repliée par défaut, disposée en 2 lignes fixes :
///   Ligne 1 : auteur/date (gauche) — bouton "Afficher/Masquer la
///             transcription" (droite, libellé complet, voir [_expanded]).
///   Ligne 2 : lecteur audio play+waveform+temps (gauche, si audio) —
///             actions Transcrire/Copier/Télécharger/Supprimer en icônes
///             compactes (droite).
/// La transcription elle-même ne s'affiche qu'au clic sur le bouton de la
/// ligne 1 (AnimatedSize). Plafonnée à 600px de large sur desktop, pleine
/// largeur disponible sur mobile. Voir bo_chantier_detail_screen.dart,
/// _buildRex. [audioController] est partagé par toutes les cartes REX d'une
/// même fiche (un seul lecteur, une seule lecture à la fois) — requis
/// seulement quand [Rex.audioPath] est renseigné. [onTranscrire], s'il est
/// fourni, déclenche la transcription automatique côté serveur — visible dès
/// que le REX a un audio, MÊME s'il a déjà une transcription (relance =
/// écrase l'existante côté serveur, pour corriger une transcription ratée).
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
  bool _expanded = false;

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

  /// Bouton distinct (libellé complet, pas juste une icône) en haut à droite
  /// de la carte — repli/dépli de la transcription. Grisé + tooltip quand le
  /// REX n'en a aucune ; un [Tooltip] à message vide afficherait quand même
  /// une bulle fantôme au survol, d'où le widget conditionnel plutôt qu'un
  /// message vide passé systématiquement.
  Widget _buildAfficherTranscriptionButton(bool hasTranscription) {
    final button = TextButton.icon(
      onPressed: hasTranscription ? () => setState(() => _expanded = !_expanded) : null,
      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 15),
      label: Text(_expanded ? 'Masquer' : 'Afficher la transcription', style: const TextStyle(fontSize: 11)),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.acier,
        disabledForegroundColor: AppColors.lignes,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: const Size(0, 26),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
    if (hasTranscription) return button;
    return Tooltip(message: 'Aucune transcription', child: button);
  }

  @override
  Widget build(BuildContext context) {
    final rex = widget.rex;
    final hasTranscription = rex.transcription != null && rex.transcription!.isNotEmpty;
    final peutTranscrire = widget.onTranscrire != null && rex.audioPath != null;
    final showCopier = hasTranscription;
    final showTelecharger = rex.audioPath != null && widget.onTelechargerAudio != null;
    final showSupprimer = widget.onSupprimer != null;
    final hasAudio = rex.audioPath != null && widget.audioController != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // La waveform partage sa ligne avec les icônes d'action : on lui
        // réserve la largeur restante une fois les icônes visibles comptées
        // (plutôt qu'un pourcentage fixe de la carte, qui déborderait sur
        // les icônes quand elles sont nombreuses).
        final iconCount = (peutTranscrire ? 1 : 0) + (showCopier ? 1 : 0) + (showTelecharger ? 1 : 0) + (showSupprimer ? 1 : 0);
        final reservedForIcons = iconCount * 32.0;
        final waveformWidth = (constraints.maxWidth - reservedForIcons - 90).clamp(60.0, 280.0);

        return Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.fond, borderRadius: BorderRadius.circular(9)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ligne 1 : auteur/date — bouton afficher/masquer la transcription.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${rex.auteur ?? 'Auteur inconnu'} · ${DateFormat('dd/MM/yyyy HH:mm').format(rex.soumisAt)}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.acierClair),
                    ),
                  ),
                  _buildAfficherTranscriptionButton(hasTranscription),
                ],
              ),
              const SizedBox(height: 4),
              // Ligne 2 : lecteur audio — actions Transcrire/Copier/Télécharger/Supprimer.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasAudio)
                    RexAudioPlayer(
                      rexId: rex.id,
                      url: rex.audioPath!,
                      controller: widget.audioController!,
                      waveformMaxWidth: waveformWidth,
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
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
                            tooltip: hasTranscription ? 'Relancer la transcription' : 'Transcrire',
                            visualDensity: VisualDensity.compact,
                            constraints: _actionIconConstraints,
                            padding: EdgeInsets.zero,
                          ),
                  if (showCopier)
                    IconButton(
                      onPressed: () => _handleCopier(context),
                      icon: const Icon(Icons.copy_outlined, size: 16, color: AppColors.acierClair),
                      tooltip: 'Copier la transcription',
                      visualDensity: VisualDensity.compact,
                      constraints: _actionIconConstraints,
                      padding: EdgeInsets.zero,
                    ),
                  if (showTelecharger)
                    IconButton(
                      onPressed: widget.onTelechargerAudio,
                      icon: const Icon(Icons.download_outlined, size: 16, color: AppColors.acierClair),
                      tooltip: 'Télécharger l\'audio',
                      visualDensity: VisualDensity.compact,
                      constraints: _actionIconConstraints,
                      padding: EdgeInsets.zero,
                    ),
                  if (showSupprimer)
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
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded && hasTranscription
                    ? SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SelectableText(
                            rex.transcription!,
                            style: const TextStyle(fontSize: 13, color: AppColors.acier),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}
