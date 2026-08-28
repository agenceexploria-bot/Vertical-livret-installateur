import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/blob_filename.dart';

void main() {
  group('sanitizeBlobFilename', () {
    test('retire les accents et met en minuscule', () {
      final result = sanitizeBlobFilename('Dossier_conception_MBO3.pdf');
      expect(result, matches(RegExp(r'^dossier-conception-mbo3-\d+-\d+\.pdf$')));
    });

    test('remplace les espaces, tirets cadratins et points médians', () {
      final result = sanitizeBlobFilename('CDC v0.2 — Livret Installateur Digital · MBO2.pdf');
      expect(result, matches(RegExp(r'^cdc-v0-2-livret-installateur-digital-mbo2-\d+-\d+\.pdf$')));
    });

    test('translittère les caractères accentués français', () {
      final result = sanitizeBlobFilename('Réception installation été.pdf');
      expect(result, matches(RegExp(r'^reception-installation-ete-\d+-\d+\.pdf$')));
    });

    test('ne contient que des caractères ASCII sûrs', () {
      final result = sanitizeBlobFilename('Plan étage n°2 (final) – copie.pdf');
      expect(result, matches(RegExp(r'^[a-z0-9-]+\.pdf$')));
    });

    test('deux fichiers de même nom obtiennent des chemins différents', () {
      final a = sanitizeBlobFilename('rapport.pdf');
      final b = sanitizeBlobFilename('rapport.pdf');
      expect(a, isNot(equals(b)));
    });

    test('conserve une extension inconnue si elle est alphanumérique courte', () {
      final result = sanitizeBlobFilename('video.webm');
      expect(result, endsWith('.webm'));
    });

    test('ignore une extension trop longue ou invalide', () {
      final result = sanitizeBlobFilename('fichier.sans-extension-valide');
      expect(result, isNot(contains('.sans-extension-valide')));
    });

    test('gère un nom sans extension', () {
      final result = sanitizeBlobFilename('documentChantier');
      expect(result, matches(RegExp(r'^documentchantier-\d+-\d+$')));
    });

    test('retombe sur un nom par défaut si le nom nettoyé est vide', () {
      final result = sanitizeBlobFilename('°°°.pdf');
      expect(result, matches(RegExp(r'^fichier-\d+-\d+\.pdf$')));
    });
  });
}
