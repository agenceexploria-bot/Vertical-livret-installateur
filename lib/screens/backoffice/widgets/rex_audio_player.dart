import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'rex_audio_controller.dart';

/// Lecteur audio "façon WhatsApp" pour la note vocale d'un REX — bouton
/// rond play/pause, waveform compacte (barres de hauteurs déterministes,
/// seedées sur [rexId]) dont la portion déjà écoutée se colore, un curseur
/// vertical marquant la position exacte, et temps courant/durée. Scrubber
/// complet : un tap ou un glissement horizontal sur la waveform déplace la
/// lecture. Pendant la lecture, quelques barres autour de la position
/// courante ondulent légèrement (effet égaliseur discret), statiques à
/// l'arrêt. Toute la logique de lecture/position/waveform passe par
/// [controller], partagé par tous les REX d'une même fiche — voir
/// RexAudioController pour la reprise de position et la règle "un seul
/// audio à la fois".
class RexAudioPlayer extends StatefulWidget {
  final String rexId;
  final String url;
  final RexAudioController controller;
  // Largeur de la piste waveform — calculée par RexCard (~60% de la largeur
  // de la carte) pour ne jamais s'étirer sur toute la largeur de l'écran.
  final double waveformMaxWidth;

  const RexAudioPlayer({
    super.key,
    required this.rexId,
    required this.url,
    required this.controller,
    this.waveformMaxWidth = 200,
  });

  @override
  State<RexAudioPlayer> createState() => _RexAudioPlayerState();
}

// Un cycle d'ondulation dure ~120ms ; la boucle de l'AnimationController
// couvre plusieurs cycles pour offrir assez de résolution d'interpolation
// tout en revenant pile à sa valeur de départ (pas de saut visible à la
// reprise de boucle).
const _kWaveCycleMs = 120;
const _kWaveCyclesPerLoop = 8;

class _RexAudioPlayerState extends State<RexAudioPlayer> with SingleTickerProviderStateMixin {
  late final List<double> _barHeights = generateWaveformHeights(widget.rexId);
  late final AnimationController _waveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _kWaveCycleMs * _kWaveCyclesPerLoop),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _waveController.addListener(_onWaveTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _waveController.removeListener(_onWaveTick);
    _waveController.dispose();
    super.dispose();
  }

  void _onWaveTick() {
    if (mounted) setState(() {});
  }

  // Le contrôleur notifie à chaque tick de position, pour tous les REX de la
  // fiche confondus — un setState ici ne concerne que ce petit widget (bouton
  // + waveform + temps), jamais le reste de la carte REX (auteur, date,
  // transcription), qui ne s'abonne pas au contrôleur. C'est aussi ici que
  // l'animation d'ondulation démarre/s'arrête, suivant l'état de lecture réel
  // de CE REX précis (pas celui d'un autre REX de la fiche).
  void _onControllerChanged() {
    if (!mounted) return;
    final playing = widget.controller.isPlayingRex(widget.rexId);
    if (playing && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!playing && _waveController.isAnimating) {
      _waveController.stop();
    }
    setState(() {});
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleSeek(double localDx, Duration duration) {
    if (duration == Duration.zero || widget.waveformMaxWidth <= 0) return;
    final ratio = (localDx / widget.waveformMaxWidth).clamp(0.0, 1.0);
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
          iconSize: 32,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: playing ? 'Mettre en pause' : 'Écouter la note vocale',
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _handleSeek(details.localPosition.dx, duration),
              onHorizontalDragUpdate: (details) => _handleSeek(details.localPosition.dx, duration),
              child: SizedBox(
                height: 26,
                width: widget.waveformMaxWidth,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    heights: _barHeights,
                    progress: progress,
                    playedColor: AppColors.orange,
                    unplayedColor: AppColors.lignes,
                    isPlaying: playing,
                    wavePhase: _waveController.value * _kWaveCyclesPerLoop,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_format(position)} / ${_format(duration > Duration.zero ? duration : position)}',
              style: const TextStyle(fontSize: 10.5, color: AppColors.acierClair),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dessine la waveform (barres + curseur de progression). Un nouveau
/// [_WaveformPainter] est créé à chaque tick de position ou d'animation,
/// mais [shouldRepaint] ne redessine le canevas que si quelque chose a
/// réellement changé visuellement.
class _WaveformPainter extends CustomPainter {
  final List<double> heights;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;
  final bool isPlaying;
  // Phase courante de l'ondulation, en nombre de cycles (fractionnaire) —
  // seulement pertinente/animée quand [isPlaying] est vrai.
  final double wavePhase;

  _WaveformPainter({
    required this.heights,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
    required this.isPlaying,
    required this.wavePhase,
  });

  // Nombre de barres de part et d'autre de la position courante qui
  // ondulent pendant la lecture (5 barres au total avec le centre).
  static const _waveRadius = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty || size.width <= 0) return;
    const gap = 1.5;
    final barCount = heights.length;
    final barWidth = ((size.width - gap * (barCount - 1)) / barCount).clamp(1.0, double.infinity);
    final playedBars = (progress * barCount).round();
    for (var i = 0; i < barCount; i++) {
      var heightFactor = heights[i];
      if (isPlaying) {
        final distance = (i - playedBars).abs();
        if (distance <= _waveRadius) {
          final wobble = sin((wavePhase + i * 0.35) * 2 * pi) * 0.1 * (1 - distance / (_waveRadius + 1));
          heightFactor = (heightFactor * (1 + wobble)).clamp(0.05, 1.0);
        }
      }
      final barHeight = (heightFactor * size.height).clamp(2.0, size.height);
      final x = i * (barWidth + gap);
      final paint = Paint()..color = i < playedBars ? playedColor : unplayedColor;
      final rect = Rect.fromLTWH(x, (size.height - barHeight) / 2, barWidth, barHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)), paint);
    }

    if (progress > 0) {
      final cursorX = (progress * size.width).clamp(0.0, size.width);
      final cursorPaint = Paint()
        ..color = playedColor
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(cursorX, 0), Offset(cursorX, size.height), cursorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.playedColor != playedColor ||
      oldDelegate.unplayedColor != unplayedColor ||
      oldDelegate.isPlaying != isPlaying ||
      oldDelegate.wavePhase != wavePhase;
}
