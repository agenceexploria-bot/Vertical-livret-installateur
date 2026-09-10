import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Lecteur audio compact pour la note vocale d'un REX (voir
/// [Rex.audioPath]) — juste lecture/pause et la durée, pas de barre de
/// progression ni de contrôle de volume : le besoin ici est d'écouter la
/// note directement depuis la fiche chantier back-office, pas un lecteur
/// média complet. N'est jamais affiché si le REX n'a pas d'audio (voir
/// bo_chantier_detail_screen.dart, _buildRex).
class RexAudioPlayer extends StatefulWidget {
  final String url;
  const RexAudioPlayer({super.key, required this.url});

  @override
  State<RexAudioPlayer> createState() => _RexAudioPlayerState();
}

class _RexAudioPlayerState extends State<RexAudioPlayer> {
  final _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late final StreamSubscription<PlayerState> _stateSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<Duration> _positionSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _durationSub.cancel();
    _positionSub.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else if (_state == PlayerState.paused) {
      await _player.resume();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final playing = _state == PlayerState.playing;
    final total = _duration > Duration.zero ? _duration : _position;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: AppColors.orange),
          iconSize: 28,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: playing ? 'Mettre en pause' : 'Écouter la note vocale',
        ),
        const SizedBox(width: 8),
        Text('${_format(_position)} / ${_format(total)}', style: const TextStyle(fontSize: 11, color: AppColors.acierClair)),
      ],
    );
  }
}
