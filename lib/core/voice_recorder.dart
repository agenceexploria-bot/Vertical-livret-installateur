import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'platform/blob_reader.dart';
import 'platform/web_media_recorder.dart';
import 'voice_recorder_file_io.dart' if (dart.library.html) 'voice_recorder_file_web.dart' as file_io;

/// Résultat de [VoiceRecorder.stopAndEncode] : soit la note vocale encodée
/// ([dataUrl]), soit la raison précise de l'échec ([error]) — jamais les
/// deux. Remplace l'ancien retour `String?`, dont le seul `null` ne
/// distinguait aucune des étapes qui peuvent échouer (arrêt du micro,
/// lecture du blob, fichier vide...) : sans cette distinction, l'écran REX
/// ne pouvait afficher qu'un message générique, quelle que soit la cause
/// réelle (voir rex_screen.dart, diagnostic transcription REX mobile).
class VoiceEncodeResult {
  final String? dataUrl;
  final String? error;
  const VoiceEncodeResult.success(this.dataUrl) : error = null;
  const VoiceEncodeResult.failure(this.error) : dataUrl = null;
  bool get isSuccess => dataUrl != null;
}

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

  /// Trace de chaque étape franchie par le cycle start → stopAndEncode le
  /// plus récent — remise à zéro à chaque [start()]. Consultable sans
  /// brancher de console (voir le panneau "détails techniques" de
  /// rex_screen.dart) : c'est la seule fenêtre sur ce qui s'est réellement
  /// passé quand Tobi teste sur un téléphone qu'on ne peut pas déboguer à
  /// distance.
  final List<String> stepLog = [];

  void _log(String message) {
    stepLog.add(message);
    debugPrint('VoiceRecorder: $message');
  }

  Future<VoiceRecorderStartResult> start() async {
    stepLog.clear();
    // Sur Android 6+ et iOS, la déclaration dans le manifest/Info.plist ne
    // suffit pas : la permission doit être (re)demandée à l'exécution avant
    // chaque tentative d'accès au micro — sans ça, l'enregistrement échoue
    // silencieusement même quand RECORD_AUDIO est bien déclaré. Sur le Web,
    // permission_handler n'a pas d'équivalent utile ; `record` déclenche
    // directement l'invite native du navigateur (getUserMedia) via
    // hasPermission()/start() ci-dessous.
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (status.isPermanentlyDenied) {
        _log('permission micro refusée définitivement');
        return VoiceRecorderStartResult.permissionPermanentlyDenied;
      }
      if (!status.isGranted) {
        _log('permission micro refusée');
        return VoiceRecorderStartResult.permissionDenied;
      }
      _log('permission micro accordée');
    } else {
      try {
        // Safari/WebKit ne supporte pas la requête de permission "microphone"
        // via l'API Permissions du navigateur et lève une exception ici au
        // lieu de renvoyer simplement false (voir record_web) — plutôt que de
        // laisser cette erreur remonter telle quelle, on l'ignore et on tente
        // quand même le démarrage ci-dessous, qui déclenche lui-même l'invite
        // native du navigateur via getUserMedia.
        if (!await _recorder.hasPermission()) {
          _log('permission micro refusée (getUserMedia)');
          return VoiceRecorderStartResult.permissionDenied;
        }
        _log('permission micro accordée (getUserMedia)');
      } catch (e) {
        _log('hasPermission a levé, tentative de démarrage malgré tout — $e');
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
      if (codec == null) {
        _log('aucun format audio supporté par ce navigateur (MediaRecorder)');
        return VoiceRecorderStartResult.unsupported;
      }
      encoder = codec.encoder;
      _uploadMimeType = codec.uploadMimeType;
      _path = 'rex-${DateTime.now().millisecondsSinceEpoch}.${codec.extension}';
      _log('format retenu : $mimeType (upload en $_uploadMimeType)');
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
      if (!await _recorder.isRecording()) {
        _log('_recorder.start() n\'a pas démarré l\'enregistrement (isRecording=false)');
        return VoiceRecorderStartResult.error;
      }
      _log('enregistrement démarré');
      return VoiceRecorderStartResult.started;
    } catch (e) {
      _log('_recorder.start() a levé — $e');
      return VoiceRecorderStartResult.error;
    }
  }

  Future<VoiceEncodeResult> stopAndEncode() async {
    String? pathOrBlobUrl;
    try {
      // record_web (voir MediaRecorderDelegate.stop()) attend l'évènement
      // natif `onstop` du MediaRecorder pour compléter ce Future — s'il ne
      // se déclenche jamais (flakiness connue de l'implémentation
      // MediaRecorder de Safari/WebKit, en particulier sur un arrêt trop
      // rapproché du démarrage), l'attente ne se résout JAMAIS : ni
      // exception, ni log, le seul symptôme visible est un blocage
      // silencieux — exactement "Préparation de la note vocale..." figé à
      // l'écran (voir rex_screen.dart, _isEncoding). Ce timeout est le seul
      // filet de sécurité possible côté appelant : `record_web` n'expose
      // aucun moyen d'annuler cette attente lui-même.
      pathOrBlobUrl = await _recorder.stop().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log('arrêt du micro : aucune réponse après 5s (évènement "onstop" du MediaRecorder jamais déclenché ?) — abandon');
          return null;
        },
      );
    } catch (e) {
      _log('arrêt du micro : _recorder.stop() a levé — $e');
      return VoiceEncodeResult.failure('Impossible d\'arrêter l\'enregistrement : $e');
    }
    if (pathOrBlobUrl == null) {
      return const VoiceEncodeResult.failure('Le micro n\'a pas répondu à l\'arrêt de l\'enregistrement (délai dépassé).');
    }
    _log('arrêt du micro OK — $pathOrBlobUrl ($_uploadMimeType)');
    try {
      final Uint8List bytes;
      if (kIsWeb) {
        // Sur le Web, `record` renvoie une URL blob: résoluble via fetch
        // depuis la même page — c'est la cible prioritaire de cette PWA.
        // _uploadMimeType reflète le codec réellement choisi au démarrage
        // (voir start()) — jamais figé à webm, qu'un navigateur Safari/iOS
        // n'a de toute façon jamais produit.
        bytes = await _readBlobWithFallback(pathOrBlobUrl);
      } else {
        bytes = await file_io.readVoiceRecorderFile(pathOrBlobUrl);
        _log('lecture du fichier natif OK — ${bytes.length} octets');
      }
      // Un blob de quelques octets (ou 0) sur un enregistrement de plusieurs
      // secondes trahit une capture vide (conteneur audio sans données —
      // micro coupé trop tôt, permission retirée en cours d'enregistrement,
      // encodeur qui n'a jamais reçu de son...) plutôt qu'un problème
      // d'upload ou de transcription plus loin dans la chaîne — voir README
      // 4.6. Sans cette vérification, un audio vide était envoyé et accepté
      // tel quel, pour finir en "note vocale sans transcription" sans jamais
      // signaler la vraie cause.
      if (bytes.isEmpty) {
        _log('échec : audio vide (0 octet) — capture probablement interrompue avant la première donnée');
        return const VoiceEncodeResult.failure('L\'enregistrement est vide (0 octet) — réessayez en parlant plus longtemps après avoir appuyé sur le micro.');
      }
      return VoiceEncodeResult.success('data:$_uploadMimeType;base64,${base64Encode(bytes)}');
    } catch (e) {
      _log('échec de lecture de l\'audio enregistré — $e');
      return VoiceEncodeResult.failure('Impossible de lire la note vocale enregistrée : $e');
    }
  }

  /// Lecture principale (http.get, basé sur fetch() côté navigateur) avec
  /// repli automatique en XMLHttpRequest si elle échoue ou renvoie un
  /// résultat vide — cas connu comme fragile sur certaines versions de
  /// Safari/WebKit pour un blob: URL (voir blob_reader_web.dart). Ne
  /// remplace jamais silencieusement l'une par l'autre sans le journaliser :
  /// si le repli est celui qui a fini par marcher, c'est un indice clé pour
  /// le prochain diagnostic.
  Future<Uint8List> _readBlobWithFallback(String blobUrl) async {
    try {
      final response = await http.get(Uri.parse(blobUrl));
      if (response.bodyBytes.isNotEmpty) {
        _log('lecture du blob (http.get) OK — ${response.bodyBytes.length} octets');
        return response.bodyBytes;
      }
      _log('lecture du blob (http.get) : résultat vide, tentative de repli en XMLHttpRequest');
    } catch (e) {
      _log('lecture du blob (http.get) a levé — $e — tentative de repli en XMLHttpRequest');
    }
    try {
      final bytes = await readBlobUrlViaXhr(blobUrl);
      _log('lecture du blob (repli XMLHttpRequest) OK — ${bytes.length} octets');
      return bytes;
    } catch (e) {
      _log('lecture du blob (repli XMLHttpRequest) a aussi levé — $e');
      rethrow;
    }
  }

  void dispose() => _recorder.dispose();
}
