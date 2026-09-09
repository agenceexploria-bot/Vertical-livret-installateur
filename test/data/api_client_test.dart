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

  group('isOfflineRetryable', () {
    test('true uniquement pour ApiException.network (absence réelle de réponse HTTP)', () {
      expect(isOfflineRetryable(ApiException.network('Erreur réseau.')), isTrue);
    });

    test('false pour un ApiException avec un vrai code HTTP (le serveur a répondu et rejeté)', () {
      expect(isOfflineRetryable(ApiException(403, 'Type de fichier refusé.')), isFalse);
    });

    test('false pour un ApiException(0, ...) qui n\'est PAS marqué réseau (ex. data URL mal formée)', () {
      // Avant isOfflineRetryable, statusCode == 0 seul était utilisé comme
      // critère — ambigu, puisqu'une erreur de validation locale (pas de
      // vrai code HTTP disponible) utilise aussi 0 sans être un cas
      // hors-ligne légitime à rejouer indéfiniment.
      expect(isOfflineRetryable(ApiException(0, 'Fichier invalide.')), isFalse);
    });

    test('false pour une exception qui n\'est même pas un ApiException (bug client)', () {
      expect(isOfflineRetryable(FormatException('inattendu')), isFalse);
    });
  });
}
