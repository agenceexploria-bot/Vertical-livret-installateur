/// Hors Web (mobile/desktop natif) : `record` y utilise son encodeur natif
/// (voir voice_recorder.dart, branche `!kIsWeb`) — cette fonction n'est
/// jamais appelée sur ces plateformes, `false` reste un défaut inoffensif.
bool isAudioMimeTypeSupported(String type) => false;
