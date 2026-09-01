import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/api_client.dart';
import 'package:vertical_app/data/local/app_database.dart';
import 'package:vertical_app/data/repositories/auth_repository.dart';

/// Un `ApiClient` réel touchant réellement `http.get`/`post` n'est pas
/// exploitable ici pour simuler une coupure réseau : `flutter_test` mocke
/// `HttpClient` et renvoie systématiquement un faux HTTP 400 (jamais
/// d'exception de connexion), donc jamais `ApiException(0, ...)` — voir
/// ApiClient._request. On simule directement les deux cas réels
/// (coupure réseau vs rejet serveur) via ces deux doublures.
class _NetworkFailureApiClient extends ApiClient {
  @override
  Future<String> uploadFile({required String kind, required String dataUrl, String? filename}) async {
    throw ApiException(0, 'Erreur réseau. Vérifiez votre connexion.');
  }
}

class _RejectingApiClient extends ApiClient {
  final ApiException exception;
  _RejectingApiClient(this.exception);

  @override
  Future<String> uploadFile({required String kind, required String dataUrl, String? filename}) async {
    throw exception;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Un répertoire temporaire DÉDIÉ par appel : AppDatabase utilise toujours
  // le même nom de fichier ('vertical_app_db', voir app_database.dart) —
  // pointer chaque test vers Directory.systemTemp.path partagerait le même
  // fichier SQLite entre tests et ferait fuiter les lignes de l'un vers
  // l'autre (déjà observé : le test de rejet serveur voyait la ligne mise
  // en file d'attente par le test de coupure réseau précédent).
  Future<AppDatabase> pumpDb() async {
    final dir = Directory.systemTemp.createTempSync('auth_repository_test');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => dir.path,
    );
    return AppDatabase();
  }

  group('AuthRepository.addHabilitation', () {
    test('coupure réseau (ApiException(0, ...), voir ApiClient._request) : ne lève pas, met en file d\'attente hors-ligne', () async {
      final db = await pumpDb();
      final repository = AuthRepository(_NetworkFailureApiClient(), db);

      await repository.addHabilitation(titre: 'CACES', dateExpiration: DateTime(2027, 1, 1), file: 'data:application/pdf;base64,AAAA');

      final pending = await db.getPendingOperationsOrdered();
      expect(pending, hasLength(1));
      expect(pending.single.type, 'addHabilitation');
    });

    test('rejet serveur réel (type de fichier refusé) : relève l\'exception, ne met JAMAIS en file d\'attente', () async {
      final db = await pumpDb();
      final exception = ApiException(403, 'Ce type de fichier n\'est pas autorisé ici.');
      final repository = AuthRepository(_RejectingApiClient(exception), db);

      await expectLater(
        () => repository.addHabilitation(titre: 'CACES', dateExpiration: DateTime(2027, 1, 1), file: 'data:image/heic;base64,AAAA'),
        throwsA(same(exception)),
      );

      final pending = await db.getPendingOperationsOrdered();
      expect(pending, isEmpty, reason: 'un rejet serveur permanent rejoué à l\'identique ne doit jamais être mis en file d\'attente hors-ligne');
    });
  });
}
