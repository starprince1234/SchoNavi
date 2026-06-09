import 'recommendation.dart';

/// 对话消息发送方。
enum ChatRole { user, assistant }

/// 消息状态。V0.2 非流式只用 sending/done/error；streaming 留待 V1.0。
enum ChatMessageStatus { sending, done, error }

/// 一条对话消息。助手消息可携带嵌入推荐卡片。
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.relatedRecommendations,
    required this.status,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final List<Recommendation> relatedRecommendations;
  final ChatMessageStatus status;
}
