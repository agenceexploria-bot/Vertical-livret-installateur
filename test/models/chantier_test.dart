import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/data/models/point_controle.dart';

Map<String, dynamic> _baseJson({
  List<Map<String, dynamic>> reception = const [],
  List<Map<String, dynamic>> autoControle = const [],
  bool pvSigne = false,
}) {
  return {
    'reference': 'LD64397',
    'client': 'Costockage',
    'adresse': '4 rue des Frères Lumière',
    'ville': 'Meyzieu (69)',
    'dateDebut': '2026-07-21T00:00:00.000Z',
    'dateFin': '2026-07-23T00:00:00.000Z',
    'contactNom': 'M. Weber',
    'contactTel': '0612345678',
    'horaires': '6h30-17h00',
    'consignes': ['Badge obligatoire'],
    'typeMonteCharge': 'Monte-charge non accompagné',
    'capacite': '300 kg',
    'niveaux': 2,
    'referenceAffaire': 'AF-2026-001',
    'syncStatus': 'charge',
    'rex': [],
    'pvSigne': pvSigne,
    'livretsOuverts': [],
    'receptionMarchandises': reception,
    'autoControle': autoControle,
    'installateursRattaches': [],
    'docsTerrain': [],
  };
}

Map<String, dynamic> _point(String id, {String status = 'vide', String? photoPath}) => {
      'id': id,
      'libelle': 'Point $id',
      'photoRequise': true,
      'status': status,
      'photoPath': photoPath,
    };

void main() {
  group('Chantier.fromJson', () {
    test('parses basic fields and dates', () {
      final chantier = Chantier.fromJson(_baseJson());
      expect(chantier.reference, 'LD64397');
      expect(chantier.dateDebut, DateTime.parse('2026-07-21T00:00:00.000Z'));
      expect(chantier.consignes, ['Badge obligatoire']);
    });
  });

  group('progression', () {
    test('is 0 when there are no points', () {
      final chantier = Chantier.fromJson(_baseJson());
      expect(chantier.progressionReception, 0);
    });

    test('reflects the ratio of complete points', () {
      final chantier = Chantier.fromJson(_baseJson(
        reception: [
          _point('r1', status: 'conforme', photoPath: 'p.jpg'),
          _point('r2'),
        ],
      ));
      expect(chantier.progressionReception, 0.5);
    });
  });

  group('Chantier.toJson', () {
    // La mise à jour optimiste hors-ligne (ChantierRepository) relit le
    // cache via fromJson, mute l'objet, puis le réécrit via toJson — un
    // aller-retour infidèle romprait silencieusement le cache local.
    test('round-trips through fromJson without losing mutated fields', () {
      final original = Chantier.fromJson(_baseJson(
        reception: [_point('r1', status: 'vide')],
        pvSigne: false,
      ));

      original.receptionMarchandises.first.status = PointStatus.conforme;
      original.receptionMarchandises.first.photoPath = 'data:image/jpeg;base64,abc';
      original.receptionMarchandises.first.validePar = 'Thomas Roux';
      original.rex.add(Rex(id: 'r1', transcription: 'RAS', soumisAt: DateTime.parse('2026-07-22T10:00:00.000Z')));
      original.pvSigne = true;
      original.pvSigneur = 'M. Weber';

      final roundTripped = Chantier.fromJson(original.toJson());

      expect(roundTripped.receptionMarchandises.first.status, PointStatus.conforme);
      expect(roundTripped.receptionMarchandises.first.photoPath, 'data:image/jpeg;base64,abc');
      expect(roundTripped.receptionMarchandises.first.validePar, 'Thomas Roux');
      expect(roundTripped.rex, hasLength(1));
      expect(roundTripped.rex.first.transcription, 'RAS');
      expect(roundTripped.pvSigne, isTrue);
      expect(roundTripped.pvSigneur, 'M. Weber');
    });
  });
}
