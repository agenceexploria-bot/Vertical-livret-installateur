import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/collage_parser.dart';

void main() {
  group('CollageParser.parse — extraction de la ville', () {
    test('code postal + ville sur une ligne avec adresse', () {
      final parsed = CollageParser.parse('12 av. des Landes, 44800 Saint-Herblain');
      expect(parsed.ville, 'Saint-Herblain');
    });

    test('mot-clé "Ville" sans code postal', () {
      final parsed = CollageParser.parse('Ville SAINT-TRIVIER-DE-COURTES');
      expect(parsed.ville, 'SAINT-TRIVIER-DE-COURTES');
    });

    test('ville en plusieurs mots avec apostrophe', () {
      final parsed = CollageParser.parse("9 RUE DES PORTIERES, 49124 SAINT BARTHELEMY D'ANJOU");
      expect(parsed.ville, "SAINT BARTHELEMY D'ANJOU");
    });

    test('suffixe "Cedex" retiré', () {
      final parsed = CollageParser.parse('44800 Saint-Herblain Cedex');
      expect(parsed.ville, 'Saint-Herblain');
    });

    test('code postal + ville simple', () {
      final parsed = CollageParser.parse('75008 Paris');
      expect(parsed.ville, 'Paris');
    });

    test('code postal précédé d\'un "CS xxxxx" (boîte postale)', () {
      final parsed = CollageParser.parse('CS 10234, 35008 RENNES');
      expect(parsed.ville, 'RENNES');
    });

    test('suffixe "Cedex" suivi d\'un numéro retiré', () {
      final parsed = CollageParser.parse('44800 Saint-Herblain Cedex 2');
      expect(parsed.ville, 'Saint-Herblain');
    });

    test('suffixe "France" retiré', () {
      final parsed = CollageParser.parse('75008 Paris France');
      expect(parsed.ville, 'Paris');
    });

    test('aucun code postal ni mot-clé "Ville" — pas de faux positif', () {
      final parsed = CollageParser.parse('Transgourmet Ouest — 12 av. des Landes');
      expect(parsed.ville, isNull);
    });
  });

  group('CollageParser.parse — autres champs (non-régression)', () {
    test('extrait client, adresse, ville, contact, téléphone depuis un bloc ERP complet', () {
      final parsed = CollageParser.parse(
        'Transgourmet Ouest — 12 av. des Landes, 44800 Saint-Herblain — Resp. site : Mme Guillou 06 45 12 33 87',
      );
      expect(parsed.client, 'Transgourmet Ouest');
      expect(parsed.adresse, '12 av. des Landes');
      expect(parsed.ville, 'Saint-Herblain');
      expect(parsed.contact, 'Mme Guillou');
      expect(parsed.telephone, '06 45 12 33 87');
    });

    test('extrait un email', () {
      final parsed = CollageParser.parse('Contact : Jean Dupont — jean.dupont@exemple.fr');
      expect(parsed.email, 'jean.dupont@exemple.fr');
    });

    test('texte vide ne renvoie rien', () {
      final parsed = CollageParser.parse('   ');
      expect(parsed.client, isNull);
      expect(parsed.ville, isNull);
    });
  });
}
