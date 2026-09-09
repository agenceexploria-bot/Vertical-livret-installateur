// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Une session d'enregistrement Web avec UN SEUL accès micro
/// (`getUserMedia`, une fois) et DEUX `MediaRecorder` branchés sur le MÊME
/// flux : [main] capture l'enregistrement complet, inchangé pour l'upload
/// final (voir [stop]) ; un second enregistreur cycle en tâche de fond par
/// fenêtres de [segmentDuration] pour la transcription en direct (voir
/// [onSegment]) — chaque cycle start→stop produit un petit fichier complet
/// et autonome (avec son propre en-tête), contrairement à un simple découpage
/// `timeslice` du flux principal, dont seul le premier morceau serait
/// décodable isolément.
///
/// Dégradation gracieuse : si le second enregistreur ne démarre pas ou lève
/// en cours de route (limite du navigateur, erreur quelconque), il est
/// simplement désactivé — voir [segmentsEnabled] — et [main] n'est JAMAIS
/// affecté : c'est structurellement impossible, les deux enregistreurs ne
/// partagent aucun état hormis le flux micro lui-même.
class WebRecordingSession {
  final web.MediaStream _stream;
  final web.MediaRecorder _main;
  final Duration segmentDuration;
  final void Function(Uint8List bytes) onSegment;
  final void Function(Object error) onSegmentUnavailable;

  web.MediaRecorder? _segment;
  Timer? _segmentTimer;
  bool _stopped = false;

  /// `false` dès le départ si le second enregistreur n'a jamais pu démarrer,
  /// ou à tout moment s'il échoue en cours de route — voir la doc de classe.
  bool get segmentsEnabled => _segment != null;

  WebRecordingSession._(
    this._stream,
    this._main, {
    required this.segmentDuration,
    required this.onSegment,
    required this.onSegmentUnavailable,
  });

  static Future<WebRecordingSession> start({
    required String mimeType,
    Duration segmentDuration = const Duration(seconds: 5),
    required void Function(Uint8List bytes) onSegment,
    required void Function(Object error) onSegmentUnavailable,
  }) async {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;
    final options = web.MediaRecorderOptions(mimeType: mimeType);
    final main = web.MediaRecorder(stream, options);
    main.start();

    final session = WebRecordingSession._(
      stream,
      main,
      segmentDuration: segmentDuration,
      onSegment: onSegment,
      onSegmentUnavailable: onSegmentUnavailable,
    );
    session._trySetUpSegmentRecorder(options);
    return session;
  }

  void _trySetUpSegmentRecorder(web.MediaRecorderOptions options) {
    try {
      final recorder = web.MediaRecorder(_stream, options);
      recorder.ondataavailable = _onSegmentData.toJS;
      recorder.onstop = ((web.Event event) => _restartSegment(recorder)).toJS;
      recorder.onerror = ((web.Event event) {
        onSegmentUnavailable(Exception('MediaRecorder (segment) onerror'));
        _segment = null;
      }).toJS;
      _segment = recorder;
      recorder.start();
      _scheduleNextStop(recorder);
    } catch (e) {
      // Dégradation gracieuse : le direct est désactivé, [main] continue
      // sans jamais avoir été affecté (voir doc de classe).
      onSegmentUnavailable(e);
      _segment = null;
    }
  }

  void _onSegmentData(web.Event event) {
    final blob = (event as web.BlobEvent).data;
    blob.arrayBuffer().toDart.then((buffer) {
      onSegment(buffer.toDart.asUint8List());
    }).catchError((Object e) {
      onSegmentUnavailable(e);
    });
  }

  void _restartSegment(web.MediaRecorder recorder) {
    if (_stopped || _segment != recorder) return;
    try {
      recorder.start();
      _scheduleNextStop(recorder);
    } catch (e) {
      onSegmentUnavailable(e);
      _segment = null;
    }
  }

  void _scheduleNextStop(web.MediaRecorder recorder) {
    _segmentTimer = Timer(segmentDuration, () {
      if (_stopped || _segment != recorder) return;
      try {
        recorder.stop();
      } catch (e) {
        onSegmentUnavailable(e);
        _segment = null;
      }
    });
  }

  /// Arrête l'enregistrement principal et renvoie l'audio complet — le
  /// second enregistreur (segments) est arrêté silencieusement au passage,
  /// son éventuel segment en cours est jeté (déjà exploité en direct via
  /// [onSegment] pour ce qui a réussi ; la transcription finale se fait
  /// côté serveur sur l'audio complet renvoyé ici, voir
  /// backend/src/lib/transcription.ts). Libère aussi le micro (voir
  /// [dispose]) une fois l'audio récupéré.
  Future<Uint8List> stop() {
    _stopped = true;
    _segmentTimer?.cancel();
    final segment = _segment;
    if (segment != null && segment.state != 'inactive') {
      try {
        segment.stop();
      } catch (_) {
        // Rien à faire : le segment en cours est de toute façon jeté.
      }
    }

    final completer = Completer<Uint8List>();
    if (_main.state == 'inactive') {
      completer.completeError(Exception('Enregistrement déjà arrêté'));
    } else {
      _main.ondataavailable = ((web.Event event) {
        final blob = (event as web.BlobEvent).data;
        blob.arrayBuffer().toDart.then((buffer) {
          if (!completer.isCompleted) completer.complete(buffer.toDart.asUint8List());
        }).catchError((Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        });
      }).toJS;
      _main.onerror = ((web.Event event) {
        if (!completer.isCompleted) completer.completeError(Exception('MediaRecorder (principal) onerror'));
      }).toJS;
      _main.stop();
    }
    return completer.future.whenComplete(dispose);
  }

  /// Libère le micro — toujours sûr à appeler plusieurs fois.
  void dispose() {
    _segmentTimer?.cancel();
    for (final track in _stream.getTracks().toDart) {
      track.stop();
    }
  }
}
