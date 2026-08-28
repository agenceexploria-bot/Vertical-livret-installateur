import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

/// Capture une note vocale et la renvoie en data URL base64 (webm/opus),
/// prête à être mise en file d'attente hors-ligne (PendingOperations) — ce
/// fichier n'a besoin d'envoyer que l'audio (ou un texte saisi) : la
/// transcription automatique tourne ensuite côté serveur si la
/// reconnaissance vocale en direct de l'app (voir rex_screen.dart) n'a rien
/// donné (voir backend/src/lib/transcription.ts).
class VoiceRecorder {
  final _recorder = AudioRecorder();

  Future<bool> start() async {
    try {
      // Safari/WebKit ne supporte pas la requête de permission "microphone"
      // via l'API Permissions du navigateur et lève une exception ici au
      // lieu de renvoyer simplement false (voir record_web) — plutôt que de
      // laisser cette erreur remonter telle quelle (bouton micro silencieux,
      // aucun retour visuel), on l'ignore et on tente quand même le
      // démarrage ci-dessous, qui déclenche lui-même l'invite native du
      // navigateur via getUserMedia.
      if (!await _recorder.hasPermission()) return false;
    } catch (e) {
      debugPrint('VoiceRecorder.start (hasPermission): $e');
    }
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.opus),
        path: 'rex-${DateTime.now().millisecondsSinceEpoch}.webm',
      );
      return true;
    } catch (e) {
      debugPrint('VoiceRecorder.start: $e');
      return false;
    }
  }

  Future<String?> stopAndEncode() async {
    final pathOrBlobUrl = await _recorder.stop();
    if (pathOrBlobUrl == null) return null;
    try {
      // Sur le Web, `record` renvoie une URL blob: résoluble via fetch depuis
      // la même page — c'est la cible prioritaire de cette PWA.
      final response = await http.get(Uri.parse(pathOrBlobUrl));
      return 'data:audio/webm;base64,${base64Encode(response.bodyBytes)}';
    } catch (e) {
      debugPrint('VoiceRecorder.stopAndEncode: $e');
      return null;
    }
  }

  void dispose() => _recorder.dispose();
}
