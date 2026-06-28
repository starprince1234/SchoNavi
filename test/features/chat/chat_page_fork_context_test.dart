import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/conversation_aggregate.dart';
import 'package:scho_navi/domain/entities/conversation_event.dart';
import 'package:scho_navi/domain/entities/conversation_session.dart';
import 'package:scho_navi/domain/repositories/conversation_repository.dart';
import 'package:scho_navi/features/chat/pages/chat_page.dart';

class _PendingConversationRepository implements ConversationRepository {
  _PendingConversationRepository(this.session);

  final ConversationSession session;
  final Completer<Result<ConversationAggregate>> load = Completer();

  @override
  Future<Result<ConversationSession>> createSession({
    String? professorId,
  }) async => Success(session);

  @override
  Future<Result<ConversationAggregate>> loadSession(String sessionId) =>
      load.future;

  @override
  Future<Result<ConversationSession>> forkSessionAtTurn({
    required String sourceSessionId,
    required String sourceTurnId,
    required String professorId,
  }) async => Success(session);

  @override
  Stream<ConversationEvent> submitTurn({
    required String sessionId,
    required String text,
    required int expectedRevision,
    String? requestId,
  }) => const Stream.empty();

  @override
  Stream<ConversationEvent> regenerateTurn({
    required String sessionId,
    required String turnId,
    required int expectedRevision,
    String? requestId,
  }) => const Stream.empty();

  @override
  Future<Result<void>> cancelAttempt(String attemptId) async =>
      const Success(null);

  @override
  Future<Result<void>> setMessageFeedback(
    String messageId,
    ChatMessageFeedback feedback,
  ) async => const Success(null);

  @override
  Future<Result<List<ConversationSession>>> listSessions() async =>
      Success([session]);

  @override
  Future<Result<List<ConversationSession>>> listForks(
    String rootSessionId,
  ) async => Success([session]);

  @override
  Future<Result<void>> deleteSession(String sessionId) async =>
      const Success(null);
}

void main() {
  testWidgets('fork 加载时不闪通用欢迎卡，完成后显示教授专属引导', (tester) async {
    final now = DateTime.utc(2026, 6, 28);
    final professor = MockDb().getProfessor('p_001')!;
    final session = ConversationSession(
      id: 'fork-1',
      kind: ConversationSessionKind.fork,
      rootSessionId: 'main-1',
      sourceSessionId: 'main-1',
      sourceTurnId: 'source-turn',
      professorId: professor.id,
      ownerId: 'local',
      revision: 0,
      createdAt: now,
      updatedAt: now,
    );
    final repository = _PendingConversationRepository(session);
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
        initialAppConfigProvider.overrideWithValue(
          const AppConfig(dataSource: DataSource.http),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ChatPage(forkMode: true, forkId: 'fork-1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('有什么想追问的？'), findsNothing);
    expect(find.textContaining('相似导师'), findsNothing);

    repository.load.complete(
      Success(
        ConversationAggregate(
          session: session,
          turns: const [],
          messages: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('关于${professor.name}教授，想继续问什么？'), findsOneWidget);
    expect(
      find.text(
        '我会参考上一轮的需求与推荐依据，但这里仅显示围绕该教授的新对话。'
        '可以问：为什么适合我、研究方向、硕博匹配、联系前准备。',
      ),
      findsOneWidget,
    );
    expect(find.text('推荐计算机视觉导师'), findsNothing);
  });
}
