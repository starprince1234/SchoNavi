import 'chat_message.dart';
import 'conversation_session.dart';
import 'conversation_turn.dart';

sealed class ConversationEvent {
  const ConversationEvent({
    required this.sessionId,
    required this.turnId,
    required this.attemptId,
    required this.revision,
  });

  final String sessionId;
  final String turnId;
  final String attemptId;
  final int revision;
}

class ConversationAcknowledged extends ConversationEvent {
  const ConversationAcknowledged({
    required super.sessionId,
    required super.turnId,
    required super.attemptId,
    required super.revision,
  });
}

class ConversationRouted extends ConversationEvent {
  const ConversationRouted({
    required super.sessionId,
    required super.turnId,
    required super.attemptId,
    required super.revision,
    required this.route,
  });

  final ConversationRoute route;
}

class ConversationDelta extends ConversationEvent {
  const ConversationDelta({
    required super.sessionId,
    required super.turnId,
    required super.attemptId,
    required super.revision,
    required this.text,
  });

  final String text;
}

class ConversationCompleted extends ConversationEvent {
  const ConversationCompleted({
    required super.sessionId,
    required super.turnId,
    required super.attemptId,
    required super.revision,
    required this.message,
    required this.session,
    this.quickActions = const [],
  });

  final ChatMessage message;
  final ConversationSession session;
  final List<String> quickActions;
}

class ConversationFailed extends ConversationEvent {
  const ConversationFailed({
    required super.sessionId,
    required super.turnId,
    required super.attemptId,
    required super.revision,
    required this.message,
    this.code,
    this.requestId,
    this.path,
  });

  final String message;
  final String? code;
  final String? requestId;
  final String? path;
}
