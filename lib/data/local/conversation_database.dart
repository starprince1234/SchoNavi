import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'conversation_database.g.dart';

@DataClassName('ConversationSessionRow')
class ConversationSessions extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get rootSessionId => text()();
  TextColumn get sourceSessionId => text().nullable()();
  TextColumn get sourceTurnId => text().nullable()();
  TextColumn get professorId => text().nullable()();
  TextColumn get ownerId => text().withDefault(const Constant('local'))();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get title => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get legacyContextIncomplete =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceSessionId, sourceTurnId, professorId},
  ];
}

@DataClassName('ConversationTurnRow')
class ConversationTurns extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    ConversationSessions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get ordinal => integer()();
  TextColumn get status => text()();
  TextColumn get route => text().nullable()();
  TextColumn get userMessageId => text()();
  TextColumn get activeAttemptId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sessionId, ordinal},
  ];
}

@DataClassName('AssistantAttemptRow')
class AssistantAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get turnId =>
      text().references(ConversationTurns, #id, onDelete: KeyAction.cascade)();
  TextColumn get requestId => text().unique()();
  TextColumn get status => text()();
  TextColumn get assistantMessageId => text().nullable()();
  TextColumn get errorCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ConversationMessageRow')
class ConversationMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    ConversationSessions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get turnId =>
      text().references(ConversationTurns, #id, onDelete: KeyAction.cascade)();
  TextColumn get attemptId => text().nullable()();
  TextColumn get role => text()();
  TextColumn get kind => text()();
  TextColumn get content => text()();
  TextColumn get status => text()();
  TextColumn get recommendationsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get feedback => text().withDefault(const Constant('none'))();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sessionId, position},
  ];
}

@DataClassName('ContextCheckpointRow')
class ContextCheckpoints extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    ConversationSessions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get throughTurnId => text()();
  TextColumn get summary => text()();
  TextColumn get factsJson => text().withDefault(const Constant('{}'))();
  TextColumn get modelVersion => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SessionAliasRow')
class SessionAliases extends Table {
  TextColumn get legacyId => text()();
  TextColumn get sessionId => text().references(
    ConversationSessions,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  Set<Column<Object>> get primaryKey => {legacyId};
}

@DataClassName('ConversationMetaRow')
class ConversationMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    ConversationSessions,
    ConversationTurns,
    AssistantAttempts,
    ConversationMessages,
    ContextCheckpoints,
    SessionAliases,
    ConversationMetadata,
  ],
)
class ConversationDatabase extends _$ConversationDatabase {
  ConversationDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'scho_navi_conversations',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.dart.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await transaction(() async {
        const activeTurnStatuses = [
          'queued',
          'classifying',
          'connecting',
          'streaming',
          'recommending',
          'cancelling',
        ];
        final activeTurns = await (select(
          conversationTurns,
        )..where((turn) => turn.status.isIn(activeTurnStatuses))).get();
        if (activeTurns.isEmpty) return;
        final now = DateTime.now();
        final attemptIds = activeTurns
            .map((turn) => turn.activeAttemptId)
            .whereType<String>()
            .toList(growable: false);
        if (attemptIds.isNotEmpty) {
          await (update(conversationMessages)..where(
                (message) =>
                    message.attemptId.isIn(attemptIds) &
                    message.status.isIn(const ['sending', 'streaming']),
              ))
              .write(
                ConversationMessagesCompanion(
                  status: const Value('interrupted'),
                  updatedAt: Value(now),
                ),
              );
          await (update(assistantAttempts)..where(
                (attempt) =>
                    attempt.id.isIn(attemptIds) &
                    attempt.status.isIn(const ['connecting', 'streaming']),
              ))
              .write(
                AssistantAttemptsCompanion(
                  status: const Value('interrupted'),
                  updatedAt: Value(now),
                ),
              );
        }
        await (update(
          conversationTurns,
        )..where((turn) => turn.id.isIn(activeTurns.map((t) => t.id)))).write(
          ConversationTurnsCompanion(
            status: const Value('interrupted'),
            updatedAt: Value(now),
          ),
        );
        for (final sessionId in activeTurns.map((t) => t.sessionId).toSet()) {
          await (update(
            conversationSessions,
          )..where((session) => session.id.equals(sessionId))).write(
            ConversationSessionsCompanion.custom(
              revision: conversationSessions.revision + const Constant(1),
              updatedAt: Constant(now),
            ),
          );
        }
      });
    },
  );
}
