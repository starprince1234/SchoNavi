import '../../domain/entities/chat_result.dart';
import 'api_envelope.dart';
import 'recommendation_dtos.dart';

class ChatMessageResponseDto {
  const ChatMessageResponseDto({
    required this.sessionId,
    required this.answer,
    required this.relatedRecommendations,
  });

  final String sessionId;
  final String answer;
  final List<RecommendationDto> relatedRecommendations;

  factory ChatMessageResponseDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageResponseDto(
      sessionId: json['session_id'] as String,
      answer: json['answer'] as String,
      relatedRecommendations:
          (json['related_recommendations'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((item) => RecommendationDto.fromJson(asJsonObject(item)))
              .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'session_id': sessionId,
    'answer': answer,
    'related_recommendations': relatedRecommendations
        .map((item) => item.toJson())
        .toList(),
  };

  ChatResult toEntity() => ChatResult(
    sessionId: sessionId,
    answer: answer,
    relatedRecommendations: relatedRecommendations
        .map((item) => item.toEntity())
        .toList(),
  );
}
