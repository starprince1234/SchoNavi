import 'recommendation.dart';

/// 对话消息发送方。
enum ChatRole { user, assistant }

/// 消息状态。streaming = 正在逐字接收；sending 保留为等待首个增量的思考态。
enum ChatMessageStatus { sending, streaming, done, error }

/// 助手消息所属的业务轮次。
///
/// 推荐轮由结构化推荐接口直接产出，不支持“重新生成文字”；普通聊天轮才允许
/// 重新生成。forkReroute 是 fork 追问内识别到再推荐意图时的重路由提示轮，
/// 不可重新生成、无推荐卡片。
enum ChatMessageKind { conversation, recommendation, forkReroute }

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
    this.kind = ChatMessageKind.conversation,
    this.feedback = ChatMessageFeedback.none,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final List<Recommendation> relatedRecommendations;
  final ChatMessageStatus status;
  final ChatMessageKind kind;
  final ChatMessageFeedback feedback;

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    List<Recommendation>? relatedRecommendations,
    ChatMessageStatus? status,
    ChatMessageKind? kind,
    ChatMessageFeedback? feedback,
  }) => ChatMessage(
    id: id ?? this.id,
    role: role ?? this.role,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    relatedRecommendations:
        relatedRecommendations ?? this.relatedRecommendations,
    status: status ?? this.status,
    kind: kind ?? this.kind,
    feedback: feedback ?? this.feedback,
  );
}
