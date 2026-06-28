enum ConversationSessionKind { general, professor, fork }

class ConversationSession {
  const ConversationSession({
    required this.id,
    required this.kind,
    required this.rootSessionId,
    required this.ownerId,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.sourceSessionId,
    this.sourceTurnId,
    this.professorId,
    this.title,
    this.deletedAt,
    this.legacyContextIncomplete = false,
  });

  final String id;
  final ConversationSessionKind kind;
  final String rootSessionId;
  final String? sourceSessionId;
  final String? sourceTurnId;
  final String? professorId;
  final String ownerId;
  final int revision;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool legacyContextIncomplete;

  bool get isFork => kind == ConversationSessionKind.fork;
  bool get isDeleted => deletedAt != null;
}
