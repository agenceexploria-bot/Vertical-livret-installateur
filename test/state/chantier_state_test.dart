import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/api_client.dart';
import 'package:vertical_app/data/local/app_database.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/data/repositories/chantier_repository.dart';
import 'package:vertical_app/state/chantier_state.dart';

/// Doublure de ApiClient.getChantier — voir ChantierState.loadChantierByReference
/// (lien direct WhatsApp/SMS vers un chantier, voir "Copier le lien" dans
/// bo_chantier_detail_screen.dart).
class _GetChantierApiClient extends ApiClient {
  final Map<String, dynamic>? chantierJson;
  final Object? error;
  _GetChantierApiClient.success(this.chantierJson) : error = null;
  _GetChantierApiClient.failure(this.error) : chantierJson = null;

  @override
  Future<Map<String, dynamic>> getChantier(String reference) async {
    if (error != null) throw error!;
    return {'chantier': chantierJson};
  }
}

Chantier _chantier(String reference, {bool pvSigne = false, DateTime? pvSigneAt, ChantierType type = ChantierType.installation}) => Chantier(
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
      type: type,
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

  group('chantiersInstallation / chantiersSav (module SAV — deux tuiles de l\'accueil installateur)', () {
    test('sépare correctement une liste mixte installations/SAV', () {
      final chantiers = [
        _chantier('LD1', type: ChantierType.installation),
        _chantier('SAV-LD1-1', type: ChantierType.sav),
        _chantier('LD2', type: ChantierType.installation),
        _chantier('SAV-LD1-2', type: ChantierType.sav),
      ];

      expect(chantiersInstallation(chantiers).map((c) => c.reference), ['LD1', 'LD2']);
      expect(chantiersSav(chantiers).map((c) => c.reference), ['SAV-LD1-1', 'SAV-LD1-2']);
    });

    test('compteurs exacts (les tuiles affichent chantiersXList.length) : liste vide -> 0 des deux côtés', () {
      expect(chantiersInstallation([]), isEmpty);
      expect(chantiersSav([]), isEmpty);
    });

    test('un chantier sans champ type explicite (rétrocompatibilité) est classé installation par défaut', () {
      final chantier = Chantier.fromJson({
        'reference': 'LD_ANCIEN',
        'client': 'Client',
        'adresse': '1 rue',
        'ville': 'Ville',
        'dateDebut': '2026-01-01T00:00:00.000Z',
        'dateFin': '2026-01-02T00:00:00.000Z',
        'contactNom': 'M. Test',
        'contactTel': '0600000000',
        'horaires': '8h-17h',
        'consignes': [],
        'typeMonteCharge': 'Monte-charge',
        'capacite': '300 kg',
        'niveaux': 2,
        'referenceAffaire': 'AF-1',
        'rex': [],
        'livretsOuverts': [],
        'receptionMarchandises': [],
        'autoControle': [],
        'installateursRattaches': [],
        'docsTerrain': [],
      });

      expect(chantiersInstallation([chantier]).map((c) => c.reference), ['LD_ANCIEN']);
      expect(chantiersSav([chantier]), isEmpty);
    });
  });

  group('ChantierState.loadChantierByReference (lien direct WhatsApp/SMS vers un chantier)', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    // Répertoire temporaire dédié par test — voir chantier_repository_test.dart
    // (AppDatabase utilise toujours le même nom de fichier ; le partager
    // entre tests ferait fuiter les lignes de l'un vers l'autre).
    Future<AppDatabase> pumpDb() async {
      final dir = Directory.systemTemp.createTempSync('chantier_state_test');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => dir.path,
      );
      return AppDatabase();
    }

    test('succès : le chantier résolu devient currentChantier', () async {
      final db = await pumpDb();
      final json = _chantier('LD70850').toJson();
      final state = ChantierState(ChantierRepository(_GetChantierApiClient.success(json), db));

      await state.loadChantierByReference('LD70850');

      expect(state.currentChantier?.reference, 'LD70850');
    });

    test('installateur non rattaché (403) : relève l\'exception avec le message exact du backend — jamais un écran vide sans explication', () async {
      final db = await pumpDb();
      final exception = ApiException(403, 'Vous n\'êtes pas rattaché à ce chantier');
      final state = ChantierState(ChantierRepository(_GetChantierApiClient.failure(exception), db));

      await expectLater(
        () => state.loadChantierByReference('LD70850'),
        throwsA(same(exception)),
      );
      expect(state.currentChantier, isNull);
    });

    test('chantier introuvable (404) : relève l\'exception avec le message exact du backend', () async {
      final db = await pumpDb();
      final exception = ApiException(404, 'Chantier introuvable');
      final state = ChantierState(ChantierRepository(_GetChantierApiClient.failure(exception), db));

      await expectLater(
        () => state.loadChantierByReference('INEXISTANT'),
        throwsA(same(exception)),
      );
    });
  });
}
