import 'dart:async';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/screens/backoffice/widgets/rex_audio_controller.dart';

/// Double de [RexAudioBackend] — ne touche jamais aux canaux de plateforme
/// réels d'audioplayers (injoignables en test) : mémorise juste ce qui a été
/// demandé (play/pause/resume/seek) et laisse le test simuler les
/// évènements du "vrai" lecteur (position, durée, fin de lecture) via les
/// méthodes emit*.
class _FakeBackend implements RexAudioBackend {
  final _stateController = StreamController<ap.PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _completeController = StreamController<void>.broadcast();

  String? lastPlayUrl;
  Duration? lastPlayPosition;
  int playCount = 0;
  bool paused = false;
  bool resumed = false;
  Duration? lastSeek;

  @override
  Stream<ap.PlayerState> get onPlayerStateChanged => _stateController.stream;
  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;
  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;
  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Future<void> play(String url, {Duration? position}) async {
    lastPlayUrl = url;
    lastPlayPosition = position;
    playCount++;
    _stateController.add(ap.PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    paused = true;
    _stateController.add(ap.PlayerState.paused);
  }

  @override
  Future<void> resume() async {
    resumed = true;
    _stateController.add(ap.PlayerState.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _completeController.close();
  }

  void emitPosition(Duration d) => _positionController.add(d);
  void emitComplete() => _completeController.add(null);
}

void main() {
  group('RexAudioController — reprise de position par REX', () {
    test('pause puis reprise du MÊME REX : ne relance jamais depuis 0 (resume, pas un nouveau play)', () async {
      final backend = _FakeBackend();
      final controller = RexAudioController(backend: backend);

      await controller.toggle('r1', 'https://x/a.webm');
      backend.emitPosition(const Duration(seconds: 60));
      await Future<void>.delayed(Duration.zero);
      expect(controller.savedPosition('r1'), const Duration(seconds: 60));

      await controller.toggle('r1', 'https://x/a.webm'); // pause
      await Future<void>.delayed(Duration.zero);
      expect(backend.paused, isTrue);

      await controller.toggle('r1', 'https://x/a.webm'); // reprise
      expect(backend.resumed, isTrue);
      expect(backend.playCount, 1, reason: 'un seul vrai play() — la reprise passe par resume(), jamais par un nouveau play depuis 0');
      expect(controller.savedPosition('r1'), const Duration(seconds: 60), reason: 'la position n\'a jamais été perdue');
    });

    test('play -> arrêt à 1:00 (changement de REX) -> re-sélection : reprend exactement à 1:00, jamais au début', () async {
      final backend = _FakeBackend();
      final controller = RexAudioController(backend: backend);

      await controller.toggle('r1', 'https://x/a.webm');
      backend.emitPosition(const Duration(minutes: 1));
      await Future<void>.delayed(Duration.zero);

      await controller.toggle('r2', 'https://x/b.webm'); // change de REX : r1 mis de côté
      expect(controller.savedPosition('r1'), const Duration(minutes: 1), reason: 'la position de r1 doit survivre au changement de REX');

      await controller.toggle('r1', 'https://x/a.webm'); // retour sur r1
      expect(backend.lastPlayUrl, 'https://x/a.webm');
      expect(backend.lastPlayPosition, const Duration(minutes: 1), reason: 'repris exactement à 1:00, pas depuis 0');
    });

    test('fin de lecture : position réinitialisée à 0 (le prochain play repart du début)', () async {
      final backend = _FakeBackend();
      final controller = RexAudioController(backend: backend);

      await controller.toggle('r1', 'https://x/a.webm');
      backend.emitPosition(const Duration(minutes: 2));
      await Future<void>.delayed(Duration.zero);
      expect(controller.savedPosition('r1'), const Duration(minutes: 2));

      backend.emitComplete();
      await Future<void>.delayed(Duration.zero);

      expect(controller.savedPosition('r1'), Duration.zero);
      expect(controller.position, Duration.zero);
    });

    test('un seul audio à la fois : sélectionner un second REX désélectionne le premier', () async {
      final backend = _FakeBackend();
      final controller = RexAudioController(backend: backend);

      await controller.toggle('r1', 'https://x/a.webm');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isPlayingRex('r1'), isTrue);

      await controller.toggle('r2', 'https://x/b.webm');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isPlayingRex('r1'), isFalse, reason: 'un seul lecteur partagé — sélectionner r2 quitte forcément r1');
      expect(controller.isPlayingRex('r2'), isTrue);
    });
  });

  group('generateWaveformHeights — déterministe', () {
    test('même seed = toujours les mêmes hauteurs, entre deux appels', () {
      final a = generateWaveformHeights('rex-abc123');
      final b = generateWaveformHeights('rex-abc123');
      expect(a, b);
    });

    test('deux seeds différents produisent (en pratique) des hauteurs différentes', () {
      final a = generateWaveformHeights('rex-abc123');
      final b = generateWaveformHeights('rex-def456');
      expect(a, isNot(equals(b)));
    });

    test('toutes les hauteurs restent dans [0, 1]', () {
      final heights = generateWaveformHeights('rex-abc123', barCount: 50);
      expect(heights, hasLength(50));
      expect(heights.every((h) => h >= 0 && h <= 1), isTrue);
    });
  });
}
