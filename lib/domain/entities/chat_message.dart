import 'recommendation.dart';

/// 对话消息发送方。
enum ChatRole { user, assistant }

/// 消息状态。streaming = 正在逐字接收；sending 保留为等待首个增量的思考态。
enum ChatMessageStatus { sending, streaming, done, error }

/// 用户对助手消息的单条反馈。
enum ChatMessageFeedback { none, like, dislike }

/// 一条对话消息。助手消息可携带嵌入推荐卡片。
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.relatedRecommendations,
    required this.status,
    this.feedback = ChatMessageFeedback.none,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final List<Recommendation> relatedRecommendations;
  final ChatMessageStatus status;
  final ChatMessageFeedback feedback;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    List<Recommendation>? relatedRecommendations,
    ChatMessageStatus? status,
    ChatMessageFeedback? feedback,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        role: role ?? this.role,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        relatedRecommendations: relatedRecommendations ?? this.relatedRecommendations,
        status: status ?? this.status,
        feedback: feedback ?? this.feedback,
      );
}
