import 'dart:typed_data';

/// Hors Web : aucun blob: URL n'existe sur ces plateformes (voir
/// voice_recorder.dart, branche `!kIsWeb`, qui lit un vrai fichier via
/// voice_recorder_file_io.dart) — cette fonction n'est jamais appelée en
/// pratique.
Future<Uint8List> readBlobUrlViaXhr(String blobUrl) =>
    throw UnsupportedError('readBlobUrlViaXhr indisponible hors Web');
