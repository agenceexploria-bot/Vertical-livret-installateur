import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:vertical_app/core/voice_recorder.dart';

/// Simule MediaRecorder.isTypeSupported du navigateur — [supported] contient
/// les types considérés supportés, tous les autres renvoient `false`.
bool Function(String) _isTypeSupportedAmong(Set<String> supported) => (type) => supported.contains(type);

void main() {
  group('pickSupportedAudioMimeType', () {
    test('choisit audio/mp4 quand Safari/iOS le supporte (priorité iOS d\'abord)', () {
      final isSupported = _isTypeSupportedAmong({'audio/mp4', 'audio/aac'});
      expect(pickSupportedAudioMimeType(isSupported), 'audio/mp4');
    });

    test('retombe sur audio/aac si seul ce type est supporté', () {
      final isSupported = _isTypeSupportedAmong({'audio/aac'});
      expect(pickSupportedAudioMimeType(isSupported), 'audio/aac');
    });

    test('retombe sur audio/webm;codecs=opus pour un navigateur desktop typique (Chrome/Firefox)', () {
      final isSupported = _isTypeSupportedAmong({'audio/webm;codecs=opus', 'audio/webm'});
      expect(pickSupportedAudioMimeType(isSupported), 'audio/webm;codecs=opus');
    });

    test('retombe sur audio/webm si seul ce type (sans codec explicite) est supporté', () {
      final isSupported = _isTypeSupportedAmong({'audio/webm'});
      expect(pickSupportedAudioMimeType(isSupported), 'audio/webm');
    });

    test('retombe en dernier recours sur audio/ogg', () {
      final isSupported = _isTypeSupportedAmong({'audio/ogg'});
      expect(pickSupportedAudioMimeType(isSupported), 'audio/ogg');
    });

    test('préfère toujours audio/mp4 même quand webm/opus est aussi supporté (iOS d\'abord, desktop ensuite)', () {
      final isSupported = _isTypeSupportedAmong({'audio/webm;codecs=opus', 'audio/mp4', 'audio/aac'});
      expect(pickSupportedAudioMimeType(isSupported), 'audio/mp4');
    });

    test('renvoie null si aucun type audio n\'est supporté (Safari iOS antérieur à 14.3)', () {
      final isSupported = _isTypeSupportedAmong({});
      expect(pickSupportedAudioMimeType(isSupported), isNull);
    });
  });

  group('webAudioCodecFor', () {
    test('audio/mp4 -> AudioEncoder.aacLc, uploadé en audio/mp4, extension m4a', () {
      final codec = webAudioCodecFor('audio/mp4')!;
      expect(codec.encoder, AudioEncoder.aacLc);
      expect(codec.uploadMimeType, 'audio/mp4');
      expect(codec.extension, 'm4a');
    });

    test('audio/aac -> AudioEncoder.aacLc, uploadé en audio/mp4 (jamais audio/aac brut)', () {
      final codec = webAudioCodecFor('audio/aac')!;
      expect(codec.encoder, AudioEncoder.aacLc);
      expect(codec.uploadMimeType, 'audio/mp4');
    });

    test('audio/webm;codecs=opus -> AudioEncoder.opus, uploadé en audio/webm', () {
      final codec = webAudioCodecFor('audio/webm;codecs=opus')!;
      expect(codec.encoder, AudioEncoder.opus);
      expect(codec.uploadMimeType, 'audio/webm');
      expect(codec.extension, 'webm');
    });

    test('audio/webm -> AudioEncoder.opus, uploadé en audio/webm', () {
      final codec = webAudioCodecFor('audio/webm')!;
      expect(codec.encoder, AudioEncoder.opus);
      expect(codec.uploadMimeType, 'audio/webm');
    });

    test('audio/ogg -> AudioEncoder.opus, uploadé en audio/ogg', () {
      final codec = webAudioCodecFor('audio/ogg')!;
      expect(codec.encoder, AudioEncoder.opus);
      expect(codec.uploadMimeType, 'audio/ogg');
      expect(codec.extension, 'ogg');
    });

    test('null en entrée -> null (aucun type supporté)', () {
      expect(webAudioCodecFor(null), isNull);
    });
  });
}
