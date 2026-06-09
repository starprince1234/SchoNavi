import 'recommendation.dart';

/// 对话单轮结果（非流式）。
class ChatResult {
  const ChatResult({
    required this.sessionId,
    required this.answer,
    required this.relatedRecommendations,
  });

  final String sessionId;
  final String answer;
  final List<Recommendation> relatedRecommendations;
}
