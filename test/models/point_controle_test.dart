import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/point_controle.dart';

void main() {
  group('PointControle.isComplete', () {
    test('is false when status is vide', () {
      final p = PointControle(id: '1', libelle: 'Test');
      expect(p.isComplete, isFalse);
    });

    test('is true when conforme, even without a photo', () {
      final p = PointControle(id: '1', libelle: 'Test', status: PointStatus.conforme);
      expect(p.isComplete, isTrue);
    });

    test('is false when nonConforme without a photo (anomalie non prouvée)', () {
      final p = PointControle(id: '1', libelle: 'Test', status: PointStatus.nonConforme);
      expect(p.isComplete, isFalse);
    });

    test('is true when nonConforme with a photo attached', () {
      final p = PointControle(id: '1', libelle: 'Test', status: PointStatus.nonConforme, photoPath: 'photo.jpg');
      expect(p.isComplete, isTrue);
    });
  });

  group('PointControle.fromJson', () {
    test('parses status and photoPath', () {
      final p = PointControle.fromJson({
        'id': 'p1',
        'libelle': 'État des colis',
        'photoRequise': true,
        'status': 'conforme',
        'photoPath': 'photo.jpg',
      });
      expect(p.status, PointStatus.conforme);
      expect(p.isComplete, isTrue);
    });
  });
}
