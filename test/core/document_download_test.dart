import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/document_download.dart';

void main() {
  group('forceDownloadUri', () {
    test('ajoute download=1 à une URL sans paramètres — force Content-Disposition: attachment côté Vercel Blob', () {
      final uri = forceDownloadUri('https://blob.vercel-storage.com/pv-signe-abc.pdf');
      expect(uri.toString(), 'https://blob.vercel-storage.com/pv-signe-abc.pdf?download=1');
    });

    test('conserve les paramètres existants en ajoutant download=1', () {
      final uri = forceDownloadUri('https://blob.vercel-storage.com/pv-signe-abc.pdf?x-id=GET');
      expect(uri.queryParameters['x-id'], 'GET');
      expect(uri.queryParameters['download'], '1');
    });
  });
}
