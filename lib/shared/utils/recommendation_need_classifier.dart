import '../../domain/entities/recommendation_result.dart';

/// 判定一条追问是否应触发新一轮导师推荐（产卡）。
///
/// 对话式推荐里，助手每轮可选「纯文字回答」或「文字 + 横滑推荐卡片」。
/// 本抽象由 LLM 路由器实现（见 `LlmRecommendationNeedClassifier`）：
/// 把追问 + 上一轮推荐摘要喂给大模型，判定属于「要新的/调整的推荐」
/// 还是「针对已有推荐的纯解释/咨询」。
///
/// 设计为接口便于测试注入假实现，也便于日后替换为关键词兜底等其它策略。
abstract interface class RecommendationNeedClassifier {
  /// [lastResult] 为上一轮推荐结果（首轮后追问时非空）；首轮无推荐时传 null。
  /// 失败/畸形时实现应**降级返回 false**——宁可少产卡，不阻断对话。
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  });
}

/// 服务端模式使用的保守本地路由。
///
/// 只在用户明确要求“重新找/重新筛/换一批导师”时产卡，避免把针对已有导师的
/// 地区、方向解释误判为新推荐。
class ConservativeRecommendationNeedClassifier
    implements RecommendationNeedClassifier {
  const ConservativeRecommendationNeedClassifier();

  static const _explicitPhrases = [
    '再推荐',
    '重新推荐',
    '推荐几位',
    '推荐一些',
    '换一批',
    '换几个',
    '找几位',
    '找一些',
    '还有别的导师',
    '还有其他导师',
    '相似的导师',
    '类似的导师',
    '只看',
    '只考虑',
    '重新筛',
    '筛选导师',
    '换到',
    '改到',
  ];

  @override
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  }) async {
    final text = followUp.trim();
    if (text.isEmpty) return false;
    return _explicitPhrases.any(text.contains);
  }
}
