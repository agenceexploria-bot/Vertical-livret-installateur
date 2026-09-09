// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Repli de lecture d'un blob: URL en octets via une XMLHttpRequest classique
/// — un chemin de code distinct de http.get (basé sur fetch() côté
/// navigateur depuis package:http 1.x, voir VoiceRecorder.stopAndEncode).
/// XMLHttpRequest reste historiquement plus tolérant que fetch() pour lire
/// un blob: URL sur certaines versions de Safari/WebKit — utilisé en repli
/// automatique quand la lecture principale échoue ou renvoie un résultat
/// vide.
Future<Uint8List> readBlobUrlViaXhr(String blobUrl) {
  final completer = Completer<Uint8List>();
  final xhr = web.XMLHttpRequest();
  xhr.responseType = 'arraybuffer';

  void onLoad(web.Event event) {
    final status = xhr.status;
    // status 0 : requête locale (blob:, file:) sans code HTTP réel — un
    // succès malgré tout, contrairement à un vrai 0 réseau qui n'atteint
    // jamais ce gestionnaire (voir onError ci-dessous).
    if (status != 0 && (status < 200 || status >= 300)) {
      completer.completeError(Exception('XHR sur blob: URL — statut HTTP $status'));
      return;
    }
    final buffer = xhr.response as JSArrayBuffer?;
    if (buffer == null) {
      completer.completeError(Exception('XHR sur blob: URL — réponse vide ou de type inattendu'));
      return;
    }
    completer.complete(buffer.toDart.asUint8List());
  }

  void onError(web.Event event) {
    completer.completeError(Exception('XHR sur blob: URL — erreur réseau'));
  }

  xhr.addEventListener('load', onLoad.toJS);
  xhr.addEventListener('error', onError.toJS);
  xhr.open('GET', blobUrl);
  xhr.send();
  return completer.future;
}
