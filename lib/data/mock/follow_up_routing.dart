/// 假后端保留的追问路由硬编码逻辑。
///
/// 追问路由已转向后端端点 `POST /api/v1/chat/route`（见
/// `HttpRecommendationNeedClassifier`）。真后端可自行实现更智能的路由；
/// 假后端（`fake_chat_route_backend.dart`）则复用本纯函数，保留原有
/// 关键词兜底语义——这是「保留一部分硬编码逻辑」的落点。
///
/// 语义与旧 `ConservativeRecommendationNeedClassifier` 完全一致：仅在用户
/// 明确要求重新/调整推荐时返回 true，避免把针对已有导师的解释性追问
/// 误判为新推荐。**忽略上一轮推荐**（纯 `followUp` 关键词匹配）。
bool followUpNeedsRecommendations(String followUp) {
  final text = followUp.trim();
  if (text.isEmpty) return false;
  return explicitRecommendationPhrases.any(text.contains);
}

/// 触发新一轮推荐（产卡）的明确短语。
const List<String> explicitRecommendationPhrases = [
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
