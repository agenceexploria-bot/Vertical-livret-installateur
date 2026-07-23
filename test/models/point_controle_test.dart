import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/point_controle.dart';

void main() {
  group('PointControle.isComplete', () {
    test('is false when status is vide', () {
      final p = PointControle(id: '1', libelle: 'Test');
      expect(p.isComplete, isFalse);
    });

    test('is false when conforme but photo required and missing', () {
      final p = PointControle(id: '1', libelle: 'Test', status: PointStatus.conforme);
      expect(p.photoRequise, isTrue);
      expect(p.isComplete, isFalse);
    });

    test('is true when conforme with photo attached', () {
      final p = PointControle(id: '1', libelle: 'Test', status: PointStatus.conforme, photoPath: 'photo.jpg');
      expect(p.isComplete, isTrue);
    });

    test('does not require a photo when photoRequise is false', () {
      final p = PointControle(id: '1', libelle: 'Test', photoRequise: false, status: PointStatus.nonConforme);
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
