import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/api_client.dart';
import 'package:vertical_app/data/local/app_database.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/data/repositories/chantier_repository.dart';

/// Flux complet mocké de submitRex : upload de l'audio -> postRex -> mise à
/// jour du chantier. Chaque doublure injecte un échec à une étape précise
/// (upload ou postRex) avec une cause différente (coupure réseau réelle vs
/// rejet serveur vs bug client inattendu) — voir diagnostic transcription
/// REX mobile : avant [isOfflineRetryable], TOUTE erreur ici finissait
/// dans la file d'attente hors-ligne avec un REX marqué "envoyé" en local,
/// qu'elle soit réseau ou non.
class _SuccessApiClient extends ApiClient {
  final Map<String, dynamic> chantierJson;
  _SuccessApiClient(this.chantierJson);

  @override
  Future<String> uploadFile({required String kind, required String dataUrl, String? filename}) async =>
      'https://blob.vercel-storage.com/rex-audio.webm';

  @override
  Future<Map<String, dynamic>> postRex(String reference, {String? transcription, String? audioUrl}) async =>
      {'chantier': chantierJson};
}

class _UploadFailsApiClient extends ApiClient {
  final Object error;
  _UploadFailsApiClient(this.error);

  @override
  Future<String> uploadFile({required String kind, required String dataUrl, String? filename}) async => throw error;
}

/// Module SAV — création d'une intervention SAV depuis le back-office (voir
/// ChantierRepository.createSav). Capture les arguments transmis pour
/// vérifier qu'ils sont bien propagés jusqu'à ApiClient.createSav.
class _CreateSavApiClient extends ApiClient {
  final Map<String, dynamic> chantierJson;
  final Object? error;
  String? lastReference;
  String? lastDescription;
  String? lastInstallateurId;
  String? lastSavDate;
  _CreateSavApiClient.success(this.chantierJson) : error = null;
  _CreateSavApiClient.failure(this.error) : chantierJson = const {};

  @override
  Future<Map<String, dynamic>> createSav(
    String reference, {
    required String descriptionProbleme,
    required String installateurId,
    String? savDate,
  }) async {
    lastReference = reference;
    lastDescription = descriptionProbleme;
    lastInstallateurId = installateurId;
    lastSavDate = savDate;
    if (error != null) throw error!;
    return {'chantier': chantierJson};
  }
}

class _PostRexFailsApiClient extends ApiClient {
  final Object error;
  _PostRexFailsApiClient(this.error);

  @override
  Future<String> uploadFile({required String kind, required String dataUrl, String? filename}) async =>
      'https://blob.vercel-storage.com/rex-audio.webm';

  @override
  Future<Map<String, dynamic>> postRex(String reference, {String? transcription, String? audioUrl}) async => throw error;
}

Map<String, dynamic> _baseChantierJson() => {
      'reference': 'LD64397',
      'client': 'Costockage',
      'adresse': '4 rue des Frères Lumière',
      'ville': 'Meyzieu (69)',
      'dateDebut': '2026-07-21T00:00:00.000Z',
      'dateFin': '2026-07-23T00:00:00.000Z',
      'contactNom': 'M. Weber',
      'contactTel': '0612345678',
      'horaires': '6h30-17h00',
      'consignes': <String>[],
      'typeMonteCharge': 'Monte-charge non accompagné',
      'capacite': '300 kg',
      'niveaux': 2,
      'referenceAffaire': 'AF-2026-001',
      'syncStatus': 'charge',
      'rex': <Map<String, dynamic>>[],
      'pvSigne': false,
      'livretsOuverts': <String>[],
      'receptionMarchandises': <Map<String, dynamic>>[],
      'autoControle': <Map<String, dynamic>>[],
      'installateursRattaches': <Map<String, dynamic>>[],
      'docsTerrain': <Map<String, dynamic>>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Répertoire temporaire dédié par test — voir auth_repository_test.dart
  // (AppDatabase utilise toujours le même nom de fichier ; le partager entre
  // tests ferait fuiter les lignes de l'un vers l'autre).
  Future<AppDatabase> pumpDb() async {
    final dir = Directory.systemTemp.createTempSync('chantier_repository_test');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => dir.path,
    );
    return AppDatabase();
  }

  group('ChantierRepository.submitRex', () {
    test('succès : upload puis postRex OK -> wasQueued=false, rien en file d\'attente', () async {
      final db = await pumpDb();
      final chantierJson = _baseChantierJson();
      final repository = ChantierRepository(_SuccessApiClient(chantierJson), db);

      final result = await repository.submitRex('LD64397', audio: 'data:audio/webm;base64,AAAA');

      expect(result.wasQueued, isFalse);
      expect(result.chantier.reference, 'LD64397');
      expect(await db.getPendingOperationsOrdered(), isEmpty);
    });

    test('coupure réseau réelle pendant l\'upload (ApiException.network) : mise en file d\'attente + optimiste', () async {
      final db = await pumpDb();
      await db.cacheChantier(_baseChantierJson());
      final repository = ChantierRepository(
        _UploadFailsApiClient(ApiException.network('Erreur réseau. Vérifiez votre connexion.')),
        db,
      );

      final result = await repository.submitRex('LD64397', audio: 'data:audio/webm;base64,AAAA');

      expect(result.wasQueued, isTrue);
      final pending = await db.getPendingOperationsOrdered();
      expect(pending, hasLength(1));
      expect(pending.single.type, 'submitRex');
      expect(result.chantier.rex, hasLength(1), reason: 'mise à jour optimiste locale attendue');
    });

    test('rejet serveur pendant l\'upload (type de fichier refusé) : relève l\'exception, ne met JAMAIS en file d\'attente', () async {
      final db = await pumpDb();
      await db.cacheChantier(_baseChantierJson());
      final exception = ApiException(403, 'Ce type de fichier n\'est pas autorisé ici.');
      final repository = ChantierRepository(_UploadFailsApiClient(exception), db);

      await expectLater(
        () => repository.submitRex('LD64397', audio: 'data:audio/webm;base64,AAAA'),
        throwsA(same(exception)),
      );

      expect(await db.getPendingOperationsOrdered(), isEmpty);
    });

    test('rejet serveur pendant postRex (ex. validation refusée) : relève l\'exception, ne met JAMAIS en file d\'attente', () async {
      final db = await pumpDb();
      await db.cacheChantier(_baseChantierJson());
      final exception = ApiException(400, 'Une transcription ou une note vocale est requise');
      final repository = ChantierRepository(_PostRexFailsApiClient(exception), db);

      await expectLater(
        () => repository.submitRex('LD64397', audio: 'data:audio/webm;base64,AAAA'),
        throwsA(same(exception)),
      );

      expect(await db.getPendingOperationsOrdered(), isEmpty);
    });

    test('bug client inattendu (exception qui n\'est pas un ApiException) : relève l\'exception, ne met JAMAIS en file d\'attente', () async {
      // Avant isOfflineRetryable, catch (_) mettait ICI aussi en file
      // d'attente avec un succès optimiste mensonger — exactement le bug
      // diagnostiqué : un REX qui échoue pour n'importe quelle raison
      // semblait "envoyé" sans jamais atteindre le serveur.
      final db = await pumpDb();
      await db.cacheChantier(_baseChantierJson());
      final repository = ChantierRepository(_UploadFailsApiClient(FormatException('data URL invalide')), db);

      await expectLater(
        () => repository.submitRex('LD64397', audio: 'data:audio/webm;base64,AAAA'),
        throwsA(isA<FormatException>()),
      );

      expect(await db.getPendingOperationsOrdered(), isEmpty);
    });
  });

  group('ChantierRepository.createSav', () {
    test('succès : transmet référence/description/installateur/date à ApiClient, renvoie le chantier SAV créé', () async {
      final db = await pumpDb();
      final savJson = {..._baseChantierJson(), 'reference': 'SAV-LD64397-1', 'type': 'sav', 'parentReference': 'LD64397'};
      final api = _CreateSavApiClient.success(savJson);
      final repository = ChantierRepository(api, db);

      final sav = await repository.createSav(
        'LD64397',
        descriptionProbleme: 'Bruit anormal en cabine',
        installateurId: 'user-1',
        savDate: DateTime.utc(2026, 9, 15),
      );

      expect(api.lastReference, 'LD64397');
      expect(api.lastDescription, 'Bruit anormal en cabine');
      expect(api.lastInstallateurId, 'user-1');
      expect(api.lastSavDate, '2026-09-15T00:00:00.000Z');
      expect(sav.reference, 'SAV-LD64397-1');
      expect(sav.type, ChantierType.sav);
      expect(sav.parentReference, 'LD64397');
    });

    test('savDate omise (optionnelle) : n\'envoie pas de date à ApiClient', () async {
      final db = await pumpDb();
      final api = _CreateSavApiClient.success({..._baseChantierJson(), 'reference': 'SAV-LD64397-1', 'type': 'sav'});
      final repository = ChantierRepository(api, db);

      await repository.createSav('LD64397', descriptionProbleme: 'Bruit anormal', installateurId: 'user-1');

      expect(api.lastSavDate, isNull);
    });

    test('rejet serveur (ex. chantier introuvable ou installateur invalide) : relève l\'exception telle quelle', () async {
      final db = await pumpDb();
      final exception = ApiException(400, 'Installateur sélectionné invalide');
      final repository = ChantierRepository(_CreateSavApiClient.failure(exception), db);

      await expectLater(
        () => repository.createSav('LD64397', descriptionProbleme: 'Bruit anormal', installateurId: 'invalide'),
        throwsA(same(exception)),
      );
    });
  });
}
