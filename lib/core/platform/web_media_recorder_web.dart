// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// Interroge directement le navigateur — voir `voice_recorder.dart`
/// (pickSupportedAudioMimeType) pour la logique de sélection testable, qui
/// reçoit cette fonction en paramètre plutôt que d'appeler `web.MediaRecorder`
/// elle-même.
bool isAudioMimeTypeSupported(String type) => web.MediaRecorder.isTypeSupported(type);
