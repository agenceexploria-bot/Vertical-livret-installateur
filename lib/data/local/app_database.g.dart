// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedChantiersTable extends CachedChantiers
    with TableInfo<$CachedChantiersTable, CachedChantier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedChantiersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [reference, dataJson, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_chantiers';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedChantier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    } else if (isInserting) {
      context.missing(_referenceMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reference};
  @override
  CachedChantier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedChantier(
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedChantiersTable createAlias(String alias) {
    return $CachedChantiersTable(attachedDatabase, alias);
  }
}

class CachedChantier extends DataClass implements Insertable<CachedChantier> {
  final String reference;
  final String dataJson;
  final DateTime cachedAt;
  const CachedChantier({
    required this.reference,
    required this.dataJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reference'] = Variable<String>(reference);
    map['data_json'] = Variable<String>(dataJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedChantiersCompanion toCompanion(bool nullToAbsent) {
    return CachedChantiersCompanion(
      reference: Value(reference),
      dataJson: Value(dataJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedChantier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedChantier(
      reference: serializer.fromJson<String>(json['reference']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reference': serializer.toJson<String>(reference),
      'dataJson': serializer.toJson<String>(dataJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedChantier copyWith({
    String? reference,
    String? dataJson,
    DateTime? cachedAt,
  }) => CachedChantier(
    reference: reference ?? this.reference,
    dataJson: dataJson ?? this.dataJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedChantier copyWithCompanion(CachedChantiersCompanion data) {
    return CachedChantier(
      reference: data.reference.present ? data.reference.value : this.reference,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedChantier(')
          ..write('reference: $reference, ')
          ..write('dataJson: $dataJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(reference, dataJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedChantier &&
          other.reference == this.reference &&
          other.dataJson == this.dataJson &&
          other.cachedAt == this.cachedAt);
}

class CachedChantiersCompanion extends UpdateCompanion<CachedChantier> {
  final Value<String> reference;
  final Value<String> dataJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedChantiersCompanion({
    this.reference = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedChantiersCompanion.insert({
    required String reference,
    required String dataJson,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : reference = Value(reference),
       dataJson = Value(dataJson),
       cachedAt = Value(cachedAt);
  static Insertable<CachedChantier> custom({
    Expression<String>? reference,
    Expression<String>? dataJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reference != null) 'reference': reference,
      if (dataJson != null) 'data_json': dataJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedChantiersCompanion copyWith({
    Value<String>? reference,
    Value<String>? dataJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedChantiersCompanion(
      reference: reference ?? this.reference,
      dataJson: dataJson ?? this.dataJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedChantiersCompanion(')
          ..write('reference: $reference, ')
          ..write('dataJson: $dataJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingOperationsTable extends PendingOperations
    with TableInfo<$PendingOperationsTable, PendingOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chantierReferenceMeta = const VerificationMeta(
    'chantierReference',
  );
  @override
  late final GeneratedColumn<String> chantierReference =
      GeneratedColumn<String>(
        'chantier_reference',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    chantierReference,
    payloadJson,
    createdAt,
    status,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('chantier_reference')) {
      context.handle(
        _chantierReferenceMeta,
        chantierReference.isAcceptableOrUnknown(
          data['chantier_reference']!,
          _chantierReferenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chantierReferenceMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOperation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      chantierReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chantier_reference'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PendingOperationsTable createAlias(String alias) {
    return $PendingOperationsTable(attachedDatabase, alias);
  }
}

class PendingOperation extends DataClass
    implements Insertable<PendingOperation> {
  final int id;
  final String type;
  final String chantierReference;
  final String payloadJson;
  final DateTime createdAt;
  final String status;
  final String? lastError;
  const PendingOperation({
    required this.id,
    required this.type,
    required this.chantierReference,
    required this.payloadJson,
    required this.createdAt,
    required this.status,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['type'] = Variable<String>(type);
    map['chantier_reference'] = Variable<String>(chantierReference);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingOperationsCompanion toCompanion(bool nullToAbsent) {
    return PendingOperationsCompanion(
      id: Value(id),
      type: Value(type),
      chantierReference: Value(chantierReference),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      status: Value(status),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOperation(
      id: serializer.fromJson<int>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      chantierReference: serializer.fromJson<String>(json['chantierReference']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(type),
      'chantierReference': serializer.toJson<String>(chantierReference),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingOperation copyWith({
    int? id,
    String? type,
    String? chantierReference,
    String? payloadJson,
    DateTime? createdAt,
    String? status,
    Value<String?> lastError = const Value.absent(),
  }) => PendingOperation(
    id: id ?? this.id,
    type: type ?? this.type,
    chantierReference: chantierReference ?? this.chantierReference,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PendingOperation copyWithCompanion(PendingOperationsCompanion data) {
    return PendingOperation(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      chantierReference: data.chantierReference.present
          ? data.chantierReference.value
          : this.chantierReference,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperation(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('chantierReference: $chantierReference, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    chantierReference,
    payloadJson,
    createdAt,
    status,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOperation &&
          other.id == this.id &&
          other.type == this.type &&
          other.chantierReference == this.chantierReference &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.lastError == this.lastError);
}

class PendingOperationsCompanion extends UpdateCompanion<PendingOperation> {
  final Value<int> id;
  final Value<String> type;
  final Value<String> chantierReference;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<String?> lastError;
  const PendingOperationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.chantierReference = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PendingOperationsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required String chantierReference,
    required String payloadJson,
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : type = Value(type),
       chantierReference = Value(chantierReference),
       payloadJson = Value(payloadJson);
  static Insertable<PendingOperation> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? chantierReference,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (chantierReference != null) 'chantier_reference': chantierReference,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PendingOperationsCompanion copyWith({
    Value<int>? id,
    Value<String>? type,
    Value<String>? chantierReference,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<String>? status,
    Value<String?>? lastError,
  }) {
    return PendingOperationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      chantierReference: chantierReference ?? this.chantierReference,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (chantierReference.present) {
      map['chantier_reference'] = Variable<String>(chantierReference.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('chantierReference: $chantierReference, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedChantiersTable cachedChantiers = $CachedChantiersTable(
    this,
  );
  late final $PendingOperationsTable pendingOperations =
      $PendingOperationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedChantiers,
    pendingOperations,
  ];
}

typedef $$CachedChantiersTableCreateCompanionBuilder =
    CachedChantiersCompanion Function({
      required String reference,
      required String dataJson,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedChantiersTableUpdateCompanionBuilder =
    CachedChantiersCompanion Function({
      Value<String> reference,
      Value<String> dataJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedChantiersTableFilterComposer
    extends Composer<_$AppDatabase, $CachedChantiersTable> {
  $$CachedChantiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedChantiersTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedChantiersTable> {
  $$CachedChantiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedChantiersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedChantiersTable> {
  $$CachedChantiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedChantiersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedChantiersTable,
          CachedChantier,
          $$CachedChantiersTableFilterComposer,
          $$CachedChantiersTableOrderingComposer,
          $$CachedChantiersTableAnnotationComposer,
          $$CachedChantiersTableCreateCompanionBuilder,
          $$CachedChantiersTableUpdateCompanionBuilder,
          (
            CachedChantier,
            BaseReferences<
              _$AppDatabase,
              $CachedChantiersTable,
              CachedChantier
            >,
          ),
          CachedChantier,
          PrefetchHooks Function()
        > {
  $$CachedChantiersTableTableManager(
    _$AppDatabase db,
    $CachedChantiersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedChantiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedChantiersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedChantiersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> reference = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedChantiersCompanion(
                reference: reference,
                dataJson: dataJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String reference,
                required String dataJson,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedChantiersCompanion.insert(
                reference: reference,
                dataJson: dataJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedChantiersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedChantiersTable,
      CachedChantier,
      $$CachedChantiersTableFilterComposer,
      $$CachedChantiersTableOrderingComposer,
      $$CachedChantiersTableAnnotationComposer,
      $$CachedChantiersTableCreateCompanionBuilder,
      $$CachedChantiersTableUpdateCompanionBuilder,
      (
        CachedChantier,
        BaseReferences<_$AppDatabase, $CachedChantiersTable, CachedChantier>,
      ),
      CachedChantier,
      PrefetchHooks Function()
    >;
typedef $$PendingOperationsTableCreateCompanionBuilder =
    PendingOperationsCompanion Function({
      Value<int> id,
      required String type,
      required String chantierReference,
      required String payloadJson,
      Value<DateTime> createdAt,
      Value<String> status,
      Value<String?> lastError,
    });
typedef $$PendingOperationsTableUpdateCompanionBuilder =
    PendingOperationsCompanion Function({
      Value<int> id,
      Value<String> type,
      Value<String> chantierReference,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<String> status,
      Value<String?> lastError,
    });

class $$PendingOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chantierReference => $composableBuilder(
    column: $table.chantierReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chantierReference => $composableBuilder(
    column: $table.chantierReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get chantierReference => $composableBuilder(
    column: $table.chantierReference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingOperationsTable,
          PendingOperation,
          $$PendingOperationsTableFilterComposer,
          $$PendingOperationsTableOrderingComposer,
          $$PendingOperationsTableAnnotationComposer,
          $$PendingOperationsTableCreateCompanionBuilder,
          $$PendingOperationsTableUpdateCompanionBuilder,
          (
            PendingOperation,
            BaseReferences<
              _$AppDatabase,
              $PendingOperationsTable,
              PendingOperation
            >,
          ),
          PendingOperation,
          PrefetchHooks Function()
        > {
  $$PendingOperationsTableTableManager(
    _$AppDatabase db,
    $PendingOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> chantierReference = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingOperationsCompanion(
                id: id,
                type: type,
                chantierReference: chantierReference,
                payloadJson: payloadJson,
                createdAt: createdAt,
                status: status,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String type,
                required String chantierReference,
                required String payloadJson,
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingOperationsCompanion.insert(
                id: id,
                type: type,
                chantierReference: chantierReference,
                payloadJson: payloadJson,
                createdAt: createdAt,
                status: status,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingOperationsTable,
      PendingOperation,
      $$PendingOperationsTableFilterComposer,
      $$PendingOperationsTableOrderingComposer,
      $$PendingOperationsTableAnnotationComposer,
      $$PendingOperationsTableCreateCompanionBuilder,
      $$PendingOperationsTableUpdateCompanionBuilder,
      (
        PendingOperation,
        BaseReferences<
          _$AppDatabase,
          $PendingOperationsTable,
          PendingOperation
        >,
      ),
      PendingOperation,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedChantiersTableTableManager get cachedChantiers =>
      $$CachedChantiersTableTableManager(_db, _db.cachedChantiers);
  $$PendingOperationsTableTableManager get pendingOperations =>
      $$PendingOperationsTableTableManager(_db, _db.pendingOperations);
}
