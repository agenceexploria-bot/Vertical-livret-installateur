import 'dart:typed_data';

/// dart:io n'existe pas sur le Web — cette branche n'est jamais appelée en
/// pratique, VoiceRecorder.stopAndEncode lit son propre blob: via http sur
/// cette plateforme (voir voice_recorder_file_io.dart pour l'implémentation
/// mobile/desktop réellement utilisée).
Future<Uint8List> readVoiceRecorderFile(String path) =>
    throw UnsupportedError('readVoiceRecorderFile indisponible sur le Web');
