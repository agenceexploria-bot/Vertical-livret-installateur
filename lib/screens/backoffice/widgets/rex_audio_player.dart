import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'rex_audio_controller.dart';

/// Lecteur audio "façon WhatsApp" pour la note vocale d'un REX — bouton
/// rond play/pause, waveform (barres de hauteurs déterministes, seedées sur
/// [rexId]) dont la portion déjà écoutée se colore, et temps courant/durée.
/// Toute la logique de lecture/position/waveform passe par [controller],
/// partagé par tous les REX d'une même fiche — voir RexAudioController pour
/// la reprise de position et la règle "un seul audio à la fois".
class RexAudioPlayer extends StatefulWidget {
  final String rexId;
  final String url;
  final RexAudioController controller;

  const RexAudioPlayer({super.key, required this.rexId, required this.url, required this.controller});

  @override
  State<RexAudioPlayer> createState() => _RexAudioPlayerState();
}

class _RexAudioPlayerState extends State<RexAudioPlayer> {
  late final List<double> _barHeights = generateWaveformHeights(widget.rexId);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // Le contrôleur notifie à chaque tick de position, pour tous les REX de la
  // fiche confondus — un setState ici ne concerne que ce petit widget (bouton
  // + waveform + temps), jamais le reste de la carte REX (auteur, date,
  // transcription), qui ne s'abonne pas au contrôleur.
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleSeekTap(TapUpDetails details, double width, Duration duration) {
    if (duration == Duration.zero || width <= 0) return;
    final ratio = (details.localPosition.dx / width).clamp(0.0, 1.0);
    widget.controller.seekWithin(widget.rexId, widget.url, duration * ratio);
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.controller.isCurrentRex(widget.rexId);
    final playing = widget.controller.isPlayingRex(widget.rexId);
    final position = widget.controller.savedPosition(widget.rexId);
    final duration = isCurrent ? widget.controller.duration : Duration.zero;
    final progress = duration > Duration.zero ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0) : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => widget.controller.toggle(widget.rexId, widget.url),
          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: AppColors.orange),
          iconSize: 34,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: playing ? 'Mettre en pause' : 'Écouter la note vocale',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _handleSeekTap(details, constraints.maxWidth, duration),
                    child: SizedBox(
                      height: 28,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _WaveformPainter(
                          heights: _barHeights,
                          progress: progress,
                          playedColor: AppColors.orange,
                          unplayedColor: AppColors.lignes,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                '${_format(position)} / ${_format(duration > Duration.zero ? duration : position)}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.acierClair),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dessine uniquement la waveform — un nouveau [_WaveformPainter] est créé à
/// chaque tick de position, mais [shouldRepaint] ne redessine le canevas que
/// si la portion "écoutée" a réellement changé de barre, pas à chaque pixel
/// de progression.
class _WaveformPainter extends CustomPainter {
  final List<double> heights;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _WaveformPainter({required this.heights, required this.progress, required this.playedColor, required this.unplayedColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty || size.width <= 0) return;
    const gap = 2.0;
    final barCount = heights.length;
    final barWidth = ((size.width - gap * (barCount - 1)) / barCount).clamp(1.0, double.infinity);
    final playedBars = (progress * barCount).round();
    for (var i = 0; i < barCount; i++) {
      final barHeight = (heights[i] * size.height).clamp(2.0, size.height);
      final x = i * (barWidth + gap);
      final paint = Paint()..color = i < playedBars ? playedColor : unplayedColor;
      final rect = Rect.fromLTWH(x, (size.height - barHeight) / 2, barWidth, barHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.playedColor != playedColor || oldDelegate.unplayedColor != unplayedColor;
}
