import '../../domain/entities/chat_message.dart';
import 'recommendation_dtos.dart';

class ChatMessageDto {
  const ChatMessageDto({
    required this.role,
    required this.content,
    required this.createdAt,
    required this.status,
    required this.kind,
    required this.feedback,
    required this.relatedRecommendations,
  });

  final String role; // 'user' | 'assistant'
  final String content;
  final String createdAt; // ISO8601
  final String status; // sending|streaming|done|error
  final String kind; // conversation|recommendation|forkReroute
  final String feedback; // none|like|dislike
  final List<RecommendationDto> relatedRecommendations;

  factory ChatMessageDto.fromEntity(ChatMessage m) => ChatMessageDto(
        role: m.role == ChatRole.user ? 'user' : 'assistant',
        content: m.content,
        createdAt: m.createdAt.toIso8601String(),
        status: m.status.name,
        kind: m.kind.name,
        feedback: m.feedback.name,
        relatedRecommendations: m.relatedRecommendations
            .map(RecommendationDto.fromEntity)
            .toList(),
      );

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) => ChatMessageDto(
        role: json['role'] as String? ?? 'assistant',
        content: json['content'] as String? ?? '',
        createdAt: json['created_at'] as String? ??
            DateTime.now().toIso8601String(),
        status: json['status'] as String? ?? 'done',
        kind: json['kind'] as String? ?? 'conversation',
        feedback: json['feedback'] as String? ?? 'none',
        relatedRecommendations:
            (json['related_recommendations'] as List<dynamic>? ?? const [])
                .map((e) => RecommendationDto.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role,
        'content': content,
        'created_at': createdAt,
        'status': status,
        'kind': kind,
        'feedback': feedback,
        'related_recommendations':
            relatedRecommendations.map((d) => d.toJson()).toList(),
      };

  ChatMessage toEntity(String id) => ChatMessage(
        id: id,
        role: role == 'user' ? ChatRole.user : ChatRole.assistant,
        content: content,
        createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
        relatedRecommendations:
            relatedRecommendations.map((d) => d.toEntity()).toList(),
        status: ChatMessageStatus.values.byName(status),
        kind: ChatMessageKind.values.byName(kind),
        feedback: ChatMessageFeedback.values.byName(feedback),
      );
}
