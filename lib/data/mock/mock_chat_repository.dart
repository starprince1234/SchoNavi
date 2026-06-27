import 'dart:math' as math;

import '../../core/result/result.dart';
import '../../domain/entities/chat_result.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/repositories/chat_repository.dart';
import 'mock_db.dart';

/// 按消息关键词意图返回合理假回答；「相似/换方向/只看某地」附带推荐卡片。
class MockChatRepository implements ChatRepository {
  MockChatRepository(
    this._db, {
    this.streamChunkDelay = const Duration(milliseconds: 28),
  });

  final MockDb _db;

  /// 每片之间的间隔，制造逐字流式观感；测试可传 Duration.zero 提速。
  final Duration streamChunkDelay;

  static const List<String> _locations = [
    '北京',
    '上海',
    '江浙沪',
    '浙江',
    '杭州',
    '江苏',
    '南京',
    '广东',
    '深圳',
    '广州',
    '安徽',
    '合肥',
    '陕西',
    '西安',
    '黑龙江',
    '哈尔滨',
    '华东',
  ];

  static const Map<String, String> _interestSynonyms = {
    'AI': '人工智能',
    'CV': '计算机视觉',
    'NLP': '自然语言处理',
  };

  static const List<String> _interests = [
    '人工智能',
    '计算机视觉',
    '自然语言处理',
    '大模型',
    '大模型安全',
    '医学影像',
    '机器人',
    '网络安全',
    '生物信息',
    '材料计算',
    '深度学习',
    '强化学习',
    '推荐系统',
    '知识图谱',
    '自动驾驶',
    '多模态',
    '隐私计算',
    '联邦学习',
    '具身智能',
    'SLAM',
  ];

  @override
  Future<void> seedRecommendationTurn({
    required String sessionId,
    required String userPrompt,
    required RecommendationResult result,
  }) async {
    // Mock 按消息关键词即时产卡，无需跨轮上下文注入；空实现满足接口契约。
  }

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (_contains(message, const ['为什么', '理由', '原因', '凭什么'])) {
      final anchor = professorId == null ? null : _db.getProfessor(professorId);
      final who = anchor == null
          ? '这位导师'
          : '${anchor.name}（${anchor.university}）';
      return Success(
        ChatResult(
          sessionId: sessionId,
          answer:
              '推荐$who的主要**依据**：\n\n'
              '- **研究方向匹配**：其公开方向与你描述的需求重叠度较高。\n'
              '- **地域 / 阶段契合**：与你给出的偏好基本一致。\n\n'
              '> 注：以上基于公开资料的离线模拟，仅供参考。',
          relatedRecommendations: const [],
        ),
      );
    }

    if (_contains(message, const ['相似', '类似', '差不多', '同方向', '像他', '像她'])) {
      final anchor = professorId == null ? null : _db.getProfessor(professorId);
      final query = anchor == null ? message : anchor.researchFields.join(' ');
      final recs = _recommend(query, excludeId: professorId, take: 2);
      return Success(
        ChatResult(
          sessionId: sessionId,
          answer: recs.isEmpty
              ? '暂未找到方向相近的导师，可尝试放宽研究方向或地区。'
              : '为你找到 ${recs.length} 位方向相近的导师，可点击卡片查看详情：',
          relatedRecommendations: recs,
        ),
      );
    }

    final loc = _locations.firstWhere(message.contains, orElse: () => '');
    if (loc.isNotEmpty &&
        _contains(message, const ['只看', '只考虑', '换到', '改到', '限定', '在'])) {
      final recs = _recommend(loc, take: 3);
      return Success(
        ChatResult(
          sessionId: sessionId,
          answer: recs.isEmpty
              ? '在「$loc」暂未匹配到合适的导师，可尝试邻近地区。'
              : '已为你筛选「$loc」地区的导师：',
          relatedRecommendations: recs,
        ),
      );
    }

    final field = _detectInterest(message);
    if (field != null && _contains(message, const ['换', '改', '改成', '改为'])) {
      final recs = _recommend(field, take: 3);
      return Success(
        ChatResult(
          sessionId: sessionId,
          answer: recs.isEmpty
              ? '「$field」方向暂未匹配到导师，可换个说法再试。'
              : '已切换到「$field」方向，为你重新推荐：',
          relatedRecommendations: recs,
        ),
      );
    }

    if (_contains(message, const ['硕士', '博士', '保研', '读研', '读博', '适合'])) {
      return Success(
        ChatResult(
          sessionId: sessionId,
          answer:
              '是否适合主要看课题方向、招生名额与你的背景匹配度。\n\n'
              '建议你：\n'
              '1. 查看导师近 3 年论文方向；\n'
              '2. 通过学校官网确认当年招生信息；\n'
              '3. 邮件礼貌咨询。',
          relatedRecommendations: const [],
        ),
      );
    }

    return Success(
      ChatResult(
        sessionId: sessionId,
        answer: '为了更准地帮你，可以**补充**一下：你更看重 **研究方向**、**地区**，还是 **导师职称 / 招生**？',
        relatedRecommendations: const [],
      ),
    );
  }

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) async* {
    final res = await sendMessage(
      sessionId: sessionId,
      message: message,
      professorId: professorId,
    );
    final answer = switch (res) {
      Success(:final data) => data.answer,
      Failure(:final error) => error.message,
    };

    for (final chunk in _sliceForStream(answer)) {
      await Future<void>.delayed(streamChunkDelay);
      yield chunk;
    }
  }

  /// 把整段答案按固定字符数切片，离线兜底的逐字流式（不含推荐卡片）。
  Iterable<String> _sliceForStream(String text, {int size = 4}) sync* {
    for (var i = 0; i < text.length; i += size) {
      yield text.substring(i, math.min(i + size, text.length));
    }
  }

  bool _contains(String text, List<String> keywords) =>
      keywords.any(text.contains);

  String? _detectInterest(String message) {
    for (final entry in _interestSynonyms.entries) {
      if (message.contains(entry.key)) return entry.value;
    }
    for (final field in _interests) {
      if (message.contains(field)) return field;
    }
    return null;
  }

  List<Recommendation> _recommend(
    String query, {
    String? excludeId,
    int take = 3,
  }) {
    final matched = _db
        .recommend(query)
        .recommendations
        .where((r) => r.professorId != excludeId)
        .toList();
    return matched.take(take).toList();
  }
}
