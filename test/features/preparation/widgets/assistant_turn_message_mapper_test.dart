import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/assistant_turn.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/features/preparation/widgets/assistant_turn_message_mapper.dart';

void main() {
  group('AssistantTurnMessageMapper', () {
    final createdAt = DateTime.utc(2026, 6, 29, 10, 30, 0);

    AssistantTurn buildTurn({bool error = false}) => AssistantTurn(
          id: 'turn_42',
          planId: 'plan_7',
          userMessage: '能帮我把决赛冲刺阶段提前一周吗？',
          reply: error ? '抱歉，调用失败，请稍后重试。' : '好的，已为你调整冲刺阶段起始日。',
          createdAt: createdAt,
          cardStatuses: const {},
          error: error,
        );

    test('maps to exactly two messages (user + assistant)', () {
      final messages =
          AssistantTurnMessageMapper.toMessages(buildTurn(), 'plan_7');
      expect(messages, hasLength(2));
      expect(messages[0].role, ChatRole.user);
      expect(messages[1].role, ChatRole.assistant);
    });

    test('IDs are deterministic and composed of planId + turnId + role', () {
      final messages =
          AssistantTurnMessageMapper.toMessages(buildTurn(), 'plan_7');
      expect(messages[0].id, 'plan_7_turn_42_user');
      expect(messages[1].id, 'plan_7_turn_42_assistant');
    });

    test('user message content mirrors turn.userMessage', () {
      final messages =
          AssistantTurnMessageMapper.toMessages(buildTurn(), 'plan_7');
      expect(messages[0].content, '能帮我把决赛冲刺阶段提前一周吗？');
    });

    test('assistant message content mirrors turn.reply', () {
      final messages =
          AssistantTurnMessageMapper.toMessages(buildTurn(), 'plan_7');
      expect(messages[1].content, '好的，已为你调整冲刺阶段起始日。');
    });

    test('createdAt propagated to both messages', () {
      final messages =
          AssistantTurnMessageMapper.toMessages(buildTurn(), 'plan_7');
      expect(messages[0].createdAt, createdAt);
      expect(messages[1].createdAt, createdAt);
    });

    test('relatedRecommendations empty on both messages', () {
      final messages =
          AssistantTurnMessageMapper.toMessages(buildTurn(), 'plan_7');
      expect(messages[0].relatedRecommendations, isEmpty);
      expect(messages[1].relatedRecommendations, isEmpty);
    });

    test('non-error turn → assistant status done', () {
      final messages =
          AssistantTurnMessageMapper.toMessages(buildTurn(), 'plan_7');
      expect(messages[0].status, ChatMessageStatus.done);
      expect(messages[1].status, ChatMessageStatus.done);
    });

    test('error turn → assistant status error, user still done', () {
      final messages = AssistantTurnMessageMapper.toMessages(
          buildTurn(error: true), 'plan_7');
      expect(messages[0].status, ChatMessageStatus.done);
      expect(messages[1].status, ChatMessageStatus.error);
      expect(messages[1].content, '抱歉，调用失败，请稍后重试。');
    });

    test('deterministic IDs across repeated calls (no randomness)', () {
      final turn = buildTurn();
      final first = AssistantTurnMessageMapper.toMessages(turn, 'plan_7');
      final second = AssistantTurnMessageMapper.toMessages(turn, 'plan_7');
      expect(first.map((m) => m.id).toList(),
          second.map((m) => m.id).toList());
    });
  });
}
