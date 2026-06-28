import 'chat_message.dart';

enum ConversationTurnStatus {
  queued,
  classifying,
  connecting,
  streaming,
  recommending,
  completed,
  failed,
  interrupted,
}

enum ConversationRoute { conversation, recommendation, forkReroute }

enum AssistantAttemptStatus {
  connecting,
  streaming,
  completed,
  failed,
  interrupted,
}

class ConversationTurn {
  const ConversationTurn({
    required this.id,
    required this.sessionId,
    required this.ordinal,
    required this.status,
    required this.userMessage,
    required this.createdAt,
    required this.updatedAt,
    this.route,
    this.activeAttemptId,
  });

  final String id;
  final String sessionId;
  final int ordinal;
  final ConversationTurnStatus status;
  final ConversationRoute? route;
  final ChatMessage userMessage;
  final String? activeAttemptId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AssistantAttempt {
  const AssistantAttempt({
    required this.id,
    required this.turnId,
    required this.requestId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assistantMessage,
    this.errorCode,
  });

  final String id;
  final String turnId;
  final String requestId;
  final AssistantAttemptStatus status;
  final ChatMessage? assistantMessage;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
}
