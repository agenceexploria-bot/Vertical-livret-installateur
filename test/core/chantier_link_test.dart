import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/chantier_link.dart';

void main() {
  group('chantierLinkUrl', () {
    test('construit l\'URL exacte transmise au presse-papier — origine + hash + référence', () {
      final url = chantierLinkUrl(origin: 'https://vertical-livret-installateur.vercel.app', reference: 'LD70850');
      expect(url, 'https://vertical-livret-installateur.vercel.app/#/chantier/LD70850');
    });

    test('fonctionne avec une origine de dev (localhost)', () {
      final url = chantierLinkUrl(origin: 'http://localhost:3000', reference: 'LD70850');
      expect(url, 'http://localhost:3000/#/chantier/LD70850');
    });
  });
}
