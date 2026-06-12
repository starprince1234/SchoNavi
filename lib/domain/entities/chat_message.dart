import 'recommendation.dart';

/// 对话消息发送方。
enum ChatRole { user, assistant }

/// 消息状态。streaming = 正在逐字接收；sending 保留为等待首个增量的思考态。
enum ChatMessageStatus { sending, streaming, done, error }

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
