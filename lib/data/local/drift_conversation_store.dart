import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/ids/uuid_v7.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation_aggregate.dart';
import '../../domain/entities/conversation_session.dart';
import '../../domain/entities/conversation_turn.dart';
import '../dto/chat_message_dto.dart';
import 'conversation_database.dart';

class DriftConversationStore {
  DriftConversationStore(this.db, {UuidV7? ids}) : ids = ids ?? UuidV7();

  final ConversationDatabase db;
  final UuidV7 ids;

  static const localOwnerId = 'local';

  Future<String> resolveSessionId(String id) async {
    final direct = await (db.select(
      db.conversationSessions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (direct != null) return direct.id;
    final alias = await (db.select(
      db.sessionAliases,
    )..where((t) => t.legacyId.equals(id))).getSingleOrNull();
    return alias?.sessionId ?? id;
  }

  Future<ConversationSession> createSession({
    String? professorId,
    String ownerId = localOwnerId,
    String? preferredId,
    String? title,
    bool legacyContextIncomplete = false,
  }) async {
    final now = DateTime.now();
    final id = preferredId ?? ids.generate();
    final kind = professorId == null
        ? ConversationSessionKind.general
        : ConversationSessionKind.professor;
    await db
        .into(db.conversationSessions)
        .insert(
          ConversationSessionsCompanion.insert(
            id: id,
            kind: kind.name,
            rootSessionId: id,
            professorId: Value(professorId),
            ownerId: Value(ownerId),
            title: Value(title),
            createdAt: now,
            updatedAt: now,
            legacyContextIncomplete: Value(legacyContextIncomplete),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return (await getSession(id))!;
  }

  Future<ConversationSession?> getSession(String rawId) async {
    final id = await resolveSessionId(rawId);
    final row = await (db.select(
      db.conversationSessions,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _session(row);
  }

  Future<ConversationAggregate?> loadAggregate(
    String rawId, {
    bool includeInherited = false,
  }) async {
    final session = await getSession(rawId);
    if (session == null) return null;

    final turns = <ConversationTurn>[];
    final messages = <ChatMessage>[];
    if (includeInherited && session.kind == ConversationSessionKind.fork) {
      final sourceId = session.sourceSessionId!;
      final sourceTurn = await (db.select(
        db.conversationTurns,
      )..where((t) => t.id.equals(session.sourceTurnId!))).getSingleOrNull();
      if (sourceTurn != null) {
        final sourceTurns =
            await (db.select(db.conversationTurns)
                  ..where(
                    (t) =>
                        t.sessionId.equals(sourceId) &
                        t.ordinal.isSmallerOrEqualValue(sourceTurn.ordinal),
                  )
                  ..orderBy([(t) => OrderingTerm.asc(t.ordinal)]))
                .get();
        for (final row in sourceTurns) {
          turns.add(await _turn(row));
        }
        final sourceMessages =
            await (db.select(db.conversationMessages)
                  ..where(
                    (m) =>
                        m.sessionId.equals(sourceId) &
                        m.turnId.isIn(sourceTurns.map((t) => t.id)),
                  )
                  ..orderBy([(m) => OrderingTerm.asc(m.position)]))
                .get();
        final activeAttempts = {
          for (final t in sourceTurns) t.id: t.activeAttemptId,
        };
        messages.addAll(
          sourceMessages
              .where(
                (m) =>
                    m.role == ChatRole.user.name ||
                    m.attemptId == activeAttempts[m.turnId],
              )
              .map(_message),
        );
      }
    }

    final ownTurns =
        await (db.select(db.conversationTurns)
              ..where((t) => t.sessionId.equals(session.id))
              ..orderBy([(t) => OrderingTerm.asc(t.ordinal)]))
            .get();
    for (final row in ownTurns) {
      turns.add(await _turn(row));
    }
    final ownMessages =
        await (db.select(db.conversationMessages)
              ..where((m) => m.sessionId.equals(session.id))
              ..orderBy([(m) => OrderingTerm.asc(m.position)]))
            .get();
    final ownActiveAttempts = {
      for (final t in ownTurns) t.id: t.activeAttemptId,
    };
    messages.addAll(
      ownMessages
          .where(
            (m) =>
                m.role == ChatRole.user.name ||
                m.attemptId == ownActiveAttempts[m.turnId],
          )
          .map(_message),
    );

    return ConversationAggregate(
      session: session,
      turns: List.unmodifiable(turns),
      messages: List.unmodifiable(messages),
    );
  }

  Future<ConversationSession> forkAtTurn({
    required String sourceSessionId,
    required String sourceTurnId,
    required String professorId,
    String ownerId = localOwnerId,
  }) async {
    final source = await getSession(sourceSessionId);
    if (source == null || source.isDeleted) {
      throw StateError('source session not found');
    }
    final turn =
        await (db.select(db.conversationTurns)..where(
              (t) =>
                  t.id.equals(sourceTurnId) &
                  t.sessionId.equals(source.id) &
                  t.status.equals(ConversationTurnStatus.completed.name),
            ))
            .getSingleOrNull();
    if (turn == null) throw StateError('source turn is not completed');

    final turnMessages = await (db.select(
      db.conversationMessages,
    )..where((m) => m.turnId.equals(sourceTurnId))).get();
    final containsProfessor = turnMessages
        .map(_message)
        .expand((m) => m.relatedRecommendations)
        .any((r) => r.professorId == professorId);
    if (!containsProfessor) {
      throw StateError('professor is not present in source turn');
    }

    final existing =
        await (db.select(db.conversationSessions)..where(
              (s) =>
                  s.sourceSessionId.equals(source.id) &
                  s.sourceTurnId.equals(sourceTurnId) &
                  s.professorId.equals(professorId) &
                  s.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing != null) return _session(existing);

    final now = DateTime.now();
    await db
        .into(db.conversationSessions)
        .insert(
          ConversationSessionsCompanion.insert(
            id: ids.generate(),
            kind: ConversationSessionKind.fork.name,
            rootSessionId: source.rootSessionId,
            sourceSessionId: Value(source.id),
            sourceTurnId: Value(sourceTurnId),
            professorId: Value(professorId),
            ownerId: Value(ownerId),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final resolved =
        await (db.select(db.conversationSessions)..where(
              (s) =>
                  s.sourceSessionId.equals(source.id) &
                  s.sourceTurnId.equals(sourceTurnId) &
                  s.professorId.equals(professorId) &
                  s.deletedAt.isNull(),
            ))
            .getSingle();
    return _session(resolved);
  }

  Future<({ConversationTurn turn, AssistantAttempt attempt})> beginTurn({
    required String sessionId,
    required String text,
    required int expectedRevision,
    String? requestId,
  }) async {
    return db.transaction(() async {
      final session = await getSession(sessionId);
      if (session == null) throw StateError('session not found');
      if (session.revision != expectedRevision) {
        throw StateError('revision conflict');
      }
      final active =
          await (db.select(db.conversationTurns)..where(
                (t) =>
                    t.sessionId.equals(session.id) &
                    t.status.isIn(const [
                      'queued',
                      'classifying',
                      'connecting',
                      'streaming',
                      'recommending',
                    ]),
              ))
              .getSingleOrNull();
      if (active != null) {
        throw StateError('session already has an active turn');
      }

      final existingTurns =
          await (db.select(db.conversationTurns)
                ..where((t) => t.sessionId.equals(session.id))
                ..orderBy([(t) => OrderingTerm.desc(t.ordinal)])
                ..limit(1))
              .get();
      final ordinal = existingTurns.isEmpty
          ? 0
          : existingTurns.first.ordinal + 1;
      final existingMessages =
          await (db.select(db.conversationMessages)
                ..where((m) => m.sessionId.equals(session.id))
                ..orderBy([(m) => OrderingTerm.desc(m.position)])
                ..limit(1))
              .get();
      final position = existingMessages.isEmpty
          ? 0
          : existingMessages.first.position + 1;
      final now = DateTime.now();
      final turnId = ids.generate();
      final messageId = ids.generate();
      final attemptId = ids.generate();
      final resolvedRequestId = requestId ?? ids.generate();

      await db
          .into(db.conversationTurns)
          .insert(
            ConversationTurnsCompanion.insert(
              id: turnId,
              sessionId: session.id,
              ordinal: ordinal,
              status: ConversationTurnStatus.queued.name,
              userMessageId: messageId,
              activeAttemptId: Value(attemptId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.conversationMessages)
          .insert(
            ConversationMessagesCompanion.insert(
              id: messageId,
              sessionId: session.id,
              turnId: turnId,
              role: ChatRole.user.name,
              kind: ChatMessageKind.conversation.name,
              content: text,
              status: ChatMessageStatus.done.name,
              position: position,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.assistantAttempts)
          .insert(
            AssistantAttemptsCompanion.insert(
              id: attemptId,
              turnId: turnId,
              requestId: resolvedRequestId,
              status: AssistantAttemptStatus.connecting.name,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (session.title == null || session.title!.trim().isEmpty) {
        await (db.update(
          db.conversationSessions,
        )..where((s) => s.id.equals(session.id))).write(
          ConversationSessionsCompanion(
            title: Value(text.length > 60 ? '${text.substring(0, 60)}…' : text),
            updatedAt: Value(now),
          ),
        );
      }
      final turn = await _turn(
        (await (db.select(
          db.conversationTurns,
        )..where((t) => t.id.equals(turnId))).getSingle()),
      );
      return (
        turn: turn,
        attempt: AssistantAttempt(
          id: attemptId,
          turnId: turnId,
          requestId: resolvedRequestId,
          status: AssistantAttemptStatus.connecting,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  Future<void> setTurnPhase(
    String turnId,
    ConversationTurnStatus status, {
    ConversationRoute? route,
  }) async {
    await (db.update(
      db.conversationTurns,
    )..where((t) => t.id.equals(turnId))).write(
      ConversationTurnsCompanion(
        status: Value(status.name),
        route: route == null ? const Value.absent() : Value(route.name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<AssistantAttempt> beginRegeneration({
    required String sessionId,
    required String turnId,
    required int expectedRevision,
    String? requestId,
  }) async {
    return db.transaction(() async {
      final session = await getSession(sessionId);
      if (session == null || session.revision != expectedRevision) {
        throw StateError('revision conflict');
      }
      final turn =
          await (db.select(db.conversationTurns)..where(
                (t) => t.id.equals(turnId) & t.sessionId.equals(session.id),
              ))
              .getSingleOrNull();
      if (turn == null ||
          !const ['completed', 'failed', 'interrupted'].contains(turn.status)) {
        throw StateError('turn cannot be regenerated');
      }
      final now = DateTime.now();
      final attemptId = ids.generate();
      final resolvedRequestId = requestId ?? ids.generate();
      await db
          .into(db.assistantAttempts)
          .insert(
            AssistantAttemptsCompanion.insert(
              id: attemptId,
              turnId: turnId,
              requestId: resolvedRequestId,
              status: AssistantAttemptStatus.connecting.name,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await (db.update(
        db.conversationTurns,
      )..where((t) => t.id.equals(turnId))).write(
        ConversationTurnsCompanion(
          status: Value(ConversationTurnStatus.connecting.name),
          activeAttemptId: Value(attemptId),
          updatedAt: Value(now),
        ),
      );
      return AssistantAttempt(
        id: attemptId,
        turnId: turnId,
        requestId: resolvedRequestId,
        status: AssistantAttemptStatus.connecting,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  Future<void> interruptAttempt(String attemptId, {String partial = ''}) async {
    final attempt = await (db.select(
      db.assistantAttempts,
    )..where((a) => a.id.equals(attemptId))).getSingleOrNull();
    if (attempt == null ||
        !const ['connecting', 'streaming'].contains(attempt.status)) {
      return;
    }
    await db.transaction(() async {
      if (partial.isNotEmpty) {
        final turn = await (db.select(
          db.conversationTurns,
        )..where((t) => t.id.equals(attempt.turnId))).getSingle();
        final last =
            await (db.select(db.conversationMessages)
                  ..where((m) => m.sessionId.equals(turn.sessionId))
                  ..orderBy([(m) => OrderingTerm.desc(m.position)])
                  ..limit(1))
                .getSingle();
        final messageId = ids.generate();
        final now = DateTime.now();
        await _insertImportedMessage(
          sessionId: turn.sessionId,
          turnId: turn.id,
          attemptId: attempt.id,
          position: last.position + 1,
          message: ChatMessage(
            id: messageId,
            role: ChatRole.assistant,
            content: partial,
            createdAt: now,
            relatedRecommendations: const [],
            status: ChatMessageStatus.interrupted,
          ),
        );
        await (db.update(
          db.assistantAttempts,
        )..where((a) => a.id.equals(attempt.id))).write(
          AssistantAttemptsCompanion(assistantMessageId: Value(messageId)),
        );
      }
      await failAttempt(
        turnId: attempt.turnId,
        attemptId: attempt.id,
        interrupted: true,
      );
    });
  }

  Future<ChatMessage> completeAttempt({
    required String sessionId,
    required String turnId,
    required String attemptId,
    required ChatMessage message,
  }) async {
    return db.transaction(() async {
      final last =
          await (db.select(db.conversationMessages)
                ..where((m) => m.sessionId.equals(sessionId))
                ..orderBy([(m) => OrderingTerm.desc(m.position)])
                ..limit(1))
              .getSingle();
      final now = DateTime.now();
      final stored = message.copyWith(
        id: message.id.isEmpty ? ids.generate() : message.id,
        status: ChatMessageStatus.done,
      );
      final dto = ChatMessageDto.fromEntity(stored);
      await db
          .into(db.conversationMessages)
          .insert(
            ConversationMessagesCompanion.insert(
              id: stored.id,
              sessionId: sessionId,
              turnId: turnId,
              attemptId: Value(attemptId),
              role: stored.role.name,
              kind: stored.kind.name,
              content: stored.content,
              status: stored.status.name,
              recommendationsJson: Value(
                jsonEncode(
                  dto.relatedRecommendations.map((r) => r.toJson()).toList(),
                ),
              ),
              feedback: Value(stored.feedback.name),
              position: last.position + 1,
              createdAt: stored.createdAt,
              updatedAt: now,
            ),
          );
      await (db.update(
        db.assistantAttempts,
      )..where((a) => a.id.equals(attemptId))).write(
        AssistantAttemptsCompanion(
          status: Value(AssistantAttemptStatus.completed.name),
          assistantMessageId: Value(stored.id),
          updatedAt: Value(now),
        ),
      );
      await setTurnPhase(turnId, ConversationTurnStatus.completed);
      await (db.update(
        db.conversationSessions,
      )..where((s) => s.id.equals(sessionId))).write(
        ConversationSessionsCompanion.custom(
          revision: db.conversationSessions.revision + const Constant(1),
          updatedAt: Constant(now),
        ),
      );
      return stored;
    });
  }

  Future<void> failAttempt({
    required String turnId,
    required String attemptId,
    String? errorCode,
    bool interrupted = false,
  }) async {
    final now = DateTime.now();
    final attemptStatus = interrupted
        ? AssistantAttemptStatus.interrupted
        : AssistantAttemptStatus.failed;
    final turnStatus = interrupted
        ? ConversationTurnStatus.interrupted
        : ConversationTurnStatus.failed;
    await db.transaction(() async {
      final turn = await (db.select(
        db.conversationTurns,
      )..where((t) => t.id.equals(turnId))).getSingle();
      await (db.update(
        db.assistantAttempts,
      )..where((a) => a.id.equals(attemptId))).write(
        AssistantAttemptsCompanion(
          status: Value(attemptStatus.name),
          errorCode: Value(errorCode),
          updatedAt: Value(now),
        ),
      );
      await setTurnPhase(turnId, turnStatus);
      await (db.update(
        db.conversationSessions,
      )..where((s) => s.id.equals(turn.sessionId))).write(
        ConversationSessionsCompanion.custom(
          revision: db.conversationSessions.revision + const Constant(1),
          updatedAt: Constant(now),
        ),
      );
    });
  }

  Future<void> setFeedback(
    String messageId,
    ChatMessageFeedback feedback,
  ) async {
    final changed =
        await (db.update(
          db.conversationMessages,
        )..where((m) => m.id.equals(messageId))).write(
          ConversationMessagesCompanion(feedback: Value(feedback.name)),
        );
    if (changed == 0) throw StateError('message not found');
  }

  Future<List<ConversationSession>> listSessions({
    bool rootsOnly = true,
  }) async {
    final query = db.select(db.conversationSessions)
      ..where(
        (s) =>
            s.deletedAt.isNull() &
            (rootsOnly
                ? s.kind.isNotValue(ConversationSessionKind.fork.name)
                : const Constant(true)),
      )
      ..orderBy([(s) => OrderingTerm.desc(s.updatedAt)]);
    return (await query.get()).map(_session).toList(growable: false);
  }

  Future<List<ConversationSession>> listForks(String rootSessionId) async {
    final rows =
        await (db.select(db.conversationSessions)
              ..where(
                (s) =>
                    s.rootSessionId.equals(rootSessionId) &
                    s.kind.equals(ConversationSessionKind.fork.name) &
                    s.deletedAt.isNull(),
              )
              ..orderBy([(s) => OrderingTerm.desc(s.updatedAt)]))
            .get();
    return rows.map(_session).toList(growable: false);
  }

  Future<void> deleteSession(String rawId) async {
    final session = await getSession(rawId);
    if (session == null) return;
    await db.transaction(() async {
      if (session.kind == ConversationSessionKind.fork) {
        await (db.delete(
          db.conversationSessions,
        )..where((s) => s.id.equals(session.id))).go();
      } else {
        final ids =
            await (db.select(db.conversationSessions)
                  ..where((s) => s.rootSessionId.equals(session.rootSessionId)))
                .map((s) => s.id)
                .get();
        await (db.delete(
          db.conversationSessions,
        )..where((s) => s.id.isIn(ids))).go();
      }
    });
  }

  Future<void> saveAlias(String legacyId, String sessionId) => db
      .into(db.sessionAliases)
      .insertOnConflictUpdate(
        SessionAliasesCompanion.insert(
          legacyId: legacyId,
          sessionId: sessionId,
        ),
      );

  Future<void> importLegacyMessages(
    String sessionId,
    List<ChatMessage> legacyMessages,
  ) async {
    await db.transaction(() async {
      var ordinal = 0;
      var position = 0;
      String? turnId;
      for (final legacy in legacyMessages) {
        if (legacy.role == ChatRole.user) {
          turnId = ids.generate();
          final messageId = ids.generate();
          final now = legacy.createdAt;
          await db
              .into(db.conversationTurns)
              .insert(
                ConversationTurnsCompanion.insert(
                  id: turnId,
                  sessionId: sessionId,
                  ordinal: ordinal++,
                  status: ConversationTurnStatus.interrupted.name,
                  userMessageId: messageId,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await _insertImportedMessage(
            sessionId: sessionId,
            turnId: turnId,
            position: position++,
            message: legacy.copyWith(id: messageId),
          );
          continue;
        }
        if (turnId == null) continue;
        final attemptId = ids.generate();
        final messageId = ids.generate();
        final now = legacy.createdAt;
        await db
            .into(db.assistantAttempts)
            .insert(
              AssistantAttemptsCompanion.insert(
                id: attemptId,
                turnId: turnId,
                requestId: ids.generate(),
                status: legacy.status == ChatMessageStatus.error
                    ? AssistantAttemptStatus.failed.name
                    : AssistantAttemptStatus.completed.name,
                assistantMessageId: Value(messageId),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _insertImportedMessage(
          sessionId: sessionId,
          turnId: turnId,
          attemptId: attemptId,
          position: position++,
          message: legacy.copyWith(
            id: messageId,
            status: legacy.status == ChatMessageStatus.error
                ? ChatMessageStatus.error
                : ChatMessageStatus.done,
          ),
        );
        final route = switch (legacy.kind) {
          ChatMessageKind.recommendation => ConversationRoute.recommendation,
          ChatMessageKind.forkReroute => ConversationRoute.forkReroute,
          ChatMessageKind.conversation => ConversationRoute.conversation,
        };
        await (db.update(
          db.conversationTurns,
        )..where((t) => t.id.equals(turnId!))).write(
          ConversationTurnsCompanion(
            status: Value(
              legacy.status == ChatMessageStatus.error
                  ? ConversationTurnStatus.failed.name
                  : ConversationTurnStatus.completed.name,
            ),
            route: Value(route.name),
            activeAttemptId: Value(attemptId),
            updatedAt: Value(now),
          ),
        );
      }
      await (db.update(
        db.conversationSessions,
      )..where((s) => s.id.equals(sessionId))).write(
        ConversationSessionsCompanion(
          revision: Value(ordinal),
          updatedAt: Value(
            legacyMessages.isEmpty
                ? DateTime.now()
                : legacyMessages.last.createdAt,
          ),
        ),
      );
    });
  }

  Future<String?> latestRecommendationTurnForProfessor(
    String sessionId,
    String professorId,
  ) async {
    final turns =
        await (db.select(db.conversationTurns)
              ..where((t) => t.sessionId.equals(sessionId))
              ..orderBy([(t) => OrderingTerm.desc(t.ordinal)]))
            .get();
    for (final turn in turns) {
      final messages = await (db.select(
        db.conversationMessages,
      )..where((m) => m.turnId.equals(turn.id))).get();
      if (messages
          .map(_message)
          .expand((m) => m.relatedRecommendations)
          .any((r) => r.professorId == professorId)) {
        return turn.id;
      }
    }
    return null;
  }

  Future<String?> latestTurnId(String sessionId) async =>
      (await (db.select(db.conversationTurns)
                ..where((t) => t.sessionId.equals(sessionId))
                ..orderBy([(t) => OrderingTerm.desc(t.ordinal)])
                ..limit(1))
              .getSingleOrNull())
          ?.id;

  Future<ConversationSession> importLegacyFork({
    required String sourceSessionId,
    required String sourceTurnId,
    required String professorId,
    required List<ChatMessage> branchMessages,
    required String legacyId,
    required bool contextIncomplete,
  }) async {
    final source = await getSession(sourceSessionId);
    if (source == null) throw StateError('legacy source session not found');
    final now = DateTime.now();
    final id = ids.generate();
    await db
        .into(db.conversationSessions)
        .insert(
          ConversationSessionsCompanion.insert(
            id: id,
            kind: ConversationSessionKind.fork.name,
            rootSessionId: source.rootSessionId,
            sourceSessionId: Value(source.id),
            sourceTurnId: Value(sourceTurnId),
            professorId: Value(professorId),
            createdAt: now,
            updatedAt: now,
            legacyContextIncomplete: Value(contextIncomplete),
          ),
        );
    await saveAlias(legacyId, id);
    await importLegacyMessages(id, branchMessages);
    return (await getSession(id))!;
  }

  Future<String?> metadata(String key) async => (await (db.select(
    db.conversationMetadata,
  )..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setMetadata(String key, String value) => db
      .into(db.conversationMetadata)
      .insertOnConflictUpdate(
        ConversationMetadataCompanion.insert(key: key, value: value),
      );

  Future<ContextCheckpointRow?> latestCheckpoint(String sessionId) =>
      (db.select(db.contextCheckpoints)
            ..where((c) => c.sessionId.equals(sessionId))
            ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> saveCheckpoint({
    required String sessionId,
    required String throughTurnId,
    required String summary,
    required String modelVersion,
    String factsJson = '{}',
  }) => db
      .into(db.contextCheckpoints)
      .insert(
        ContextCheckpointsCompanion.insert(
          id: ids.generate(),
          sessionId: sessionId,
          throughTurnId: throughTurnId,
          summary: summary,
          factsJson: Value(factsJson),
          modelVersion: modelVersion,
          createdAt: DateTime.now(),
        ),
      );

  Future<void> _insertImportedMessage({
    required String sessionId,
    required String turnId,
    required int position,
    required ChatMessage message,
    String? attemptId,
  }) async {
    final dto = ChatMessageDto.fromEntity(message);
    await db
        .into(db.conversationMessages)
        .insert(
          ConversationMessagesCompanion.insert(
            id: message.id,
            sessionId: sessionId,
            turnId: turnId,
            attemptId: Value(attemptId),
            role: message.role.name,
            kind: message.kind.name,
            content: message.content,
            status: message.status.name,
            recommendationsJson: Value(
              jsonEncode(
                dto.relatedRecommendations.map((r) => r.toJson()).toList(),
              ),
            ),
            feedback: Value(message.feedback.name),
            position: position,
            createdAt: message.createdAt,
            updatedAt: message.createdAt,
          ),
        );
  }

  Future<ConversationTurn> _turn(ConversationTurnRow row) async {
    final userRow = await (db.select(
      db.conversationMessages,
    )..where((m) => m.id.equals(row.userMessageId))).getSingle();
    return ConversationTurn(
      id: row.id,
      sessionId: row.sessionId,
      ordinal: row.ordinal,
      status: _turnStatus(row.status),
      route: row.route == null ? null : _route(row.route!),
      userMessage: _message(userRow),
      activeAttemptId: row.activeAttemptId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ConversationSession _session(ConversationSessionRow row) =>
      ConversationSession(
        id: row.id,
        kind: ConversationSessionKind.values.byName(row.kind),
        rootSessionId: row.rootSessionId,
        sourceSessionId: row.sourceSessionId,
        sourceTurnId: row.sourceTurnId,
        professorId: row.professorId,
        ownerId: row.ownerId,
        revision: row.revision,
        title: row.title,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
        legacyContextIncomplete: row.legacyContextIncomplete,
      );

  ChatMessage _message(ConversationMessageRow row) {
    final raw = jsonDecode(row.recommendationsJson);
    return ChatMessageDto.fromJson({
      'id': row.id,
      'role': row.role,
      'content': row.content,
      'created_at': row.createdAt.toIso8601String(),
      'status': row.status,
      'kind': row.kind,
      'feedback': row.feedback,
      'related_recommendations': raw is List ? raw : const [],
    }).toEntity(row.id);
  }

  ConversationTurnStatus _turnStatus(String value) =>
      ConversationTurnStatus.values.where((e) => e.name == value).firstOrNull ??
      ConversationTurnStatus.interrupted;

  ConversationRoute _route(String value) =>
      ConversationRoute.values.where((e) => e.name == value).firstOrNull ??
      ConversationRoute.conversation;
}
