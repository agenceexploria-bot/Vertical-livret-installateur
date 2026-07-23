import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Cache des chantiers récupérés depuis l'API — permet la consultation d'une
/// fiche chantier et de la liste des chantiers sans réseau.
@DataClassName('CachedChantier')
class CachedChantiers extends Table {
  TextColumn get reference => text()();
  TextColumn get dataJson => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {reference};
}

/// File d'attente des actions effectuées hors-ligne (checklist, REX, PV,
/// document terrain) — rejouées vers l'API dès que le réseau revient.
@DataClassName('PendingOperation')
class PendingOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get chantierReference => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().nullable()();
}

@DriftDatabase(tables: [CachedChantiers, PendingOperations])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'vertical_app_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  // ---- Cache chantiers ----

  /// Remplace tout le cache par la liste fraîchement reçue du serveur —
  /// garantit qu'un chantier retiré côté serveur (ex. dé-rattachement)
  /// disparaît aussi du cache local.
  Future<void> replaceAllChantiers(List<Map<String, dynamic>> chantiers) {
    return transaction(() async {
      await delete(cachedChantiers).go();
      final now = DateTime.now();
      await batch((b) {
        b.insertAll(
          cachedChantiers,
          chantiers.map((c) => CachedChantiersCompanion.insert(
                reference: c['reference'] as String,
                dataJson: jsonEncode(c),
                cachedAt: now,
              )),
        );
      });
    });
  }

  Future<void> cacheChantier(Map<String, dynamic> chantier) {
    return into(cachedChantiers).insertOnConflictUpdate(CachedChantiersCompanion.insert(
      reference: chantier['reference'] as String,
      dataJson: jsonEncode(chantier),
      cachedAt: DateTime.now(),
    ));
  }

  Future<List<Map<String, dynamic>>> getAllCachedChantiers() async {
    final rows = await select(cachedChantiers).get();
    return rows.map((r) => jsonDecode(r.dataJson) as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>?> getCachedChantier(String reference) async {
    final row = await (select(cachedChantiers)..where((t) => t.reference.equals(reference))).getSingleOrNull();
    return row == null ? null : jsonDecode(row.dataJson) as Map<String, dynamic>;
  }

  Future<void> clearChantierCache() => delete(cachedChantiers).go();

  // ---- File d'attente de synchronisation ----

  Future<int> enqueueOperation({
    required String type,
    required String chantierReference,
    required Map<String, dynamic> payload,
  }) {
    return into(pendingOperations).insert(PendingOperationsCompanion.insert(
      type: type,
      chantierReference: chantierReference,
      payloadJson: jsonEncode(payload),
    ));
  }

  Future<List<PendingOperation>> getPendingOperationsOrdered() {
    return (select(pendingOperations)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> deleteOperation(int id) => (delete(pendingOperations)..where((t) => t.id.equals(id))).go();

  Future<void> markOperationFailed(int id, String error) {
    return (update(pendingOperations)..where((t) => t.id.equals(id))).write(
      PendingOperationsCompanion(status: const Value('failed'), lastError: Value(error)),
    );
  }

  Stream<int> watchPendingCount() {
    final query = select(pendingOperations)..where((t) => t.status.equals('pending'));
    return query.watch().map((rows) => rows.length);
  }
}
