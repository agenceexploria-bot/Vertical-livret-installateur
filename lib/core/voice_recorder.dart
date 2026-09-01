import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'platform/web_media_recorder.dart';
import 'voice_recorder_file_io.dart' if (dart.library.html) 'voice_recorder_file_web.dart' as file_io;

/// Résultat du démarrage d'un enregistrement — distingue un refus de
/// permission (rejouable ou non) d'un échec technique, et [unsupported]
/// (navigateur incapable d'enregistrer de l'audio, voir
/// [pickSupportedAudioMimeType]), pour que l'écran affiche le message adapté
/// (voir rex_screen.dart).
enum VoiceRecorderStartResult { started, permissionDenied, permissionPermanentlyDenied, unsupported, error }

/// Types MIME essayés dans cet ordre pour l'enregistrement audio Web via
/// MediaRecorder — Safari/iOS en tête (`audio/mp4`, `audio/aac` : seuls
/// formats qu'il supporte, HE-AAC dans un conteneur MP4 depuis iOS 14.3,
/// voir record_web/lib/mime_types.dart pour la correspondance exacte avec
/// AudioEncoder.aacLc), puis les navigateurs desktop/Android en repli
/// (webm/opus, webm, ogg — AudioEncoder.opus). Détection de CAPACITÉ,
/// jamais de plateforme : un Safari qui gagnerait un jour le support webm
/// (ou l'inverse) reste couvert sans changement de code.
const webAudioMimeTypeCandidates = [
  'audio/mp4',
  'audio/aac',
  'audio/webm;codecs=opus',
  'audio/webm',
  'audio/ogg',
];

/// Premier type de [webAudioMimeTypeCandidates] pour lequel [isTypeSupported]
/// renvoie `true`, ou `null` si aucun ne l'est — seul cas réaliste : Safari
/// iOS antérieur à 14.3, qui n'implémentait pas du tout MediaRecorder. Pure
/// — [isTypeSupported] est injecté (voir platform/web_media_recorder.dart
/// pour le seul appelant réel) pour rester testable sans navigateur.
String? pickSupportedAudioMimeType(bool Function(String) isTypeSupported) {
  for (final type in webAudioMimeTypeCandidates) {
    if (isTypeSupported(type)) return type;
  }
  return null;
}

/// Codec `record` (voir AudioEncoder) à utiliser pour un type MIME Web
/// détecté par [pickSupportedAudioMimeType], avec le type MIME à annoncer
/// pour l'upload et l'extension de fichier associée — voir
/// backend/src/lib/transcription.ts (EXTENSION_TO_MIME) et
/// KIND_CONFIG.rexAudio (backend/src/routes/uploads.ts), déjà alignés sur
/// `audio/mp4`/`audio/webm`/`audio/ogg`.
class WebAudioCodec {
  final AudioEncoder encoder;
  final String uploadMimeType;
  final String extension;
  const WebAudioCodec({required this.encoder, required this.uploadMimeType, required this.extension});
}

/// `null` si [mimeType] est `null` (aucun type supporté, voir
/// [pickSupportedAudioMimeType]). `audio/aac` (flux ADTS brut, sans
/// conteneur) est volontairement regroupé avec `audio/mp4` : les annoncer
/// tous deux comme `audio/mp4` évite un type non couvert par
/// EXTENSION_TO_MIME côté backend (repli silencieux sur `audio/webm`, faux
/// pour un fichier AAC) — ce cas ADTS-brut-sans-MP4 n'a de toute façon
/// jamais été observé sur un navigateur réel supportant par ailleurs
/// `audio/mp4;codecs=...`.
WebAudioCodec? webAudioCodecFor(String? mimeType) {
  switch (mimeType) {
    case 'audio/mp4':
    case 'audio/aac':
      return const WebAudioCodec(encoder: AudioEncoder.aacLc, uploadMimeType: 'audio/mp4', extension: 'm4a');
    case 'audio/webm;codecs=opus':
    case 'audio/webm':
      return const WebAudioCodec(encoder: AudioEncoder.opus, uploadMimeType: 'audio/webm', extension: 'webm');
    case 'audio/ogg':
      return const WebAudioCodec(encoder: AudioEncoder.opus, uploadMimeType: 'audio/ogg', extension: 'ogg');
    default:
      return null;
  }
}

/// Capture une note vocale et la renvoie en data URL base64, prête à être
/// mise en file d'attente hors-ligne (PendingOperations) — ce fichier n'a
/// besoin d'envoyer que l'audio (ou un texte saisi) : la transcription
/// automatique tourne ensuite côté serveur si la reconnaissance vocale en
/// direct de l'app (voir rex_screen.dart) n'a rien donné (voir
/// backend/src/lib/transcription.ts).
class VoiceRecorder {
  final _recorder = AudioRecorder();
  String? _path;
  // Valeur par défaut : conteneur natif OGG/Opus utilisé hors Web (voir
  // stopAndEncode) — écrasée en cas de démarrage Web par le codec réellement
  // choisi (voir start()).
  String _uploadMimeType = 'audio/ogg';

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

    var encoder = AudioEncoder.opus;
    if (kIsWeb) {
      // Détection de CAPACITÉ, jamais de plateforme (voir doc de
      // webAudioMimeTypeCandidates) — sans ce choix, l'app forçait toujours
      // AudioEncoder.opus (webm/opus), que Safari/iOS ne supporte pas :
      // record_web échouait alors en interne (voir sa propre gestion
      // d'erreur) SANS jamais faire remonter d'exception jusqu'ici, ce qui
      // laissait croire que l'enregistrement avait démarré alors qu'aucun
      // son n'était capté — le micro semblait "fonctionner" puis
      // l'enregistrement échouait silencieusement à l'arrêt.
      final mimeType = pickSupportedAudioMimeType(isAudioMimeTypeSupported);
      final codec = webAudioCodecFor(mimeType);
      if (codec == null) return VoiceRecorderStartResult.unsupported;
      encoder = codec.encoder;
      _uploadMimeType = codec.uploadMimeType;
      _path = 'rex-${DateTime.now().millisecondsSinceEpoch}.${codec.extension}';
    } else {
      // Contrairement au Web, `record` écrit ici un vrai fichier sur mobile
      // : il faut un chemin absolu vers un répertoire accessible en
      // écriture (un nom de fichier relatif seul faisait échouer
      // l'enregistrement — message "Micro indisponible" trompeur, alors
      // que la permission était en réalité accordée).
      final dir = await getTemporaryDirectory();
      _path = '${dir.path}/rex-${DateTime.now().millisecondsSinceEpoch}.ogg';
      _uploadMimeType = 'audio/ogg';
    }

    try {
      // Mono 16 kHz : la voix captée par un micro de téléphone n'a besoin ni
      // de stéréo ni d'un échantillonnage plus élevé — Whisper travaille de
      // toute façon en interne à 16 kHz mono, quel que soit l'encodeur — et
      // ça réduit d'autant la taille envoyée sur le réseau.
      await _recorder.start(
        RecordConfig(encoder: encoder, sampleRate: 16000, numChannels: 1),
        path: _path!,
      );
      // record_web peut échouer en interne (encodeur non supporté, micro
      // refusé...) sans jamais lever d'exception jusqu'ici (voir le
      // commentaire ci-dessus) — vérifier explicitement l'état évite de
      // renvoyer `started` pour un enregistrement qui n'a en réalité jamais
      // démarré.
      if (!await _recorder.isRecording()) return VoiceRecorderStartResult.error;
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
        // _uploadMimeType reflète le codec réellement choisi au démarrage
        // (voir start()) — jamais figé à webm, qu'un navigateur Safari/iOS
        // n'a de toute façon jamais produit.
        final response = await http.get(Uri.parse(pathOrBlobUrl));
        return 'data:$_uploadMimeType;base64,${base64Encode(response.bodyBytes)}';
      }
      final bytes = await file_io.readVoiceRecorderFile(pathOrBlobUrl);
      return 'data:$_uploadMimeType;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('VoiceRecorder.stopAndEncode: $e');
      return null;
    }
  }

  void dispose() => _recorder.dispose();
}
