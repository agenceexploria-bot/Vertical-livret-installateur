import 'dart:typed_data';

/// Hors Web : cette classe n'est jamais instanciée en pratique (voir
/// voice_recorder.dart, branche `kIsWeb && isMobileDevice()`).
class WebRecordingSession {
  bool get segmentsEnabled => false;

  static Future<WebRecordingSession> start({
    required String mimeType,
    Duration segmentDuration = const Duration(seconds: 5),
    required void Function(Uint8List bytes) onSegment,
    required void Function(Object error) onSegmentUnavailable,
  }) =>
      throw UnsupportedError('WebRecordingSession indisponible hors Web');

  Future<Uint8List> stop() => throw UnsupportedError('WebRecordingSession indisponible hors Web');

  void dispose() {}
}
