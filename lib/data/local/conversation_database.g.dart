// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_database.dart';

// ignore_for_file: type=lint
class $ConversationSessionsTable extends ConversationSessions
    with TableInfo<$ConversationSessionsTable, ConversationSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootSessionIdMeta = const VerificationMeta(
    'rootSessionId',
  );
  @override
  late final GeneratedColumn<String> rootSessionId = GeneratedColumn<String>(
    'root_session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceSessionIdMeta = const VerificationMeta(
    'sourceSessionId',
  );
  @override
  late final GeneratedColumn<String> sourceSessionId = GeneratedColumn<String>(
    'source_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTurnIdMeta = const VerificationMeta(
    'sourceTurnId',
  );
  @override
  late final GeneratedColumn<String> sourceTurnId = GeneratedColumn<String>(
    'source_turn_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _professorIdMeta = const VerificationMeta(
    'professorId',
  );
  @override
  late final GeneratedColumn<String> professorId = GeneratedColumn<String>(
    'professor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _legacyContextIncompleteMeta =
      const VerificationMeta('legacyContextIncomplete');
  @override
  late final GeneratedColumn<bool> legacyContextIncomplete =
      GeneratedColumn<bool>(
        'legacy_context_incomplete',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("legacy_context_incomplete" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    rootSessionId,
    sourceSessionId,
    sourceTurnId,
    professorId,
    ownerId,
    revision,
    title,
    createdAt,
    updatedAt,
    deletedAt,
    legacyContextIncomplete,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('root_session_id')) {
      context.handle(
        _rootSessionIdMeta,
        rootSessionId.isAcceptableOrUnknown(
          data['root_session_id']!,
          _rootSessionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rootSessionIdMeta);
    }
    if (data.containsKey('source_session_id')) {
      context.handle(
        _sourceSessionIdMeta,
        sourceSessionId.isAcceptableOrUnknown(
          data['source_session_id']!,
          _sourceSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('source_turn_id')) {
      context.handle(
        _sourceTurnIdMeta,
        sourceTurnId.isAcceptableOrUnknown(
          data['source_turn_id']!,
          _sourceTurnIdMeta,
        ),
      );
    }
    if (data.containsKey('professor_id')) {
      context.handle(
        _professorIdMeta,
        professorId.isAcceptableOrUnknown(
          data['professor_id']!,
          _professorIdMeta,
        ),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('legacy_context_incomplete')) {
      context.handle(
        _legacyContextIncompleteMeta,
        legacyContextIncomplete.isAcceptableOrUnknown(
          data['legacy_context_incomplete']!,
          _legacyContextIncompleteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceSessionId, sourceTurnId, professorId},
  ];
  @override
  ConversationSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      rootSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_session_id'],
      )!,
      sourceSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_session_id'],
      ),
      sourceTurnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_turn_id'],
      ),
      professorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}professor_id'],
      ),
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      legacyContextIncomplete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}legacy_context_incomplete'],
      )!,
    );
  }

  @override
  $ConversationSessionsTable createAlias(String alias) {
    return $ConversationSessionsTable(attachedDatabase, alias);
  }
}

class ConversationSessionRow extends DataClass
    implements Insertable<ConversationSessionRow> {
  final String id;
  final String kind;
  final String rootSessionId;
  final String? sourceSessionId;
  final String? sourceTurnId;
  final String? professorId;
  final String ownerId;
  final int revision;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool legacyContextIncomplete;
  const ConversationSessionRow({
    required this.id,
    required this.kind,
    required this.rootSessionId,
    this.sourceSessionId,
    this.sourceTurnId,
    this.professorId,
    required this.ownerId,
    required this.revision,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.legacyContextIncomplete,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['root_session_id'] = Variable<String>(rootSessionId);
    if (!nullToAbsent || sourceSessionId != null) {
      map['source_session_id'] = Variable<String>(sourceSessionId);
    }
    if (!nullToAbsent || sourceTurnId != null) {
      map['source_turn_id'] = Variable<String>(sourceTurnId);
    }
    if (!nullToAbsent || professorId != null) {
      map['professor_id'] = Variable<String>(professorId);
    }
    map['owner_id'] = Variable<String>(ownerId);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['legacy_context_incomplete'] = Variable<bool>(legacyContextIncomplete);
    return map;
  }

  ConversationSessionsCompanion toCompanion(bool nullToAbsent) {
    return ConversationSessionsCompanion(
      id: Value(id),
      kind: Value(kind),
      rootSessionId: Value(rootSessionId),
      sourceSessionId: sourceSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSessionId),
      sourceTurnId: sourceTurnId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTurnId),
      professorId: professorId == null && nullToAbsent
          ? const Value.absent()
          : Value(professorId),
      ownerId: Value(ownerId),
      revision: Value(revision),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      legacyContextIncomplete: Value(legacyContextIncomplete),
    );
  }

  factory ConversationSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationSessionRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      rootSessionId: serializer.fromJson<String>(json['rootSessionId']),
      sourceSessionId: serializer.fromJson<String?>(json['sourceSessionId']),
      sourceTurnId: serializer.fromJson<String?>(json['sourceTurnId']),
      professorId: serializer.fromJson<String?>(json['professorId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      revision: serializer.fromJson<int>(json['revision']),
      title: serializer.fromJson<String?>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      legacyContextIncomplete: serializer.fromJson<bool>(
        json['legacyContextIncomplete'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'rootSessionId': serializer.toJson<String>(rootSessionId),
      'sourceSessionId': serializer.toJson<String?>(sourceSessionId),
      'sourceTurnId': serializer.toJson<String?>(sourceTurnId),
      'professorId': serializer.toJson<String?>(professorId),
      'ownerId': serializer.toJson<String>(ownerId),
      'revision': serializer.toJson<int>(revision),
      'title': serializer.toJson<String?>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'legacyContextIncomplete': serializer.toJson<bool>(
        legacyContextIncomplete,
      ),
    };
  }

  ConversationSessionRow copyWith({
    String? id,
    String? kind,
    String? rootSessionId,
    Value<String?> sourceSessionId = const Value.absent(),
    Value<String?> sourceTurnId = const Value.absent(),
    Value<String?> professorId = const Value.absent(),
    String? ownerId,
    int? revision,
    Value<String?> title = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? legacyContextIncomplete,
  }) => ConversationSessionRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    rootSessionId: rootSessionId ?? this.rootSessionId,
    sourceSessionId: sourceSessionId.present
        ? sourceSessionId.value
        : this.sourceSessionId,
    sourceTurnId: sourceTurnId.present ? sourceTurnId.value : this.sourceTurnId,
    professorId: professorId.present ? professorId.value : this.professorId,
    ownerId: ownerId ?? this.ownerId,
    revision: revision ?? this.revision,
    title: title.present ? title.value : this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    legacyContextIncomplete:
        legacyContextIncomplete ?? this.legacyContextIncomplete,
  );
  ConversationSessionRow copyWithCompanion(ConversationSessionsCompanion data) {
    return ConversationSessionRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      rootSessionId: data.rootSessionId.present
          ? data.rootSessionId.value
          : this.rootSessionId,
      sourceSessionId: data.sourceSessionId.present
          ? data.sourceSessionId.value
          : this.sourceSessionId,
      sourceTurnId: data.sourceTurnId.present
          ? data.sourceTurnId.value
          : this.sourceTurnId,
      professorId: data.professorId.present
          ? data.professorId.value
          : this.professorId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      revision: data.revision.present ? data.revision.value : this.revision,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      legacyContextIncomplete: data.legacyContextIncomplete.present
          ? data.legacyContextIncomplete.value
          : this.legacyContextIncomplete,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSessionRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('rootSessionId: $rootSessionId, ')
          ..write('sourceSessionId: $sourceSessionId, ')
          ..write('sourceTurnId: $sourceTurnId, ')
          ..write('professorId: $professorId, ')
          ..write('ownerId: $ownerId, ')
          ..write('revision: $revision, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('legacyContextIncomplete: $legacyContextIncomplete')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    rootSessionId,
    sourceSessionId,
    sourceTurnId,
    professorId,
    ownerId,
    revision,
    title,
    createdAt,
    updatedAt,
    deletedAt,
    legacyContextIncomplete,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationSessionRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.rootSessionId == this.rootSessionId &&
          other.sourceSessionId == this.sourceSessionId &&
          other.sourceTurnId == this.sourceTurnId &&
          other.professorId == this.professorId &&
          other.ownerId == this.ownerId &&
          other.revision == this.revision &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.legacyContextIncomplete == this.legacyContextIncomplete);
}

class ConversationSessionsCompanion
    extends UpdateCompanion<ConversationSessionRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> rootSessionId;
  final Value<String?> sourceSessionId;
  final Value<String?> sourceTurnId;
  final Value<String?> professorId;
  final Value<String> ownerId;
  final Value<int> revision;
  final Value<String?> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> legacyContextIncomplete;
  final Value<int> rowid;
  const ConversationSessionsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.rootSessionId = const Value.absent(),
    this.sourceSessionId = const Value.absent(),
    this.sourceTurnId = const Value.absent(),
    this.professorId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.revision = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.legacyContextIncomplete = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationSessionsCompanion.insert({
    required String id,
    required String kind,
    required String rootSessionId,
    this.sourceSessionId = const Value.absent(),
    this.sourceTurnId = const Value.absent(),
    this.professorId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.revision = const Value.absent(),
    this.title = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.legacyContextIncomplete = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       rootSessionId = Value(rootSessionId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationSessionRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? rootSessionId,
    Expression<String>? sourceSessionId,
    Expression<String>? sourceTurnId,
    Expression<String>? professorId,
    Expression<String>? ownerId,
    Expression<int>? revision,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? legacyContextIncomplete,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (rootSessionId != null) 'root_session_id': rootSessionId,
      if (sourceSessionId != null) 'source_session_id': sourceSessionId,
      if (sourceTurnId != null) 'source_turn_id': sourceTurnId,
      if (professorId != null) 'professor_id': professorId,
      if (ownerId != null) 'owner_id': ownerId,
      if (revision != null) 'revision': revision,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (legacyContextIncomplete != null)
        'legacy_context_incomplete': legacyContextIncomplete,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? rootSessionId,
    Value<String?>? sourceSessionId,
    Value<String?>? sourceTurnId,
    Value<String?>? professorId,
    Value<String>? ownerId,
    Value<int>? revision,
    Value<String?>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? legacyContextIncomplete,
    Value<int>? rowid,
  }) {
    return ConversationSessionsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      rootSessionId: rootSessionId ?? this.rootSessionId,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      sourceTurnId: sourceTurnId ?? this.sourceTurnId,
      professorId: professorId ?? this.professorId,
      ownerId: ownerId ?? this.ownerId,
      revision: revision ?? this.revision,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      legacyContextIncomplete:
          legacyContextIncomplete ?? this.legacyContextIncomplete,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rootSessionId.present) {
      map['root_session_id'] = Variable<String>(rootSessionId.value);
    }
    if (sourceSessionId.present) {
      map['source_session_id'] = Variable<String>(sourceSessionId.value);
    }
    if (sourceTurnId.present) {
      map['source_turn_id'] = Variable<String>(sourceTurnId.value);
    }
    if (professorId.present) {
      map['professor_id'] = Variable<String>(professorId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (legacyContextIncomplete.present) {
      map['legacy_context_incomplete'] = Variable<bool>(
        legacyContextIncomplete.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSessionsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('rootSessionId: $rootSessionId, ')
          ..write('sourceSessionId: $sourceSessionId, ')
          ..write('sourceTurnId: $sourceTurnId, ')
          ..write('professorId: $professorId, ')
          ..write('ownerId: $ownerId, ')
          ..write('revision: $revision, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('legacyContextIncomplete: $legacyContextIncomplete, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationTurnsTable extends ConversationTurns
    with TableInfo<$ConversationTurnsTable, ConversationTurnRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationTurnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversation_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routeMeta = const VerificationMeta('route');
  @override
  late final GeneratedColumn<String> route = GeneratedColumn<String>(
    'route',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userMessageIdMeta = const VerificationMeta(
    'userMessageId',
  );
  @override
  late final GeneratedColumn<String> userMessageId = GeneratedColumn<String>(
    'user_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeAttemptIdMeta = const VerificationMeta(
    'activeAttemptId',
  );
  @override
  late final GeneratedColumn<String> activeAttemptId = GeneratedColumn<String>(
    'active_attempt_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    ordinal,
    status,
    route,
    userMessageId,
    activeAttemptId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_turns';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationTurnRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('route')) {
      context.handle(
        _routeMeta,
        route.isAcceptableOrUnknown(data['route']!, _routeMeta),
      );
    }
    if (data.containsKey('user_message_id')) {
      context.handle(
        _userMessageIdMeta,
        userMessageId.isAcceptableOrUnknown(
          data['user_message_id']!,
          _userMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_userMessageIdMeta);
    }
    if (data.containsKey('active_attempt_id')) {
      context.handle(
        _activeAttemptIdMeta,
        activeAttemptId.isAcceptableOrUnknown(
          data['active_attempt_id']!,
          _activeAttemptIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId, ordinal},
  ];
  @override
  ConversationTurnRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationTurnRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      route: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route'],
      ),
      userMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_message_id'],
      )!,
      activeAttemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_attempt_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConversationTurnsTable createAlias(String alias) {
    return $ConversationTurnsTable(attachedDatabase, alias);
  }
}

class ConversationTurnRow extends DataClass
    implements Insertable<ConversationTurnRow> {
  final String id;
  final String sessionId;
  final int ordinal;
  final String status;
  final String? route;
  final String userMessageId;
  final String? activeAttemptId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ConversationTurnRow({
    required this.id,
    required this.sessionId,
    required this.ordinal,
    required this.status,
    this.route,
    required this.userMessageId,
    this.activeAttemptId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['ordinal'] = Variable<int>(ordinal);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || route != null) {
      map['route'] = Variable<String>(route);
    }
    map['user_message_id'] = Variable<String>(userMessageId);
    if (!nullToAbsent || activeAttemptId != null) {
      map['active_attempt_id'] = Variable<String>(activeAttemptId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationTurnsCompanion toCompanion(bool nullToAbsent) {
    return ConversationTurnsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      ordinal: Value(ordinal),
      status: Value(status),
      route: route == null && nullToAbsent
          ? const Value.absent()
          : Value(route),
      userMessageId: Value(userMessageId),
      activeAttemptId: activeAttemptId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeAttemptId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConversationTurnRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationTurnRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      status: serializer.fromJson<String>(json['status']),
      route: serializer.fromJson<String?>(json['route']),
      userMessageId: serializer.fromJson<String>(json['userMessageId']),
      activeAttemptId: serializer.fromJson<String?>(json['activeAttemptId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'ordinal': serializer.toJson<int>(ordinal),
      'status': serializer.toJson<String>(status),
      'route': serializer.toJson<String?>(route),
      'userMessageId': serializer.toJson<String>(userMessageId),
      'activeAttemptId': serializer.toJson<String?>(activeAttemptId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConversationTurnRow copyWith({
    String? id,
    String? sessionId,
    int? ordinal,
    String? status,
    Value<String?> route = const Value.absent(),
    String? userMessageId,
    Value<String?> activeAttemptId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ConversationTurnRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    ordinal: ordinal ?? this.ordinal,
    status: status ?? this.status,
    route: route.present ? route.value : this.route,
    userMessageId: userMessageId ?? this.userMessageId,
    activeAttemptId: activeAttemptId.present
        ? activeAttemptId.value
        : this.activeAttemptId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConversationTurnRow copyWithCompanion(ConversationTurnsCompanion data) {
    return ConversationTurnRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      status: data.status.present ? data.status.value : this.status,
      route: data.route.present ? data.route.value : this.route,
      userMessageId: data.userMessageId.present
          ? data.userMessageId.value
          : this.userMessageId,
      activeAttemptId: data.activeAttemptId.present
          ? data.activeAttemptId.value
          : this.activeAttemptId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationTurnRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('status: $status, ')
          ..write('route: $route, ')
          ..write('userMessageId: $userMessageId, ')
          ..write('activeAttemptId: $activeAttemptId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    ordinal,
    status,
    route,
    userMessageId,
    activeAttemptId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationTurnRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.ordinal == this.ordinal &&
          other.status == this.status &&
          other.route == this.route &&
          other.userMessageId == this.userMessageId &&
          other.activeAttemptId == this.activeAttemptId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationTurnsCompanion extends UpdateCompanion<ConversationTurnRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> ordinal;
  final Value<String> status;
  final Value<String?> route;
  final Value<String> userMessageId;
  final Value<String?> activeAttemptId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationTurnsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.status = const Value.absent(),
    this.route = const Value.absent(),
    this.userMessageId = const Value.absent(),
    this.activeAttemptId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationTurnsCompanion.insert({
    required String id,
    required String sessionId,
    required int ordinal,
    required String status,
    this.route = const Value.absent(),
    required String userMessageId,
    this.activeAttemptId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       ordinal = Value(ordinal),
       status = Value(status),
       userMessageId = Value(userMessageId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationTurnRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? ordinal,
    Expression<String>? status,
    Expression<String>? route,
    Expression<String>? userMessageId,
    Expression<String>? activeAttemptId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (ordinal != null) 'ordinal': ordinal,
      if (status != null) 'status': status,
      if (route != null) 'route': route,
      if (userMessageId != null) 'user_message_id': userMessageId,
      if (activeAttemptId != null) 'active_attempt_id': activeAttemptId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationTurnsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? ordinal,
    Value<String>? status,
    Value<String?>? route,
    Value<String>? userMessageId,
    Value<String?>? activeAttemptId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationTurnsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      ordinal: ordinal ?? this.ordinal,
      status: status ?? this.status,
      route: route ?? this.route,
      userMessageId: userMessageId ?? this.userMessageId,
      activeAttemptId: activeAttemptId ?? this.activeAttemptId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (route.present) {
      map['route'] = Variable<String>(route.value);
    }
    if (userMessageId.present) {
      map['user_message_id'] = Variable<String>(userMessageId.value);
    }
    if (activeAttemptId.present) {
      map['active_attempt_id'] = Variable<String>(activeAttemptId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationTurnsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('status: $status, ')
          ..write('route: $route, ')
          ..write('userMessageId: $userMessageId, ')
          ..write('activeAttemptId: $activeAttemptId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssistantAttemptsTable extends AssistantAttempts
    with TableInfo<$AssistantAttemptsTable, AssistantAttemptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turnIdMeta = const VerificationMeta('turnId');
  @override
  late final GeneratedColumn<String> turnId = GeneratedColumn<String>(
    'turn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversation_turns (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assistantMessageIdMeta =
      const VerificationMeta('assistantMessageId');
  @override
  late final GeneratedColumn<String> assistantMessageId =
      GeneratedColumn<String>(
        'assistant_message_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    turnId,
    requestId,
    status,
    assistantMessageId,
    errorCode,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistant_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantAttemptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('turn_id')) {
      context.handle(
        _turnIdMeta,
        turnId.isAcceptableOrUnknown(data['turn_id']!, _turnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turnIdMeta);
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('assistant_message_id')) {
      context.handle(
        _assistantMessageIdMeta,
        assistantMessageId.isAcceptableOrUnknown(
          data['assistant_message_id']!,
          _assistantMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssistantAttemptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantAttemptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      turnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_id'],
      )!,
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      assistantMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assistant_message_id'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AssistantAttemptsTable createAlias(String alias) {
    return $AssistantAttemptsTable(attachedDatabase, alias);
  }
}

class AssistantAttemptRow extends DataClass
    implements Insertable<AssistantAttemptRow> {
  final String id;
  final String turnId;
  final String requestId;
  final String status;
  final String? assistantMessageId;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AssistantAttemptRow({
    required this.id,
    required this.turnId,
    required this.requestId,
    required this.status,
    this.assistantMessageId,
    this.errorCode,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['turn_id'] = Variable<String>(turnId);
    map['request_id'] = Variable<String>(requestId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || assistantMessageId != null) {
      map['assistant_message_id'] = Variable<String>(assistantMessageId);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AssistantAttemptsCompanion toCompanion(bool nullToAbsent) {
    return AssistantAttemptsCompanion(
      id: Value(id),
      turnId: Value(turnId),
      requestId: Value(requestId),
      status: Value(status),
      assistantMessageId: assistantMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantMessageId),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AssistantAttemptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantAttemptRow(
      id: serializer.fromJson<String>(json['id']),
      turnId: serializer.fromJson<String>(json['turnId']),
      requestId: serializer.fromJson<String>(json['requestId']),
      status: serializer.fromJson<String>(json['status']),
      assistantMessageId: serializer.fromJson<String?>(
        json['assistantMessageId'],
      ),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'turnId': serializer.toJson<String>(turnId),
      'requestId': serializer.toJson<String>(requestId),
      'status': serializer.toJson<String>(status),
      'assistantMessageId': serializer.toJson<String?>(assistantMessageId),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AssistantAttemptRow copyWith({
    String? id,
    String? turnId,
    String? requestId,
    String? status,
    Value<String?> assistantMessageId = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AssistantAttemptRow(
    id: id ?? this.id,
    turnId: turnId ?? this.turnId,
    requestId: requestId ?? this.requestId,
    status: status ?? this.status,
    assistantMessageId: assistantMessageId.present
        ? assistantMessageId.value
        : this.assistantMessageId,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AssistantAttemptRow copyWithCompanion(AssistantAttemptsCompanion data) {
    return AssistantAttemptRow(
      id: data.id.present ? data.id.value : this.id,
      turnId: data.turnId.present ? data.turnId.value : this.turnId,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      status: data.status.present ? data.status.value : this.status,
      assistantMessageId: data.assistantMessageId.present
          ? data.assistantMessageId.value
          : this.assistantMessageId,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantAttemptRow(')
          ..write('id: $id, ')
          ..write('turnId: $turnId, ')
          ..write('requestId: $requestId, ')
          ..write('status: $status, ')
          ..write('assistantMessageId: $assistantMessageId, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    turnId,
    requestId,
    status,
    assistantMessageId,
    errorCode,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantAttemptRow &&
          other.id == this.id &&
          other.turnId == this.turnId &&
          other.requestId == this.requestId &&
          other.status == this.status &&
          other.assistantMessageId == this.assistantMessageId &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AssistantAttemptsCompanion extends UpdateCompanion<AssistantAttemptRow> {
  final Value<String> id;
  final Value<String> turnId;
  final Value<String> requestId;
  final Value<String> status;
  final Value<String?> assistantMessageId;
  final Value<String?> errorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AssistantAttemptsCompanion({
    this.id = const Value.absent(),
    this.turnId = const Value.absent(),
    this.requestId = const Value.absent(),
    this.status = const Value.absent(),
    this.assistantMessageId = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantAttemptsCompanion.insert({
    required String id,
    required String turnId,
    required String requestId,
    required String status,
    this.assistantMessageId = const Value.absent(),
    this.errorCode = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       turnId = Value(turnId),
       requestId = Value(requestId),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AssistantAttemptRow> custom({
    Expression<String>? id,
    Expression<String>? turnId,
    Expression<String>? requestId,
    Expression<String>? status,
    Expression<String>? assistantMessageId,
    Expression<String>? errorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (turnId != null) 'turn_id': turnId,
      if (requestId != null) 'request_id': requestId,
      if (status != null) 'status': status,
      if (assistantMessageId != null)
        'assistant_message_id': assistantMessageId,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantAttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? turnId,
    Value<String>? requestId,
    Value<String>? status,
    Value<String?>? assistantMessageId,
    Value<String?>? errorCode,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AssistantAttemptsCompanion(
      id: id ?? this.id,
      turnId: turnId ?? this.turnId,
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      assistantMessageId: assistantMessageId ?? this.assistantMessageId,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (turnId.present) {
      map['turn_id'] = Variable<String>(turnId.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (assistantMessageId.present) {
      map['assistant_message_id'] = Variable<String>(assistantMessageId.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantAttemptsCompanion(')
          ..write('id: $id, ')
          ..write('turnId: $turnId, ')
          ..write('requestId: $requestId, ')
          ..write('status: $status, ')
          ..write('assistantMessageId: $assistantMessageId, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationMessagesTable extends ConversationMessages
    with TableInfo<$ConversationMessagesTable, ConversationMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversation_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _turnIdMeta = const VerificationMeta('turnId');
  @override
  late final GeneratedColumn<String> turnId = GeneratedColumn<String>(
    'turn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversation_turns (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recommendationsJsonMeta =
      const VerificationMeta('recommendationsJson');
  @override
  late final GeneratedColumn<String> recommendationsJson =
      GeneratedColumn<String>(
        'recommendations_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _feedbackMeta = const VerificationMeta(
    'feedback',
  );
  @override
  late final GeneratedColumn<String> feedback = GeneratedColumn<String>(
    'feedback',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    turnId,
    attemptId,
    role,
    kind,
    content,
    status,
    recommendationsJson,
    feedback,
    position,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('turn_id')) {
      context.handle(
        _turnIdMeta,
        turnId.isAcceptableOrUnknown(data['turn_id']!, _turnIdMeta),
      );
    } else if (isInserting) {
      context.missing(_turnIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('recommendations_json')) {
      context.handle(
        _recommendationsJsonMeta,
        recommendationsJson.isAcceptableOrUnknown(
          data['recommendations_json']!,
          _recommendationsJsonMeta,
        ),
      );
    }
    if (data.containsKey('feedback')) {
      context.handle(
        _feedbackMeta,
        feedback.isAcceptableOrUnknown(data['feedback']!, _feedbackMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId, position},
  ];
  @override
  ConversationMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      turnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      recommendationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recommendations_json'],
      )!,
      feedback: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feedback'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConversationMessagesTable createAlias(String alias) {
    return $ConversationMessagesTable(attachedDatabase, alias);
  }
}

class ConversationMessageRow extends DataClass
    implements Insertable<ConversationMessageRow> {
  final String id;
  final String sessionId;
  final String turnId;
  final String? attemptId;
  final String role;
  final String kind;
  final String content;
  final String status;
  final String recommendationsJson;
  final String feedback;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ConversationMessageRow({
    required this.id,
    required this.sessionId,
    required this.turnId,
    this.attemptId,
    required this.role,
    required this.kind,
    required this.content,
    required this.status,
    required this.recommendationsJson,
    required this.feedback,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['turn_id'] = Variable<String>(turnId);
    if (!nullToAbsent || attemptId != null) {
      map['attempt_id'] = Variable<String>(attemptId);
    }
    map['role'] = Variable<String>(role);
    map['kind'] = Variable<String>(kind);
    map['content'] = Variable<String>(content);
    map['status'] = Variable<String>(status);
    map['recommendations_json'] = Variable<String>(recommendationsJson);
    map['feedback'] = Variable<String>(feedback);
    map['position'] = Variable<int>(position);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationMessagesCompanion toCompanion(bool nullToAbsent) {
    return ConversationMessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      turnId: Value(turnId),
      attemptId: attemptId == null && nullToAbsent
          ? const Value.absent()
          : Value(attemptId),
      role: Value(role),
      kind: Value(kind),
      content: Value(content),
      status: Value(status),
      recommendationsJson: Value(recommendationsJson),
      feedback: Value(feedback),
      position: Value(position),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConversationMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationMessageRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      turnId: serializer.fromJson<String>(json['turnId']),
      attemptId: serializer.fromJson<String?>(json['attemptId']),
      role: serializer.fromJson<String>(json['role']),
      kind: serializer.fromJson<String>(json['kind']),
      content: serializer.fromJson<String>(json['content']),
      status: serializer.fromJson<String>(json['status']),
      recommendationsJson: serializer.fromJson<String>(
        json['recommendationsJson'],
      ),
      feedback: serializer.fromJson<String>(json['feedback']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'turnId': serializer.toJson<String>(turnId),
      'attemptId': serializer.toJson<String?>(attemptId),
      'role': serializer.toJson<String>(role),
      'kind': serializer.toJson<String>(kind),
      'content': serializer.toJson<String>(content),
      'status': serializer.toJson<String>(status),
      'recommendationsJson': serializer.toJson<String>(recommendationsJson),
      'feedback': serializer.toJson<String>(feedback),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConversationMessageRow copyWith({
    String? id,
    String? sessionId,
    String? turnId,
    Value<String?> attemptId = const Value.absent(),
    String? role,
    String? kind,
    String? content,
    String? status,
    String? recommendationsJson,
    String? feedback,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ConversationMessageRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    turnId: turnId ?? this.turnId,
    attemptId: attemptId.present ? attemptId.value : this.attemptId,
    role: role ?? this.role,
    kind: kind ?? this.kind,
    content: content ?? this.content,
    status: status ?? this.status,
    recommendationsJson: recommendationsJson ?? this.recommendationsJson,
    feedback: feedback ?? this.feedback,
    position: position ?? this.position,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConversationMessageRow copyWithCompanion(ConversationMessagesCompanion data) {
    return ConversationMessageRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      turnId: data.turnId.present ? data.turnId.value : this.turnId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      role: data.role.present ? data.role.value : this.role,
      kind: data.kind.present ? data.kind.value : this.kind,
      content: data.content.present ? data.content.value : this.content,
      status: data.status.present ? data.status.value : this.status,
      recommendationsJson: data.recommendationsJson.present
          ? data.recommendationsJson.value
          : this.recommendationsJson,
      feedback: data.feedback.present ? data.feedback.value : this.feedback,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMessageRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('turnId: $turnId, ')
          ..write('attemptId: $attemptId, ')
          ..write('role: $role, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('recommendationsJson: $recommendationsJson, ')
          ..write('feedback: $feedback, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    turnId,
    attemptId,
    role,
    kind,
    content,
    status,
    recommendationsJson,
    feedback,
    position,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationMessageRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.turnId == this.turnId &&
          other.attemptId == this.attemptId &&
          other.role == this.role &&
          other.kind == this.kind &&
          other.content == this.content &&
          other.status == this.status &&
          other.recommendationsJson == this.recommendationsJson &&
          other.feedback == this.feedback &&
          other.position == this.position &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ConversationMessagesCompanion
    extends UpdateCompanion<ConversationMessageRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> turnId;
  final Value<String?> attemptId;
  final Value<String> role;
  final Value<String> kind;
  final Value<String> content;
  final Value<String> status;
  final Value<String> recommendationsJson;
  final Value<String> feedback;
  final Value<int> position;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationMessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.turnId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.role = const Value.absent(),
    this.kind = const Value.absent(),
    this.content = const Value.absent(),
    this.status = const Value.absent(),
    this.recommendationsJson = const Value.absent(),
    this.feedback = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationMessagesCompanion.insert({
    required String id,
    required String sessionId,
    required String turnId,
    this.attemptId = const Value.absent(),
    required String role,
    required String kind,
    required String content,
    required String status,
    this.recommendationsJson = const Value.absent(),
    this.feedback = const Value.absent(),
    required int position,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       turnId = Value(turnId),
       role = Value(role),
       kind = Value(kind),
       content = Value(content),
       status = Value(status),
       position = Value(position),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationMessageRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? turnId,
    Expression<String>? attemptId,
    Expression<String>? role,
    Expression<String>? kind,
    Expression<String>? content,
    Expression<String>? status,
    Expression<String>? recommendationsJson,
    Expression<String>? feedback,
    Expression<int>? position,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (turnId != null) 'turn_id': turnId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (role != null) 'role': role,
      if (kind != null) 'kind': kind,
      if (content != null) 'content': content,
      if (status != null) 'status': status,
      if (recommendationsJson != null)
        'recommendations_json': recommendationsJson,
      if (feedback != null) 'feedback': feedback,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? turnId,
    Value<String?>? attemptId,
    Value<String>? role,
    Value<String>? kind,
    Value<String>? content,
    Value<String>? status,
    Value<String>? recommendationsJson,
    Value<String>? feedback,
    Value<int>? position,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationMessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      turnId: turnId ?? this.turnId,
      attemptId: attemptId ?? this.attemptId,
      role: role ?? this.role,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      status: status ?? this.status,
      recommendationsJson: recommendationsJson ?? this.recommendationsJson,
      feedback: feedback ?? this.feedback,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (turnId.present) {
      map['turn_id'] = Variable<String>(turnId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (recommendationsJson.present) {
      map['recommendations_json'] = Variable<String>(recommendationsJson.value);
    }
    if (feedback.present) {
      map['feedback'] = Variable<String>(feedback.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('turnId: $turnId, ')
          ..write('attemptId: $attemptId, ')
          ..write('role: $role, ')
          ..write('kind: $kind, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('recommendationsJson: $recommendationsJson, ')
          ..write('feedback: $feedback, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContextCheckpointsTable extends ContextCheckpoints
    with TableInfo<$ContextCheckpointsTable, ContextCheckpointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContextCheckpointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversation_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _throughTurnIdMeta = const VerificationMeta(
    'throughTurnId',
  );
  @override
  late final GeneratedColumn<String> throughTurnId = GeneratedColumn<String>(
    'through_turn_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _factsJsonMeta = const VerificationMeta(
    'factsJson',
  );
  @override
  late final GeneratedColumn<String> factsJson = GeneratedColumn<String>(
    'facts_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _modelVersionMeta = const VerificationMeta(
    'modelVersion',
  );
  @override
  late final GeneratedColumn<String> modelVersion = GeneratedColumn<String>(
    'model_version',
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    throughTurnId,
    summary,
    factsJson,
    modelVersion,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'context_checkpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContextCheckpointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('through_turn_id')) {
      context.handle(
        _throughTurnIdMeta,
        throughTurnId.isAcceptableOrUnknown(
          data['through_turn_id']!,
          _throughTurnIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_throughTurnIdMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('facts_json')) {
      context.handle(
        _factsJsonMeta,
        factsJson.isAcceptableOrUnknown(data['facts_json']!, _factsJsonMeta),
      );
    }
    if (data.containsKey('model_version')) {
      context.handle(
        _modelVersionMeta,
        modelVersion.isAcceptableOrUnknown(
          data['model_version']!,
          _modelVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelVersionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContextCheckpointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContextCheckpointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      throughTurnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}through_turn_id'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      factsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}facts_json'],
      )!,
      modelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ContextCheckpointsTable createAlias(String alias) {
    return $ContextCheckpointsTable(attachedDatabase, alias);
  }
}

class ContextCheckpointRow extends DataClass
    implements Insertable<ContextCheckpointRow> {
  final String id;
  final String sessionId;
  final String throughTurnId;
  final String summary;
  final String factsJson;
  final String modelVersion;
  final DateTime createdAt;
  const ContextCheckpointRow({
    required this.id,
    required this.sessionId,
    required this.throughTurnId,
    required this.summary,
    required this.factsJson,
    required this.modelVersion,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['through_turn_id'] = Variable<String>(throughTurnId);
    map['summary'] = Variable<String>(summary);
    map['facts_json'] = Variable<String>(factsJson);
    map['model_version'] = Variable<String>(modelVersion);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ContextCheckpointsCompanion toCompanion(bool nullToAbsent) {
    return ContextCheckpointsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      throughTurnId: Value(throughTurnId),
      summary: Value(summary),
      factsJson: Value(factsJson),
      modelVersion: Value(modelVersion),
      createdAt: Value(createdAt),
    );
  }

  factory ContextCheckpointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContextCheckpointRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      throughTurnId: serializer.fromJson<String>(json['throughTurnId']),
      summary: serializer.fromJson<String>(json['summary']),
      factsJson: serializer.fromJson<String>(json['factsJson']),
      modelVersion: serializer.fromJson<String>(json['modelVersion']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'throughTurnId': serializer.toJson<String>(throughTurnId),
      'summary': serializer.toJson<String>(summary),
      'factsJson': serializer.toJson<String>(factsJson),
      'modelVersion': serializer.toJson<String>(modelVersion),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ContextCheckpointRow copyWith({
    String? id,
    String? sessionId,
    String? throughTurnId,
    String? summary,
    String? factsJson,
    String? modelVersion,
    DateTime? createdAt,
  }) => ContextCheckpointRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    throughTurnId: throughTurnId ?? this.throughTurnId,
    summary: summary ?? this.summary,
    factsJson: factsJson ?? this.factsJson,
    modelVersion: modelVersion ?? this.modelVersion,
    createdAt: createdAt ?? this.createdAt,
  );
  ContextCheckpointRow copyWithCompanion(ContextCheckpointsCompanion data) {
    return ContextCheckpointRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      throughTurnId: data.throughTurnId.present
          ? data.throughTurnId.value
          : this.throughTurnId,
      summary: data.summary.present ? data.summary.value : this.summary,
      factsJson: data.factsJson.present ? data.factsJson.value : this.factsJson,
      modelVersion: data.modelVersion.present
          ? data.modelVersion.value
          : this.modelVersion,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContextCheckpointRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('throughTurnId: $throughTurnId, ')
          ..write('summary: $summary, ')
          ..write('factsJson: $factsJson, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    throughTurnId,
    summary,
    factsJson,
    modelVersion,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContextCheckpointRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.throughTurnId == this.throughTurnId &&
          other.summary == this.summary &&
          other.factsJson == this.factsJson &&
          other.modelVersion == this.modelVersion &&
          other.createdAt == this.createdAt);
}

class ContextCheckpointsCompanion
    extends UpdateCompanion<ContextCheckpointRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> throughTurnId;
  final Value<String> summary;
  final Value<String> factsJson;
  final Value<String> modelVersion;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ContextCheckpointsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.throughTurnId = const Value.absent(),
    this.summary = const Value.absent(),
    this.factsJson = const Value.absent(),
    this.modelVersion = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContextCheckpointsCompanion.insert({
    required String id,
    required String sessionId,
    required String throughTurnId,
    required String summary,
    this.factsJson = const Value.absent(),
    required String modelVersion,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       throughTurnId = Value(throughTurnId),
       summary = Value(summary),
       modelVersion = Value(modelVersion),
       createdAt = Value(createdAt);
  static Insertable<ContextCheckpointRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? throughTurnId,
    Expression<String>? summary,
    Expression<String>? factsJson,
    Expression<String>? modelVersion,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (throughTurnId != null) 'through_turn_id': throughTurnId,
      if (summary != null) 'summary': summary,
      if (factsJson != null) 'facts_json': factsJson,
      if (modelVersion != null) 'model_version': modelVersion,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContextCheckpointsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? throughTurnId,
    Value<String>? summary,
    Value<String>? factsJson,
    Value<String>? modelVersion,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ContextCheckpointsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      throughTurnId: throughTurnId ?? this.throughTurnId,
      summary: summary ?? this.summary,
      factsJson: factsJson ?? this.factsJson,
      modelVersion: modelVersion ?? this.modelVersion,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (throughTurnId.present) {
      map['through_turn_id'] = Variable<String>(throughTurnId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (factsJson.present) {
      map['facts_json'] = Variable<String>(factsJson.value);
    }
    if (modelVersion.present) {
      map['model_version'] = Variable<String>(modelVersion.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContextCheckpointsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('throughTurnId: $throughTurnId, ')
          ..write('summary: $summary, ')
          ..write('factsJson: $factsJson, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionAliasesTable extends SessionAliases
    with TableInfo<$SessionAliasesTable, SessionAliasRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _legacyIdMeta = const VerificationMeta(
    'legacyId',
  );
  @override
  late final GeneratedColumn<String> legacyId = GeneratedColumn<String>(
    'legacy_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversation_sessions (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [legacyId, sessionId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionAliasRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('legacy_id')) {
      context.handle(
        _legacyIdMeta,
        legacyId.isAcceptableOrUnknown(data['legacy_id']!, _legacyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_legacyIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {legacyId};
  @override
  SessionAliasRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionAliasRow(
      legacyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}legacy_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
    );
  }

  @override
  $SessionAliasesTable createAlias(String alias) {
    return $SessionAliasesTable(attachedDatabase, alias);
  }
}

class SessionAliasRow extends DataClass implements Insertable<SessionAliasRow> {
  final String legacyId;
  final String sessionId;
  const SessionAliasRow({required this.legacyId, required this.sessionId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['legacy_id'] = Variable<String>(legacyId);
    map['session_id'] = Variable<String>(sessionId);
    return map;
  }

  SessionAliasesCompanion toCompanion(bool nullToAbsent) {
    return SessionAliasesCompanion(
      legacyId: Value(legacyId),
      sessionId: Value(sessionId),
    );
  }

  factory SessionAliasRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionAliasRow(
      legacyId: serializer.fromJson<String>(json['legacyId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'legacyId': serializer.toJson<String>(legacyId),
      'sessionId': serializer.toJson<String>(sessionId),
    };
  }

  SessionAliasRow copyWith({String? legacyId, String? sessionId}) =>
      SessionAliasRow(
        legacyId: legacyId ?? this.legacyId,
        sessionId: sessionId ?? this.sessionId,
      );
  SessionAliasRow copyWithCompanion(SessionAliasesCompanion data) {
    return SessionAliasRow(
      legacyId: data.legacyId.present ? data.legacyId.value : this.legacyId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionAliasRow(')
          ..write('legacyId: $legacyId, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(legacyId, sessionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionAliasRow &&
          other.legacyId == this.legacyId &&
          other.sessionId == this.sessionId);
}

class SessionAliasesCompanion extends UpdateCompanion<SessionAliasRow> {
  final Value<String> legacyId;
  final Value<String> sessionId;
  final Value<int> rowid;
  const SessionAliasesCompanion({
    this.legacyId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionAliasesCompanion.insert({
    required String legacyId,
    required String sessionId,
    this.rowid = const Value.absent(),
  }) : legacyId = Value(legacyId),
       sessionId = Value(sessionId);
  static Insertable<SessionAliasRow> custom({
    Expression<String>? legacyId,
    Expression<String>? sessionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (legacyId != null) 'legacy_id': legacyId,
      if (sessionId != null) 'session_id': sessionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionAliasesCompanion copyWith({
    Value<String>? legacyId,
    Value<String>? sessionId,
    Value<int>? rowid,
  }) {
    return SessionAliasesCompanion(
      legacyId: legacyId ?? this.legacyId,
      sessionId: sessionId ?? this.sessionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (legacyId.present) {
      map['legacy_id'] = Variable<String>(legacyId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionAliasesCompanion(')
          ..write('legacyId: $legacyId, ')
          ..write('sessionId: $sessionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationMetadataTable extends ConversationMetadata
    with TableInfo<$ConversationMetadataTable, ConversationMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ConversationMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationMetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ConversationMetadataTable createAlias(String alias) {
    return $ConversationMetadataTable(attachedDatabase, alias);
  }
}

class ConversationMetaRow extends DataClass
    implements Insertable<ConversationMetaRow> {
  final String key;
  final String value;
  const ConversationMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ConversationMetadataCompanion toCompanion(bool nullToAbsent) {
    return ConversationMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory ConversationMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationMetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ConversationMetaRow copyWith({String? key, String? value}) =>
      ConversationMetaRow(key: key ?? this.key, value: value ?? this.value);
  ConversationMetaRow copyWithCompanion(ConversationMetadataCompanion data) {
    return ConversationMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class ConversationMetadataCompanion
    extends UpdateCompanion<ConversationMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const ConversationMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<ConversationMetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return ConversationMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ConversationDatabase extends GeneratedDatabase {
  _$ConversationDatabase(QueryExecutor e) : super(e);
  $ConversationDatabaseManager get managers =>
      $ConversationDatabaseManager(this);
  late final $ConversationSessionsTable conversationSessions =
      $ConversationSessionsTable(this);
  late final $ConversationTurnsTable conversationTurns =
      $ConversationTurnsTable(this);
  late final $AssistantAttemptsTable assistantAttempts =
      $AssistantAttemptsTable(this);
  late final $ConversationMessagesTable conversationMessages =
      $ConversationMessagesTable(this);
  late final $ContextCheckpointsTable contextCheckpoints =
      $ContextCheckpointsTable(this);
  late final $SessionAliasesTable sessionAliases = $SessionAliasesTable(this);
  late final $ConversationMetadataTable conversationMetadata =
      $ConversationMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversationSessions,
    conversationTurns,
    assistantAttempts,
    conversationMessages,
    contextCheckpoints,
    sessionAliases,
    conversationMetadata,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('conversation_turns', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation_turns',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('assistant_attempts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('conversation_messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation_turns',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('conversation_messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('context_checkpoints', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversation_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_aliases', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ConversationSessionsTableCreateCompanionBuilder =
    ConversationSessionsCompanion Function({
      required String id,
      required String kind,
      required String rootSessionId,
      Value<String?> sourceSessionId,
      Value<String?> sourceTurnId,
      Value<String?> professorId,
      Value<String> ownerId,
      Value<int> revision,
      Value<String?> title,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> legacyContextIncomplete,
      Value<int> rowid,
    });
typedef $$ConversationSessionsTableUpdateCompanionBuilder =
    ConversationSessionsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> rootSessionId,
      Value<String?> sourceSessionId,
      Value<String?> sourceTurnId,
      Value<String?> professorId,
      Value<String> ownerId,
      Value<int> revision,
      Value<String?> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> legacyContextIncomplete,
      Value<int> rowid,
    });

final class $$ConversationSessionsTableReferences
    extends
        BaseReferences<
          _$ConversationDatabase,
          $ConversationSessionsTable,
          ConversationSessionRow
        > {
  $$ConversationSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ConversationTurnsTable, List<ConversationTurnRow>>
  _conversationTurnsRefsTable(_$ConversationDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.conversationTurns,
        aliasName: 'conversation_sessions__id__conversation_turns__session_id',
      );

  $$ConversationTurnsTableProcessedTableManager get conversationTurnsRefs {
    final manager = $$ConversationTurnsTableTableManager(
      $_db,
      $_db.conversationTurns,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _conversationTurnsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ConversationMessagesTable,
    List<ConversationMessageRow>
  >
  _conversationMessagesRefsTable(_$ConversationDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.conversationMessages,
        aliasName:
            'conversation_sessions__id__conversation_messages__session_id',
      );

  $$ConversationMessagesTableProcessedTableManager
  get conversationMessagesRefs {
    final manager = $$ConversationMessagesTableTableManager(
      $_db,
      $_db.conversationMessages,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _conversationMessagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ContextCheckpointsTable,
    List<ContextCheckpointRow>
  >
  _contextCheckpointsRefsTable(_$ConversationDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.contextCheckpoints,
        aliasName: 'conversation_sessions__id__context_checkpoints__session_id',
      );

  $$ContextCheckpointsTableProcessedTableManager get contextCheckpointsRefs {
    final manager = $$ContextCheckpointsTableTableManager(
      $_db,
      $_db.contextCheckpoints,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _contextCheckpointsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SessionAliasesTable, List<SessionAliasRow>>
  _sessionAliasesRefsTable(_$ConversationDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sessionAliases,
        aliasName: 'conversation_sessions__id__session_aliases__session_id',
      );

  $$SessionAliasesTableProcessedTableManager get sessionAliasesRefs {
    final manager = $$SessionAliasesTableTableManager(
      $_db,
      $_db.sessionAliases,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionAliasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationSessionsTableFilterComposer
    extends Composer<_$ConversationDatabase, $ConversationSessionsTable> {
  $$ConversationSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootSessionId => $composableBuilder(
    column: $table.rootSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSessionId => $composableBuilder(
    column: $table.sourceSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTurnId => $composableBuilder(
    column: $table.sourceTurnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get professorId => $composableBuilder(
    column: $table.professorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get legacyContextIncomplete => $composableBuilder(
    column: $table.legacyContextIncomplete,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> conversationTurnsRefs(
    Expression<bool> Function($$ConversationTurnsTableFilterComposer f) f,
  ) {
    final $$ConversationTurnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversationTurns,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationTurnsTableFilterComposer(
            $db: $db,
            $table: $db.conversationTurns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> conversationMessagesRefs(
    Expression<bool> Function($$ConversationMessagesTableFilterComposer f) f,
  ) {
    final $$ConversationMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversationMessages,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationMessagesTableFilterComposer(
            $db: $db,
            $table: $db.conversationMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> contextCheckpointsRefs(
    Expression<bool> Function($$ContextCheckpointsTableFilterComposer f) f,
  ) {
    final $$ContextCheckpointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contextCheckpoints,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContextCheckpointsTableFilterComposer(
            $db: $db,
            $table: $db.contextCheckpoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sessionAliasesRefs(
    Expression<bool> Function($$SessionAliasesTableFilterComposer f) f,
  ) {
    final $$SessionAliasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionAliases,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionAliasesTableFilterComposer(
            $db: $db,
            $table: $db.sessionAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationSessionsTableOrderingComposer
    extends Composer<_$ConversationDatabase, $ConversationSessionsTable> {
  $$ConversationSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootSessionId => $composableBuilder(
    column: $table.rootSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSessionId => $composableBuilder(
    column: $table.sourceSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTurnId => $composableBuilder(
    column: $table.sourceTurnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get professorId => $composableBuilder(
    column: $table.professorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get legacyContextIncomplete => $composableBuilder(
    column: $table.legacyContextIncomplete,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationSessionsTableAnnotationComposer
    extends Composer<_$ConversationDatabase, $ConversationSessionsTable> {
  $$ConversationSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get rootSessionId => $composableBuilder(
    column: $table.rootSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceSessionId => $composableBuilder(
    column: $table.sourceSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTurnId => $composableBuilder(
    column: $table.sourceTurnId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get professorId => $composableBuilder(
    column: $table.professorId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get legacyContextIncomplete => $composableBuilder(
    column: $table.legacyContextIncomplete,
    builder: (column) => column,
  );

  Expression<T> conversationTurnsRefs<T extends Object>(
    Expression<T> Function($$ConversationTurnsTableAnnotationComposer a) f,
  ) {
    final $$ConversationTurnsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.conversationTurns,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationTurnsTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationTurns,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> conversationMessagesRefs<T extends Object>(
    Expression<T> Function($$ConversationMessagesTableAnnotationComposer a) f,
  ) {
    final $$ConversationMessagesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.conversationMessages,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationMessagesTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationMessages,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> contextCheckpointsRefs<T extends Object>(
    Expression<T> Function($$ContextCheckpointsTableAnnotationComposer a) f,
  ) {
    final $$ContextCheckpointsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.contextCheckpoints,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ContextCheckpointsTableAnnotationComposer(
                $db: $db,
                $table: $db.contextCheckpoints,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> sessionAliasesRefs<T extends Object>(
    Expression<T> Function($$SessionAliasesTableAnnotationComposer a) f,
  ) {
    final $$SessionAliasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionAliases,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionAliasesTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationSessionsTableTableManager
    extends
        RootTableManager<
          _$ConversationDatabase,
          $ConversationSessionsTable,
          ConversationSessionRow,
          $$ConversationSessionsTableFilterComposer,
          $$ConversationSessionsTableOrderingComposer,
          $$ConversationSessionsTableAnnotationComposer,
          $$ConversationSessionsTableCreateCompanionBuilder,
          $$ConversationSessionsTableUpdateCompanionBuilder,
          (ConversationSessionRow, $$ConversationSessionsTableReferences),
          ConversationSessionRow,
          PrefetchHooks Function({
            bool conversationTurnsRefs,
            bool conversationMessagesRefs,
            bool contextCheckpointsRefs,
            bool sessionAliasesRefs,
          })
        > {
  $$ConversationSessionsTableTableManager(
    _$ConversationDatabase db,
    $ConversationSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationSessionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> rootSessionId = const Value.absent(),
                Value<String?> sourceSessionId = const Value.absent(),
                Value<String?> sourceTurnId = const Value.absent(),
                Value<String?> professorId = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> legacyContextIncomplete = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationSessionsCompanion(
                id: id,
                kind: kind,
                rootSessionId: rootSessionId,
                sourceSessionId: sourceSessionId,
                sourceTurnId: sourceTurnId,
                professorId: professorId,
                ownerId: ownerId,
                revision: revision,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                legacyContextIncomplete: legacyContextIncomplete,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String rootSessionId,
                Value<String?> sourceSessionId = const Value.absent(),
                Value<String?> sourceTurnId = const Value.absent(),
                Value<String?> professorId = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> legacyContextIncomplete = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationSessionsCompanion.insert(
                id: id,
                kind: kind,
                rootSessionId: rootSessionId,
                sourceSessionId: sourceSessionId,
                sourceTurnId: sourceTurnId,
                professorId: professorId,
                ownerId: ownerId,
                revision: revision,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                legacyContextIncomplete: legacyContextIncomplete,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                conversationTurnsRefs = false,
                conversationMessagesRefs = false,
                contextCheckpointsRefs = false,
                sessionAliasesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (conversationTurnsRefs) db.conversationTurns,
                    if (conversationMessagesRefs) db.conversationMessages,
                    if (contextCheckpointsRefs) db.contextCheckpoints,
                    if (sessionAliasesRefs) db.sessionAliases,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (conversationTurnsRefs)
                        await $_getPrefetchedData<
                          ConversationSessionRow,
                          $ConversationSessionsTable,
                          ConversationTurnRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationSessionsTableReferences
                              ._conversationTurnsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).conversationTurnsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (conversationMessagesRefs)
                        await $_getPrefetchedData<
                          ConversationSessionRow,
                          $ConversationSessionsTable,
                          ConversationMessageRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationSessionsTableReferences
                              ._conversationMessagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).conversationMessagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (contextCheckpointsRefs)
                        await $_getPrefetchedData<
                          ConversationSessionRow,
                          $ConversationSessionsTable,
                          ContextCheckpointRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationSessionsTableReferences
                              ._contextCheckpointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).contextCheckpointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (sessionAliasesRefs)
                        await $_getPrefetchedData<
                          ConversationSessionRow,
                          $ConversationSessionsTable,
                          SessionAliasRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationSessionsTableReferences
                              ._sessionAliasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionAliasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ConversationSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationDatabase,
      $ConversationSessionsTable,
      ConversationSessionRow,
      $$ConversationSessionsTableFilterComposer,
      $$ConversationSessionsTableOrderingComposer,
      $$ConversationSessionsTableAnnotationComposer,
      $$ConversationSessionsTableCreateCompanionBuilder,
      $$ConversationSessionsTableUpdateCompanionBuilder,
      (ConversationSessionRow, $$ConversationSessionsTableReferences),
      ConversationSessionRow,
      PrefetchHooks Function({
        bool conversationTurnsRefs,
        bool conversationMessagesRefs,
        bool contextCheckpointsRefs,
        bool sessionAliasesRefs,
      })
    >;
typedef $$ConversationTurnsTableCreateCompanionBuilder =
    ConversationTurnsCompanion Function({
      required String id,
      required String sessionId,
      required int ordinal,
      required String status,
      Value<String?> route,
      required String userMessageId,
      Value<String?> activeAttemptId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationTurnsTableUpdateCompanionBuilder =
    ConversationTurnsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> ordinal,
      Value<String> status,
      Value<String?> route,
      Value<String> userMessageId,
      Value<String?> activeAttemptId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ConversationTurnsTableReferences
    extends
        BaseReferences<
          _$ConversationDatabase,
          $ConversationTurnsTable,
          ConversationTurnRow
        > {
  $$ConversationTurnsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationSessionsTable _sessionIdTable(
    _$ConversationDatabase db,
  ) => db.conversationSessions.createAlias(
    'conversation_turns__session_id__conversation_sessions__id',
  );

  $$ConversationSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$ConversationSessionsTableTableManager(
      $_db,
      $_db.conversationSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AssistantAttemptsTable, List<AssistantAttemptRow>>
  _assistantAttemptsRefsTable(_$ConversationDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.assistantAttempts,
        aliasName: 'conversation_turns__id__assistant_attempts__turn_id',
      );

  $$AssistantAttemptsTableProcessedTableManager get assistantAttemptsRefs {
    final manager = $$AssistantAttemptsTableTableManager(
      $_db,
      $_db.assistantAttempts,
    ).filter((f) => f.turnId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _assistantAttemptsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ConversationMessagesTable,
    List<ConversationMessageRow>
  >
  _conversationMessagesRefsTable(_$ConversationDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.conversationMessages,
        aliasName: 'conversation_turns__id__conversation_messages__turn_id',
      );

  $$ConversationMessagesTableProcessedTableManager
  get conversationMessagesRefs {
    final manager = $$ConversationMessagesTableTableManager(
      $_db,
      $_db.conversationMessages,
    ).filter((f) => f.turnId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _conversationMessagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationTurnsTableFilterComposer
    extends Composer<_$ConversationDatabase, $ConversationTurnsTable> {
  $$ConversationTurnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userMessageId => $composableBuilder(
    column: $table.userMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeAttemptId => $composableBuilder(
    column: $table.activeAttemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationSessionsTableFilterComposer get sessionId {
    final $$ConversationSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.conversationSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationSessionsTableFilterComposer(
            $db: $db,
            $table: $db.conversationSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> assistantAttemptsRefs(
    Expression<bool> Function($$AssistantAttemptsTableFilterComposer f) f,
  ) {
    final $$AssistantAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assistantAttempts,
      getReferencedColumn: (t) => t.turnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssistantAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.assistantAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> conversationMessagesRefs(
    Expression<bool> Function($$ConversationMessagesTableFilterComposer f) f,
  ) {
    final $$ConversationMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversationMessages,
      getReferencedColumn: (t) => t.turnId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationMessagesTableFilterComposer(
            $db: $db,
            $table: $db.conversationMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationTurnsTableOrderingComposer
    extends Composer<_$ConversationDatabase, $ConversationTurnsTable> {
  $$ConversationTurnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userMessageId => $composableBuilder(
    column: $table.userMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeAttemptId => $composableBuilder(
    column: $table.activeAttemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationSessionsTableOrderingComposer get sessionId {
    final $$ConversationSessionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.conversationSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationSessionsTableOrderingComposer(
                $db: $db,
                $table: $db.conversationSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ConversationTurnsTableAnnotationComposer
    extends Composer<_$ConversationDatabase, $ConversationTurnsTable> {
  $$ConversationTurnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => column);

  GeneratedColumn<String> get userMessageId => $composableBuilder(
    column: $table.userMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeAttemptId => $composableBuilder(
    column: $table.activeAttemptId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ConversationSessionsTableAnnotationComposer get sessionId {
    final $$ConversationSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.conversationSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> assistantAttemptsRefs<T extends Object>(
    Expression<T> Function($$AssistantAttemptsTableAnnotationComposer a) f,
  ) {
    final $$AssistantAttemptsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.assistantAttempts,
          getReferencedColumn: (t) => t.turnId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AssistantAttemptsTableAnnotationComposer(
                $db: $db,
                $table: $db.assistantAttempts,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> conversationMessagesRefs<T extends Object>(
    Expression<T> Function($$ConversationMessagesTableAnnotationComposer a) f,
  ) {
    final $$ConversationMessagesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.conversationMessages,
          getReferencedColumn: (t) => t.turnId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationMessagesTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationMessages,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ConversationTurnsTableTableManager
    extends
        RootTableManager<
          _$ConversationDatabase,
          $ConversationTurnsTable,
          ConversationTurnRow,
          $$ConversationTurnsTableFilterComposer,
          $$ConversationTurnsTableOrderingComposer,
          $$ConversationTurnsTableAnnotationComposer,
          $$ConversationTurnsTableCreateCompanionBuilder,
          $$ConversationTurnsTableUpdateCompanionBuilder,
          (ConversationTurnRow, $$ConversationTurnsTableReferences),
          ConversationTurnRow,
          PrefetchHooks Function({
            bool sessionId,
            bool assistantAttemptsRefs,
            bool conversationMessagesRefs,
          })
        > {
  $$ConversationTurnsTableTableManager(
    _$ConversationDatabase db,
    $ConversationTurnsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationTurnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationTurnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationTurnsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> route = const Value.absent(),
                Value<String> userMessageId = const Value.absent(),
                Value<String?> activeAttemptId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationTurnsCompanion(
                id: id,
                sessionId: sessionId,
                ordinal: ordinal,
                status: status,
                route: route,
                userMessageId: userMessageId,
                activeAttemptId: activeAttemptId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int ordinal,
                required String status,
                Value<String?> route = const Value.absent(),
                required String userMessageId,
                Value<String?> activeAttemptId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationTurnsCompanion.insert(
                id: id,
                sessionId: sessionId,
                ordinal: ordinal,
                status: status,
                route: route,
                userMessageId: userMessageId,
                activeAttemptId: activeAttemptId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationTurnsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sessionId = false,
                assistantAttemptsRefs = false,
                conversationMessagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (assistantAttemptsRefs) db.assistantAttempts,
                    if (conversationMessagesRefs) db.conversationMessages,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sessionId,
                                    referencedTable:
                                        $$ConversationTurnsTableReferences
                                            ._sessionIdTable(db),
                                    referencedColumn:
                                        $$ConversationTurnsTableReferences
                                            ._sessionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (assistantAttemptsRefs)
                        await $_getPrefetchedData<
                          ConversationTurnRow,
                          $ConversationTurnsTable,
                          AssistantAttemptRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationTurnsTableReferences
                              ._assistantAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationTurnsTableReferences(
                                db,
                                table,
                                p0,
                              ).assistantAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.turnId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (conversationMessagesRefs)
                        await $_getPrefetchedData<
                          ConversationTurnRow,
                          $ConversationTurnsTable,
                          ConversationMessageRow
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationTurnsTableReferences
                              ._conversationMessagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationTurnsTableReferences(
                                db,
                                table,
                                p0,
                              ).conversationMessagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.turnId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ConversationTurnsTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationDatabase,
      $ConversationTurnsTable,
      ConversationTurnRow,
      $$ConversationTurnsTableFilterComposer,
      $$ConversationTurnsTableOrderingComposer,
      $$ConversationTurnsTableAnnotationComposer,
      $$ConversationTurnsTableCreateCompanionBuilder,
      $$ConversationTurnsTableUpdateCompanionBuilder,
      (ConversationTurnRow, $$ConversationTurnsTableReferences),
      ConversationTurnRow,
      PrefetchHooks Function({
        bool sessionId,
        bool assistantAttemptsRefs,
        bool conversationMessagesRefs,
      })
    >;
typedef $$AssistantAttemptsTableCreateCompanionBuilder =
    AssistantAttemptsCompanion Function({
      required String id,
      required String turnId,
      required String requestId,
      required String status,
      Value<String?> assistantMessageId,
      Value<String?> errorCode,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AssistantAttemptsTableUpdateCompanionBuilder =
    AssistantAttemptsCompanion Function({
      Value<String> id,
      Value<String> turnId,
      Value<String> requestId,
      Value<String> status,
      Value<String?> assistantMessageId,
      Value<String?> errorCode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$AssistantAttemptsTableReferences
    extends
        BaseReferences<
          _$ConversationDatabase,
          $AssistantAttemptsTable,
          AssistantAttemptRow
        > {
  $$AssistantAttemptsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationTurnsTable _turnIdTable(_$ConversationDatabase db) => db
      .conversationTurns
      .createAlias('assistant_attempts__turn_id__conversation_turns__id');

  $$ConversationTurnsTableProcessedTableManager get turnId {
    final $_column = $_itemColumn<String>('turn_id')!;

    final manager = $$ConversationTurnsTableTableManager(
      $_db,
      $_db.conversationTurns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_turnIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssistantAttemptsTableFilterComposer
    extends Composer<_$ConversationDatabase, $AssistantAttemptsTable> {
  $$AssistantAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationTurnsTableFilterComposer get turnId {
    final $$ConversationTurnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.conversationTurns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationTurnsTableFilterComposer(
            $db: $db,
            $table: $db.conversationTurns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssistantAttemptsTableOrderingComposer
    extends Composer<_$ConversationDatabase, $AssistantAttemptsTable> {
  $$AssistantAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationTurnsTableOrderingComposer get turnId {
    final $$ConversationTurnsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.conversationTurns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationTurnsTableOrderingComposer(
            $db: $db,
            $table: $db.conversationTurns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssistantAttemptsTableAnnotationComposer
    extends Composer<_$ConversationDatabase, $AssistantAttemptsTable> {
  $$AssistantAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ConversationTurnsTableAnnotationComposer get turnId {
    final $$ConversationTurnsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.turnId,
          referencedTable: $db.conversationTurns,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationTurnsTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationTurns,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$AssistantAttemptsTableTableManager
    extends
        RootTableManager<
          _$ConversationDatabase,
          $AssistantAttemptsTable,
          AssistantAttemptRow,
          $$AssistantAttemptsTableFilterComposer,
          $$AssistantAttemptsTableOrderingComposer,
          $$AssistantAttemptsTableAnnotationComposer,
          $$AssistantAttemptsTableCreateCompanionBuilder,
          $$AssistantAttemptsTableUpdateCompanionBuilder,
          (AssistantAttemptRow, $$AssistantAttemptsTableReferences),
          AssistantAttemptRow,
          PrefetchHooks Function({bool turnId})
        > {
  $$AssistantAttemptsTableTableManager(
    _$ConversationDatabase db,
    $AssistantAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssistantAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssistantAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssistantAttemptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> turnId = const Value.absent(),
                Value<String> requestId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> assistantMessageId = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantAttemptsCompanion(
                id: id,
                turnId: turnId,
                requestId: requestId,
                status: status,
                assistantMessageId: assistantMessageId,
                errorCode: errorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String turnId,
                required String requestId,
                required String status,
                Value<String?> assistantMessageId = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AssistantAttemptsCompanion.insert(
                id: id,
                turnId: turnId,
                requestId: requestId,
                status: status,
                assistantMessageId: assistantMessageId,
                errorCode: errorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssistantAttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({turnId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (turnId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.turnId,
                                referencedTable:
                                    $$AssistantAttemptsTableReferences
                                        ._turnIdTable(db),
                                referencedColumn:
                                    $$AssistantAttemptsTableReferences
                                        ._turnIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AssistantAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationDatabase,
      $AssistantAttemptsTable,
      AssistantAttemptRow,
      $$AssistantAttemptsTableFilterComposer,
      $$AssistantAttemptsTableOrderingComposer,
      $$AssistantAttemptsTableAnnotationComposer,
      $$AssistantAttemptsTableCreateCompanionBuilder,
      $$AssistantAttemptsTableUpdateCompanionBuilder,
      (AssistantAttemptRow, $$AssistantAttemptsTableReferences),
      AssistantAttemptRow,
      PrefetchHooks Function({bool turnId})
    >;
typedef $$ConversationMessagesTableCreateCompanionBuilder =
    ConversationMessagesCompanion Function({
      required String id,
      required String sessionId,
      required String turnId,
      Value<String?> attemptId,
      required String role,
      required String kind,
      required String content,
      required String status,
      Value<String> recommendationsJson,
      Value<String> feedback,
      required int position,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationMessagesTableUpdateCompanionBuilder =
    ConversationMessagesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> turnId,
      Value<String?> attemptId,
      Value<String> role,
      Value<String> kind,
      Value<String> content,
      Value<String> status,
      Value<String> recommendationsJson,
      Value<String> feedback,
      Value<int> position,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ConversationMessagesTableReferences
    extends
        BaseReferences<
          _$ConversationDatabase,
          $ConversationMessagesTable,
          ConversationMessageRow
        > {
  $$ConversationMessagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationSessionsTable _sessionIdTable(
    _$ConversationDatabase db,
  ) => db.conversationSessions.createAlias(
    'conversation_messages__session_id__conversation_sessions__id',
  );

  $$ConversationSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$ConversationSessionsTableTableManager(
      $_db,
      $_db.conversationSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ConversationTurnsTable _turnIdTable(_$ConversationDatabase db) => db
      .conversationTurns
      .createAlias('conversation_messages__turn_id__conversation_turns__id');

  $$ConversationTurnsTableProcessedTableManager get turnId {
    final $_column = $_itemColumn<String>('turn_id')!;

    final manager = $$ConversationTurnsTableTableManager(
      $_db,
      $_db.conversationTurns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_turnIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ConversationMessagesTableFilterComposer
    extends Composer<_$ConversationDatabase, $ConversationMessagesTable> {
  $$ConversationMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recommendationsJson => $composableBuilder(
    column: $table.recommendationsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedback => $composableBuilder(
    column: $table.feedback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationSessionsTableFilterComposer get sessionId {
    final $$ConversationSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.conversationSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationSessionsTableFilterComposer(
            $db: $db,
            $table: $db.conversationSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ConversationTurnsTableFilterComposer get turnId {
    final $$ConversationTurnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.conversationTurns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationTurnsTableFilterComposer(
            $db: $db,
            $table: $db.conversationTurns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationMessagesTableOrderingComposer
    extends Composer<_$ConversationDatabase, $ConversationMessagesTable> {
  $$ConversationMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attemptId => $composableBuilder(
    column: $table.attemptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recommendationsJson => $composableBuilder(
    column: $table.recommendationsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedback => $composableBuilder(
    column: $table.feedback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationSessionsTableOrderingComposer get sessionId {
    final $$ConversationSessionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.conversationSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationSessionsTableOrderingComposer(
                $db: $db,
                $table: $db.conversationSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ConversationTurnsTableOrderingComposer get turnId {
    final $$ConversationTurnsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.turnId,
      referencedTable: $db.conversationTurns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationTurnsTableOrderingComposer(
            $db: $db,
            $table: $db.conversationTurns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationMessagesTableAnnotationComposer
    extends Composer<_$ConversationDatabase, $ConversationMessagesTable> {
  $$ConversationMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get attemptId =>
      $composableBuilder(column: $table.attemptId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get recommendationsJson => $composableBuilder(
    column: $table.recommendationsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get feedback =>
      $composableBuilder(column: $table.feedback, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ConversationSessionsTableAnnotationComposer get sessionId {
    final $$ConversationSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.conversationSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ConversationTurnsTableAnnotationComposer get turnId {
    final $$ConversationTurnsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.turnId,
          referencedTable: $db.conversationTurns,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationTurnsTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationTurns,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ConversationMessagesTableTableManager
    extends
        RootTableManager<
          _$ConversationDatabase,
          $ConversationMessagesTable,
          ConversationMessageRow,
          $$ConversationMessagesTableFilterComposer,
          $$ConversationMessagesTableOrderingComposer,
          $$ConversationMessagesTableAnnotationComposer,
          $$ConversationMessagesTableCreateCompanionBuilder,
          $$ConversationMessagesTableUpdateCompanionBuilder,
          (ConversationMessageRow, $$ConversationMessagesTableReferences),
          ConversationMessageRow,
          PrefetchHooks Function({bool sessionId, bool turnId})
        > {
  $$ConversationMessagesTableTableManager(
    _$ConversationDatabase db,
    $ConversationMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationMessagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> turnId = const Value.absent(),
                Value<String?> attemptId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> recommendationsJson = const Value.absent(),
                Value<String> feedback = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationMessagesCompanion(
                id: id,
                sessionId: sessionId,
                turnId: turnId,
                attemptId: attemptId,
                role: role,
                kind: kind,
                content: content,
                status: status,
                recommendationsJson: recommendationsJson,
                feedback: feedback,
                position: position,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String turnId,
                Value<String?> attemptId = const Value.absent(),
                required String role,
                required String kind,
                required String content,
                required String status,
                Value<String> recommendationsJson = const Value.absent(),
                Value<String> feedback = const Value.absent(),
                required int position,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationMessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                turnId: turnId,
                attemptId: attemptId,
                role: role,
                kind: kind,
                content: content,
                status: status,
                recommendationsJson: recommendationsJson,
                feedback: feedback,
                position: position,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationMessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, turnId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$ConversationMessagesTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$ConversationMessagesTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (turnId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.turnId,
                                referencedTable:
                                    $$ConversationMessagesTableReferences
                                        ._turnIdTable(db),
                                referencedColumn:
                                    $$ConversationMessagesTableReferences
                                        ._turnIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ConversationMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationDatabase,
      $ConversationMessagesTable,
      ConversationMessageRow,
      $$ConversationMessagesTableFilterComposer,
      $$ConversationMessagesTableOrderingComposer,
      $$ConversationMessagesTableAnnotationComposer,
      $$ConversationMessagesTableCreateCompanionBuilder,
      $$ConversationMessagesTableUpdateCompanionBuilder,
      (ConversationMessageRow, $$ConversationMessagesTableReferences),
      ConversationMessageRow,
      PrefetchHooks Function({bool sessionId, bool turnId})
    >;
typedef $$ContextCheckpointsTableCreateCompanionBuilder =
    ContextCheckpointsCompanion Function({
      required String id,
      required String sessionId,
      required String throughTurnId,
      required String summary,
      Value<String> factsJson,
      required String modelVersion,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ContextCheckpointsTableUpdateCompanionBuilder =
    ContextCheckpointsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> throughTurnId,
      Value<String> summary,
      Value<String> factsJson,
      Value<String> modelVersion,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ContextCheckpointsTableReferences
    extends
        BaseReferences<
          _$ConversationDatabase,
          $ContextCheckpointsTable,
          ContextCheckpointRow
        > {
  $$ContextCheckpointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationSessionsTable _sessionIdTable(
    _$ConversationDatabase db,
  ) => db.conversationSessions.createAlias(
    'context_checkpoints__session_id__conversation_sessions__id',
  );

  $$ConversationSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$ConversationSessionsTableTableManager(
      $_db,
      $_db.conversationSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ContextCheckpointsTableFilterComposer
    extends Composer<_$ConversationDatabase, $ContextCheckpointsTable> {
  $$ContextCheckpointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get throughTurnId => $composableBuilder(
    column: $table.throughTurnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get factsJson => $composableBuilder(
    column: $table.factsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationSessionsTableFilterComposer get sessionId {
    final $$ConversationSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.conversationSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationSessionsTableFilterComposer(
            $db: $db,
            $table: $db.conversationSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContextCheckpointsTableOrderingComposer
    extends Composer<_$ConversationDatabase, $ContextCheckpointsTable> {
  $$ContextCheckpointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get throughTurnId => $composableBuilder(
    column: $table.throughTurnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get factsJson => $composableBuilder(
    column: $table.factsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationSessionsTableOrderingComposer get sessionId {
    final $$ConversationSessionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.conversationSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationSessionsTableOrderingComposer(
                $db: $db,
                $table: $db.conversationSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ContextCheckpointsTableAnnotationComposer
    extends Composer<_$ConversationDatabase, $ContextCheckpointsTable> {
  $$ContextCheckpointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get throughTurnId => $composableBuilder(
    column: $table.throughTurnId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get factsJson =>
      $composableBuilder(column: $table.factsJson, builder: (column) => column);

  GeneratedColumn<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ConversationSessionsTableAnnotationComposer get sessionId {
    final $$ConversationSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.conversationSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ContextCheckpointsTableTableManager
    extends
        RootTableManager<
          _$ConversationDatabase,
          $ContextCheckpointsTable,
          ContextCheckpointRow,
          $$ContextCheckpointsTableFilterComposer,
          $$ContextCheckpointsTableOrderingComposer,
          $$ContextCheckpointsTableAnnotationComposer,
          $$ContextCheckpointsTableCreateCompanionBuilder,
          $$ContextCheckpointsTableUpdateCompanionBuilder,
          (ContextCheckpointRow, $$ContextCheckpointsTableReferences),
          ContextCheckpointRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$ContextCheckpointsTableTableManager(
    _$ConversationDatabase db,
    $ContextCheckpointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContextCheckpointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContextCheckpointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContextCheckpointsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> throughTurnId = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> factsJson = const Value.absent(),
                Value<String> modelVersion = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContextCheckpointsCompanion(
                id: id,
                sessionId: sessionId,
                throughTurnId: throughTurnId,
                summary: summary,
                factsJson: factsJson,
                modelVersion: modelVersion,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String throughTurnId,
                required String summary,
                Value<String> factsJson = const Value.absent(),
                required String modelVersion,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ContextCheckpointsCompanion.insert(
                id: id,
                sessionId: sessionId,
                throughTurnId: throughTurnId,
                summary: summary,
                factsJson: factsJson,
                modelVersion: modelVersion,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ContextCheckpointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$ContextCheckpointsTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$ContextCheckpointsTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ContextCheckpointsTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationDatabase,
      $ContextCheckpointsTable,
      ContextCheckpointRow,
      $$ContextCheckpointsTableFilterComposer,
      $$ContextCheckpointsTableOrderingComposer,
      $$ContextCheckpointsTableAnnotationComposer,
      $$ContextCheckpointsTableCreateCompanionBuilder,
      $$ContextCheckpointsTableUpdateCompanionBuilder,
      (ContextCheckpointRow, $$ContextCheckpointsTableReferences),
      ContextCheckpointRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$SessionAliasesTableCreateCompanionBuilder =
    SessionAliasesCompanion Function({
      required String legacyId,
      required String sessionId,
      Value<int> rowid,
    });
typedef $$SessionAliasesTableUpdateCompanionBuilder =
    SessionAliasesCompanion Function({
      Value<String> legacyId,
      Value<String> sessionId,
      Value<int> rowid,
    });

final class $$SessionAliasesTableReferences
    extends
        BaseReferences<
          _$ConversationDatabase,
          $SessionAliasesTable,
          SessionAliasRow
        > {
  $$SessionAliasesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationSessionsTable _sessionIdTable(
    _$ConversationDatabase db,
  ) => db.conversationSessions.createAlias(
    'session_aliases__session_id__conversation_sessions__id',
  );

  $$ConversationSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$ConversationSessionsTableTableManager(
      $_db,
      $_db.conversationSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionAliasesTableFilterComposer
    extends Composer<_$ConversationDatabase, $SessionAliasesTable> {
  $$SessionAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationSessionsTableFilterComposer get sessionId {
    final $$ConversationSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.conversationSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationSessionsTableFilterComposer(
            $db: $db,
            $table: $db.conversationSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionAliasesTableOrderingComposer
    extends Composer<_$ConversationDatabase, $SessionAliasesTable> {
  $$SessionAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get legacyId => $composableBuilder(
    column: $table.legacyId,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationSessionsTableOrderingComposer get sessionId {
    final $$ConversationSessionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.conversationSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationSessionsTableOrderingComposer(
                $db: $db,
                $table: $db.conversationSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$SessionAliasesTableAnnotationComposer
    extends Composer<_$ConversationDatabase, $SessionAliasesTable> {
  $$SessionAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get legacyId =>
      $composableBuilder(column: $table.legacyId, builder: (column) => column);

  $$ConversationSessionsTableAnnotationComposer get sessionId {
    final $$ConversationSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.conversationSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$SessionAliasesTableTableManager
    extends
        RootTableManager<
          _$ConversationDatabase,
          $SessionAliasesTable,
          SessionAliasRow,
          $$SessionAliasesTableFilterComposer,
          $$SessionAliasesTableOrderingComposer,
          $$SessionAliasesTableAnnotationComposer,
          $$SessionAliasesTableCreateCompanionBuilder,
          $$SessionAliasesTableUpdateCompanionBuilder,
          (SessionAliasRow, $$SessionAliasesTableReferences),
          SessionAliasRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SessionAliasesTableTableManager(
    _$ConversationDatabase db,
    $SessionAliasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionAliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionAliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionAliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> legacyId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionAliasesCompanion(
                legacyId: legacyId,
                sessionId: sessionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String legacyId,
                required String sessionId,
                Value<int> rowid = const Value.absent(),
              }) => SessionAliasesCompanion.insert(
                legacyId: legacyId,
                sessionId: sessionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionAliasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$SessionAliasesTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn:
                                    $$SessionAliasesTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SessionAliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationDatabase,
      $SessionAliasesTable,
      SessionAliasRow,
      $$SessionAliasesTableFilterComposer,
      $$SessionAliasesTableOrderingComposer,
      $$SessionAliasesTableAnnotationComposer,
      $$SessionAliasesTableCreateCompanionBuilder,
      $$SessionAliasesTableUpdateCompanionBuilder,
      (SessionAliasRow, $$SessionAliasesTableReferences),
      SessionAliasRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$ConversationMetadataTableCreateCompanionBuilder =
    ConversationMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$ConversationMetadataTableUpdateCompanionBuilder =
    ConversationMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$ConversationMetadataTableFilterComposer
    extends Composer<_$ConversationDatabase, $ConversationMetadataTable> {
  $$ConversationMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationMetadataTableOrderingComposer
    extends Composer<_$ConversationDatabase, $ConversationMetadataTable> {
  $$ConversationMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationMetadataTableAnnotationComposer
    extends Composer<_$ConversationDatabase, $ConversationMetadataTable> {
  $$ConversationMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$ConversationMetadataTableTableManager
    extends
        RootTableManager<
          _$ConversationDatabase,
          $ConversationMetadataTable,
          ConversationMetaRow,
          $$ConversationMetadataTableFilterComposer,
          $$ConversationMetadataTableOrderingComposer,
          $$ConversationMetadataTableAnnotationComposer,
          $$ConversationMetadataTableCreateCompanionBuilder,
          $$ConversationMetadataTableUpdateCompanionBuilder,
          (
            ConversationMetaRow,
            BaseReferences<
              _$ConversationDatabase,
              $ConversationMetadataTable,
              ConversationMetaRow
            >,
          ),
          ConversationMetaRow,
          PrefetchHooks Function()
        > {
  $$ConversationMetadataTableTableManager(
    _$ConversationDatabase db,
    $ConversationMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationMetadataTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationMetadataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationMetadataCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => ConversationMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$ConversationDatabase,
      $ConversationMetadataTable,
      ConversationMetaRow,
      $$ConversationMetadataTableFilterComposer,
      $$ConversationMetadataTableOrderingComposer,
      $$ConversationMetadataTableAnnotationComposer,
      $$ConversationMetadataTableCreateCompanionBuilder,
      $$ConversationMetadataTableUpdateCompanionBuilder,
      (
        ConversationMetaRow,
        BaseReferences<
          _$ConversationDatabase,
          $ConversationMetadataTable,
          ConversationMetaRow
        >,
      ),
      ConversationMetaRow,
      PrefetchHooks Function()
    >;

class $ConversationDatabaseManager {
  final _$ConversationDatabase _db;
  $ConversationDatabaseManager(this._db);
  $$ConversationSessionsTableTableManager get conversationSessions =>
      $$ConversationSessionsTableTableManager(_db, _db.conversationSessions);
  $$ConversationTurnsTableTableManager get conversationTurns =>
      $$ConversationTurnsTableTableManager(_db, _db.conversationTurns);
  $$AssistantAttemptsTableTableManager get assistantAttempts =>
      $$AssistantAttemptsTableTableManager(_db, _db.assistantAttempts);
  $$ConversationMessagesTableTableManager get conversationMessages =>
      $$ConversationMessagesTableTableManager(_db, _db.conversationMessages);
  $$ContextCheckpointsTableTableManager get contextCheckpoints =>
      $$ContextCheckpointsTableTableManager(_db, _db.contextCheckpoints);
  $$SessionAliasesTableTableManager get sessionAliases =>
      $$SessionAliasesTableTableManager(_db, _db.sessionAliases);
  $$ConversationMetadataTableTableManager get conversationMetadata =>
      $$ConversationMetadataTableTableManager(_db, _db.conversationMetadata);
}
