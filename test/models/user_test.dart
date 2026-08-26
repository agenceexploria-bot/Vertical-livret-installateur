import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('parses a full installateur payload', () {
      final user = User.fromJson({
        'id': 'abc123',
        'nom': 'Roux',
        'prenom': 'Thomas',
        'mobile': '0652417890',
        'email': 't.roux@elevpro.fr',
        'role': 'installateur',
        'status': 'sousTraitant',
        'societe': "Elev'Pro",
        'isActive': true,
        'suspendu': false,
        'habilitations': [
          {'id': 'h1', 'titre': 'Habilitation électrique BR', 'dateExpiration': '2027-03-12T00:00:00.000Z'},
        ],
      });

      expect(user.fullName, 'Thomas Roux');
      expect(user.role, UserRole.installateur);
      expect(user.status, UserStatus.sousTraitant);
      expect(user.habilitations, hasLength(1));
      expect(user.habilitations.first.titre, 'Habilitation électrique BR');
    });

    test('defaults isActive/suspendu to false and handles null email/status', () {
      final user = User.fromJson({
        'id': 'abc123',
        'nom': 'Martin',
        'prenom': 'Sandrine',
        'mobile': '0102030405',
        'email': null,
        'role': 'coordinateurTravaux',
        'status': null,
      });

      expect(user.email, isNull);
      expect(user.status, isNull);
      expect(user.isActive, isFalse);
      expect(user.suspendu, isFalse);
    });
  });

  group('Habilitation', () {
    test('isExpired is true for a past date', () {
      final h = Habilitation(titre: 'Test', dateExpiration: DateTime.now().subtract(const Duration(days: 1)));
      expect(h.isExpired, isTrue);
    });

    test('expiresSoon is true within 30 days but not expired', () {
      final h = Habilitation(titre: 'Test', dateExpiration: DateTime.now().add(const Duration(days: 10)));
      expect(h.isExpired, isFalse);
      expect(h.expiresSoon, isTrue);
    });

    test('expiresSoon is false when far in the future', () {
      final h = Habilitation(titre: 'Test', dateExpiration: DateTime.now().add(const Duration(days: 365)));
      expect(h.expiresSoon, isFalse);
    });
  });
}
