import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';

/// Ce dont [RexAudioController] a besoin d'un lecteur audio — juste assez
/// de la surface d'[ap.AudioPlayer] pour piloter la lecture, jamais toute
/// son API. Permet d'injecter un double en test (voir
/// test/screens/backoffice/rex_audio_controller_test.dart) sans dépendre
/// des canaux de plateforme réels d'audioplayers, injoignables en test.
abstract class RexAudioBackend {
  Stream<ap.PlayerState> get onPlayerStateChanged;
  Stream<Duration> get onPositionChanged;
  Stream<Duration> get onDurationChanged;
  Stream<void> get onPlayerComplete;

  /// [position] démarre la lecture directement à cet instant (voir
  /// audioplayers, AudioPlayer.play) — pas de saut audible depuis le début
  /// avant un seek séparé.
  Future<void> play(String url, {Duration? position});
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class _AudioPlayersBackend implements RexAudioBackend {
  final _player = ap.AudioPlayer();

  @override
  Stream<ap.PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;
  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;
  @override
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  @override
  Future<void> play(String url, {Duration? position}) => _player.play(ap.UrlSource(url), position: position);
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> dispose() => _player.dispose();
}

/// Génère des hauteurs de barres déterministes (0..1) à partir d'un seed
/// textuel (l'id du REX) — même seed = toujours les mêmes hauteurs, sans
/// dépendre de String.hashCode (non garanti stable d'une exécution à
/// l'autre par la spec Dart) : hash maison (djb2) donnant un entier stable.
List<double> generateWaveformHeights(String seed, {int barCount = 40}) {
  var hash = 5381;
  for (final unit in seed.codeUnits) {
    hash = ((hash << 5) + hash + unit) & 0x7fffffff;
  }
  final random = Random(hash);
  return List.generate(barCount, (_) => 0.25 + random.nextDouble() * 0.75);
}

/// Contrôleur audio REX partagé par toute une fiche chantier — un seul
/// [RexAudioBackend] réutilisé pour tous les REX de la fiche, ce qui impose
/// naturellement "un seul audio à la fois" (démarrer un REX coupe
/// nécessairement celui en cours, il n'y a qu'un lecteur). Mémorise la
/// position de chaque REX (par id) entre deux lectures : survit aux
/// changements d'onglet de la fiche tant que ce contrôleur reste en vie
/// (créé une fois par _BoChantierDetailScreenState) — remis à zéro en
/// changeant de chantier (nouvelle instance de l'écran, donc du
/// contrôleur), ce qui est acceptable (voir demande produit).
class RexAudioController extends ChangeNotifier {
  final RexAudioBackend _backend;
  final Map<String, Duration> _positions = {};

  String? _currentRexId;
  ap.PlayerState _state = ap.PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  late final StreamSubscription<ap.PlayerState> _stateSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<void> _completeSub;

  RexAudioController({RexAudioBackend? backend}) : _backend = backend ?? _AudioPlayersBackend() {
    _stateSub = _backend.onPlayerStateChanged.listen((s) {
      _state = s;
      notifyListeners();
    });
    _positionSub = _backend.onPositionChanged.listen((p) {
      _position = p;
      if (_currentRexId != null) _positions[_currentRexId!] = p;
      notifyListeners();
    });
    _durationSub = _backend.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _completeSub = _backend.onPlayerComplete.listen((_) {
      if (_currentRexId != null) _positions[_currentRexId!] = Duration.zero;
      _position = Duration.zero;
      _state = ap.PlayerState.completed;
      notifyListeners();
    });
  }

  String? get currentRexId => _currentRexId;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _state == ap.PlayerState.playing;

  bool isCurrentRex(String rexId) => _currentRexId == rexId;
  bool isPlayingRex(String rexId) => isCurrentRex(rexId) && isPlaying;

  /// Position déjà écoutée pour ce REX — 0 s'il n'a jamais été joué, ou si
  /// sa dernière lecture s'est terminée (voir onPlayerComplete ci-dessus).
  Duration savedPosition(String rexId) => rexId == _currentRexId ? _position : (_positions[rexId] ?? Duration.zero);

  /// Bouton play/pause d'un REX précis : bascule lecture/pause s'il est déjà
  /// sélectionné, sinon le sélectionne et reprend à sa position mémorisée.
  Future<void> toggle(String rexId, String url) async {
    if (_currentRexId == rexId) {
      if (isPlaying) {
        await _backend.pause();
      } else {
        await _backend.resume();
      }
      return;
    }
    if (_currentRexId != null) {
      _positions[_currentRexId!] = _position;
    }
    final resumeAt = _positions[rexId] ?? Duration.zero;
    _currentRexId = rexId;
    _position = resumeAt;
    _duration = Duration.zero;
    notifyListeners();
    await _backend.play(url, position: resumeAt > Duration.zero ? resumeAt : null);
  }

  /// Clic direct sur la waveform : sélectionne ce REX si besoin, puis va
  /// exactement à la position visée.
  Future<void> seekWithin(String rexId, String url, Duration target) async {
    if (_currentRexId != rexId) {
      if (_currentRexId != null) _positions[_currentRexId!] = _position;
      _currentRexId = rexId;
      _duration = Duration.zero;
      await _backend.play(url, position: target);
    } else {
      await _backend.seek(target);
    }
    _position = target;
    _positions[rexId] = target;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _completeSub.cancel();
    _backend.dispose();
    super.dispose();
  }
}
