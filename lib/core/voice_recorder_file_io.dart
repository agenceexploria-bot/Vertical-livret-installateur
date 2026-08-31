import 'dart:io';
import 'dart:typed_data';

/// Implémentation mobile/desktop (dart:io) — voir voice_recorder_file_web.dart
/// pour l'alternative Web, jamais appelée en pratique (le Web lit son propre
/// blob: via http, voir VoiceRecorder.stopAndEncode).
Future<Uint8List> readVoiceRecorderFile(String path) => File(path).readAsBytes();
