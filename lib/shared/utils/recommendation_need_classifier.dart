import '../../domain/entities/recommendation_result.dart';

/// 判定一条追问是否应触发新一轮导师推荐（产卡）。
///
/// 对话式推荐里，助手每轮可选「纯文字回答」或「文字 + 横滑推荐卡片」。
/// 本抽象有两个实现：
/// - [LlmRecommendationNeedClassifier]（llm 模式）：把追问 + 上一轮推荐摘要
///   喂给大模型判定，是「大模型应用能力」的直接体现。
/// - [HttpRecommendationNeedClassifier]（http 模式）：`POST /api/v1/chat/route`
///   把判定交给后端；真后端可自行实现，假后端复用关键词兜底
///   （`lib/data/mock/follow_up_routing.dart`）。
///
/// 设计为接口便于测试注入假实现，也便于替换路由策略。
abstract interface class RecommendationNeedClassifier {
  /// [lastResult] 为上一轮推荐结果（首轮后追问时非空）；首轮无推荐时传 null。
  /// 失败/畸形时实现应**降级返回 false**——宁可少产卡，不阻断对话。
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  });
}
