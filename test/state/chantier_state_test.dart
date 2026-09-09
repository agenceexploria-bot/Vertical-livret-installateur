import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/state/chantier_state.dart';

Chantier _chantier(String reference, {bool pvSigne = false, DateTime? pvSigneAt}) => Chantier(
      reference: reference,
      client: 'Client $reference',
      adresse: '1 rue Test',
      ville: 'Testville',
      dateDebut: DateTime(2026, 1, 1),
      dateFin: DateTime(2026, 1, 3),
      contactNom: 'M. Test',
      contactTel: '0600000000',
      horaires: '8h-17h',
      consignes: const [],
      typeMonteCharge: 'Monte-charge',
      capacite: '300 kg',
      niveaux: 2,
      referenceAffaire: 'AF-$reference',
      receptionMarchandises: const [],
      autoControle: const [],
      pvSigne: pvSigne,
      pvSigneAt: pvSigneAt,
    );

void main() {
  group('chantiersEnCours', () {
    test('ne garde que les chantiers dont le PV n\'est pas signé — répartition correcte sur une liste mixte', () {
      final chantiers = [
        _chantier('A', pvSigne: false),
        _chantier('B', pvSigne: true, pvSigneAt: DateTime(2026, 2, 1)),
        _chantier('C', pvSigne: false),
      ];

      final result = chantiersEnCours(chantiers);

      expect(result.map((c) => c.reference), ['A', 'C']);
    });

    test('conserve l\'ordre existant de la liste (comportement actuel, non modifié)', () {
      final chantiers = [_chantier('C', pvSigne: false), _chantier('A', pvSigne: false), _chantier('B', pvSigne: false)];

      final result = chantiersEnCours(chantiers);

      expect(result.map((c) => c.reference), ['C', 'A', 'B']);
    });

    test('compteur exact : liste vide -> 0, aucun signé -> longueur totale', () {
      expect(chantiersEnCours([]), isEmpty);
      final chantiers = [_chantier('A'), _chantier('B'), _chantier('C')];
      expect(chantiersEnCours(chantiers), hasLength(3));
    });
  });

  group('chantiersTermines', () {
    test('ne garde que les chantiers avec le PV signé — répartition correcte sur une liste mixte', () {
      final chantiers = [
        _chantier('A', pvSigne: false),
        _chantier('B', pvSigne: true, pvSigneAt: DateTime(2026, 2, 1)),
        _chantier('C', pvSigne: true, pvSigneAt: DateTime(2026, 3, 1)),
      ];

      final result = chantiersTermines(chantiers);

      expect(result.map((c) => c.reference), unorderedEquals(['B', 'C']));
    });

    test('trie par date de signature décroissante (le plus récent en premier)', () {
      final chantiers = [
        _chantier('ancien', pvSigne: true, pvSigneAt: DateTime(2026, 1, 1)),
        _chantier('recent', pvSigne: true, pvSigneAt: DateTime(2026, 6, 1)),
        _chantier('intermediaire', pvSigne: true, pvSigneAt: DateTime(2026, 3, 1)),
      ];

      final result = chantiersTermines(chantiers);

      expect(result.map((c) => c.reference), ['recent', 'intermediaire', 'ancien']);
    });

    test('un PV signé sans pvSigneAt (donnée incohérente) ne plante pas — classé en dernier', () {
      final chantiers = [
        _chantier('avecDate', pvSigne: true, pvSigneAt: DateTime(2026, 1, 1)),
        _chantier('sansDate', pvSigne: true, pvSigneAt: null),
      ];

      final result = chantiersTermines(chantiers);

      expect(result.map((c) => c.reference), ['avecDate', 'sansDate']);
    });

    test('compteur exact : liste vide -> 0, tous signés -> longueur totale', () {
      expect(chantiersTermines([]), isEmpty);
      final chantiers = [_chantier('A', pvSigne: true), _chantier('B', pvSigne: true)];
      expect(chantiersTermines(chantiers), hasLength(2));
    });
  });

  group('passage automatique En cours <-> Terminés (dérivé de pvSigne, aucun statut manuel)', () {
    test('un chantier passe de "En cours" à "Terminés" quand pvSigne devient true (signature du PV)', () {
      final chantier = _chantier('LD1', pvSigne: false);
      final chantiers = [chantier];

      expect(chantiersEnCours(chantiers).map((c) => c.reference), ['LD1']);
      expect(chantiersTermines(chantiers), isEmpty);

      chantier.pvSigne = true;
      chantier.pvSigneAt = DateTime(2026, 5, 1);

      expect(chantiersEnCours(chantiers), isEmpty);
      expect(chantiersTermines(chantiers).map((c) => c.reference), ['LD1']);
    });

    test('un chantier repasse de "Terminés" à "En cours" quand le PV est supprimé (pvSigne redevient false)', () {
      final chantier = _chantier('LD2', pvSigne: true, pvSigneAt: DateTime(2026, 5, 1));
      final chantiers = [chantier];

      expect(chantiersTermines(chantiers).map((c) => c.reference), ['LD2']);
      expect(chantiersEnCours(chantiers), isEmpty);

      // Suppression du PV (voir ChantierRepository.deletePv côté backend) :
      // pvSigne redevient false, pvSigneAt est effacé.
      chantier.pvSigne = false;
      chantier.pvSigneAt = null;

      expect(chantiersTermines(chantiers), isEmpty);
      expect(chantiersEnCours(chantiers).map((c) => c.reference), ['LD2']);
    });
  });
}
