import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'voice_recorder_file_io.dart' if (dart.library.html) 'voice_recorder_file_web.dart' as file_io;

/// Résultat du démarrage d'un enregistrement — distingue un refus de
/// permission (rejouable ou non) d'un échec technique, pour que l'écran
/// affiche le message adapté et, le cas échéant, un raccourci vers les
/// réglages système (voir rex_screen.dart).
enum VoiceRecorderStartResult { started, permissionDenied, permissionPermanentlyDenied, error }

/// Capture une note vocale et la renvoie en data URL base64, prête à être
/// mise en file d'attente hors-ligne (PendingOperations) — ce fichier n'a
/// besoin d'envoyer que l'audio (ou un texte saisi) : la transcription
/// automatique tourne ensuite côté serveur si la reconnaissance vocale en
/// direct de l'app (voir rex_screen.dart) n'a rien donné (voir
/// backend/src/lib/transcription.ts).
class VoiceRecorder {
  final _recorder = AudioRecorder();
  String? _path;

  Future<VoiceRecorderStartResult> start() async {
    // Sur Android 6+ et iOS, la déclaration dans le manifest/Info.plist ne
    // suffit pas : la permission doit être (re)demandée à l'exécution avant
    // chaque tentative d'accès au micro — sans ça, l'enregistrement échoue
    // silencieusement même quand RECORD_AUDIO est bien déclaré. Sur le Web,
    // permission_handler n'a pas d'équivalent utile ; `record` déclenche
    // directement l'invite native du navigateur (getUserMedia) via
    // hasPermission()/start() ci-dessous.
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (status.isPermanentlyDenied) return VoiceRecorderStartResult.permissionPermanentlyDenied;
      if (!status.isGranted) return VoiceRecorderStartResult.permissionDenied;
    } else {
      try {
        // Safari/WebKit ne supporte pas la requête de permission "microphone"
        // via l'API Permissions du navigateur et lève une exception ici au
        // lieu de renvoyer simplement false (voir record_web) — plutôt que de
        // laisser cette erreur remonter telle quelle, on l'ignore et on tente
        // quand même le démarrage ci-dessous, qui déclenche lui-même l'invite
        // native du navigateur via getUserMedia.
        if (!await _recorder.hasPermission()) return VoiceRecorderStartResult.permissionDenied;
      } catch (e) {
        debugPrint('VoiceRecorder.start (hasPermission): $e');
      }
    }

    try {
      // Le conteneur réellement produit par l'encodeur Opus diffère du Web
      // (webm/opus, via le MediaRecorder du navigateur) au mobile (Android :
      // Opus dans un conteneur OGG — voir record_android, jamais du webm
      // malgré le nom de fichier historique). Le chemin et le type MIME
      // envoyés ensuite au backend (voir stopAndEncode) doivent refléter le
      // vrai conteneur, sans quoi Whisper reçoit un fichier mal étiqueté.
      if (kIsWeb) {
        _path = 'rex-${DateTime.now().millisecondsSinceEpoch}.webm';
      } else {
        // Contrairement au Web, `record` écrit ici un vrai fichier sur mobile
        // : il faut un chemin absolu vers un répertoire accessible en
        // écriture (un nom de fichier relatif seul faisait échouer
        // l'enregistrement — message "Micro indisponible" trompeur, alors
        // que la permission était en réalité accordée).
        final dir = await getTemporaryDirectory();
        _path = '${dir.path}/rex-${DateTime.now().millisecondsSinceEpoch}.ogg';
      }
      // Mono 16 kHz : la voix captée par un micro de téléphone n'a besoin ni
      // de stéréo ni d'un échantillonnage plus élevé — Whisper travaille de
      // toute façon en interne à 16 kHz mono, quel que soit l'encodeur — et
      // ça réduit d'autant la taille envoyée sur le réseau.
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.opus, sampleRate: 16000, numChannels: 1),
        path: _path!,
      );
      return VoiceRecorderStartResult.started;
    } catch (e) {
      debugPrint('VoiceRecorder.start: $e');
      return VoiceRecorderStartResult.error;
    }
  }

  Future<String?> stopAndEncode() async {
    final pathOrBlobUrl = await _recorder.stop();
    if (pathOrBlobUrl == null) return null;
    try {
      if (kIsWeb) {
        // Sur le Web, `record` renvoie une URL blob: résoluble via fetch
        // depuis la même page — c'est la cible prioritaire de cette PWA.
        final response = await http.get(Uri.parse(pathOrBlobUrl));
        return 'data:audio/webm;base64,${base64Encode(response.bodyBytes)}';
      }
      final bytes = await file_io.readVoiceRecorderFile(pathOrBlobUrl);
      return 'data:audio/ogg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('VoiceRecorder.stopAndEncode: $e');
      return null;
    }
  }

  void dispose() => _recorder.dispose();
}
