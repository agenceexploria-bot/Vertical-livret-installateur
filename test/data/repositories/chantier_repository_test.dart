import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/api_client.dart';
import 'package:vertical_app/data/local/app_database.dart';
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
}
