import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/jwt.dart';

String _encodeSegment(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

String _fakeJwt(Map<String, dynamic> payload) {
  final header = _encodeSegment({'alg': 'HS256', 'typ': 'JWT'});
  final body = _encodeSegment(payload);
  return '$header.$body.fake-signature';
}

void main() {
  group('jwtExpiry', () {
    test('lit le claim exp et le convertit en DateTime', () {
      final exp = DateTime(2030, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final token = _fakeJwt({'exp': exp});
      expect(jwtExpiry(token), DateTime.fromMillisecondsSinceEpoch(exp * 1000));
    });

    test('renvoie null si le jeton n\'a pas 3 parties', () {
      expect(jwtExpiry('pas-un-jwt'), isNull);
    });

    test('renvoie null si le payload n\'est pas du JSON valide', () {
      expect(jwtExpiry('header.@@@invalide@@@.signature'), isNull);
    });

    test('renvoie null si le claim exp est absent', () {
      final token = _fakeJwt({'sub': 'user-1'});
      expect(jwtExpiry(token), isNull);
    });

    test('renvoie null si le claim exp n\'est pas un entier', () {
      final token = _fakeJwt({'exp': 'bientot'});
      expect(jwtExpiry(token), isNull);
    });
  });
}
