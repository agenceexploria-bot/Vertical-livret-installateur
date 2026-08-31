import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/api_client.dart';

void main() {
  group('buildUploadsCallbackUrl', () {
    test('préfixe avec l\'origine quand elle est connue', () {
      final result = buildUploadsCallbackUrl(baseUrl: '/api', origin: 'https://vertical-livret-installateur.vercel.app');
      expect(result, 'https://vertical-livret-installateur.vercel.app/api/uploads/token');
    });

    test('reste relatif (mode dégradé) si origin est null', () {
      final result = buildUploadsCallbackUrl(baseUrl: '/api', origin: null);
      expect(result, '/api/uploads/token');
    });

    test('reste relatif (mode dégradé) si origin est une chaîne vide', () {
      final result = buildUploadsCallbackUrl(baseUrl: '/api', origin: '');
      expect(result, '/api/uploads/token');
    });

    test('fonctionne aussi avec un baseUrl déjà absolu (mobile/dev)', () {
      final result = buildUploadsCallbackUrl(baseUrl: 'http://localhost:3000', origin: null);
      expect(result, 'http://localhost:3000/uploads/token');
    });
  });
}
