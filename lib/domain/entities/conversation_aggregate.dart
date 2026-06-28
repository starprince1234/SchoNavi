import 'chat_message.dart';
import 'conversation_session.dart';
import 'conversation_turn.dart';

class ConversationAggregate {
  const ConversationAggregate({
    required this.session,
    required this.turns,
    required this.messages,
  });

  final ConversationSession session;
  final List<ConversationTurn> turns;
  final List<ChatMessage> messages;
}
