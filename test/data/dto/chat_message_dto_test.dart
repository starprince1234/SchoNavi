import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/dto/chat_message_dto.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';

Recommendation _rec() => Recommendation(
  professorId: 'p1',
  name: '李卫国',
  university: '清华大学',
  college: '计算机系',
  title: '教授',
  researchFields: const ['CV'],
  matchLevel: MatchLevel.high,
  reason: '方向匹配',
  limitations: const [],
  homepageUrl: 'http://x',
  matchScore: 0.9,
);

void main() {
  group('ChatMessageDto', () {
    test('用户消息往返', () {
      final m = ChatMessage(
        id: 'm1',
        role: ChatRole.user,
        content: '为什么推荐他',
        createdAt: DateTime(2026, 6, 27, 14, 0),
        relatedRecommendations: const [],
        status: ChatMessageStatus.done,
      );
      final dto = ChatMessageDto.fromEntity(m);
      final json = dto.toJson();
      final back = ChatMessageDto.fromJson(json).toEntity('m1');
      expect(back.role, ChatRole.user);
      expect(back.content, '为什么推荐他');
      expect(back.status, ChatMessageStatus.done);
      expect(back.kind, ChatMessageKind.conversation);
      expect(back.relatedRecommendations, isEmpty);
    });

    test('助手推荐消息含卡片往返', () {
      final m = ChatMessage(
        id: 'm2',
        role: ChatRole.assistant,
        content: '为你挑了 1 位导师',
        createdAt: DateTime(2026, 6, 27, 14, 1),
        relatedRecommendations: [_rec()],
        status: ChatMessageStatus.done,
        kind: ChatMessageKind.recommendation,
      );
      final back = ChatMessageDto.fromEntity(
        m,
      ).toJson().let((j) => ChatMessageDto.fromJson(j).toEntity('m2'));
      expect(back.kind, ChatMessageKind.recommendation);
      expect(back.relatedRecommendations.length, 1);
      expect(back.relatedRecommendations.first.professorId, 'p1');
      expect(back.relatedRecommendations.first.name, '李卫国');
    });

    test('forkReroute kind 往返', () {
      final m = ChatMessage(
        id: 'm3',
        role: ChatRole.assistant,
        content: '回首页重挑吧',
        createdAt: DateTime(2026, 6, 27, 14, 2),
        relatedRecommendations: const [],
        status: ChatMessageStatus.done,
        kind: ChatMessageKind.forkReroute,
      );
      final back = ChatMessageDto.fromEntity(
        m,
      ).toJson().let((j) => ChatMessageDto.fromJson(j).toEntity('m3'));
      expect(back.kind, ChatMessageKind.forkReroute);
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
