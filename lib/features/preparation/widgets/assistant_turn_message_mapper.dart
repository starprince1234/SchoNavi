import 'package:scho_navi/domain/entities/assistant_turn.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';

class AssistantTurnMessageMapper {
  static List<ChatMessage> toMessages(AssistantTurn turn, String planId) => [
        ChatMessage(
          id: '${planId}_${turn.id}_user',
          role: ChatRole.user,
          content: turn.userMessage,
          createdAt: turn.createdAt,
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
        ChatMessage(
          id: '${planId}_${turn.id}_assistant',
          role: ChatRole.assistant,
          content: turn.reply,
          createdAt: turn.createdAt,
          relatedRecommendations: const [],
          status:
              turn.error ? ChatMessageStatus.error : ChatMessageStatus.done,
        ),
      ];
}
