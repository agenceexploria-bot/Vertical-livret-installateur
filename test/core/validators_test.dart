import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/validators.dart';

void main() {
  group('isValidEmail', () {
    test('accepte une adresse email valide', () {
      expect(isValidEmail('jean.dupont@exemple.fr'), isTrue);
    });

    test('accepte une adresse avec des espaces en bordure', () {
      expect(isValidEmail('  jean.dupont@exemple.fr  '), isTrue);
    });

    test('refuse une chaîne sans arobase', () {
      expect(isValidEmail('jean.dupont.exemple.fr'), isFalse);
    });

    test('refuse une chaîne sans domaine', () {
      expect(isValidEmail('jean.dupont@'), isFalse);
    });

    test('refuse une chaîne avec un espace au milieu', () {
      expect(isValidEmail('jean dupont@exemple.fr'), isFalse);
    });

    test('refuse une chaîne vide', () {
      expect(isValidEmail(''), isFalse);
    });
  });
}
