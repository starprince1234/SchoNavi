import 'plan_change_card.dart';

/// 助手对话一轮（spec §2.6）：用户提问 + AI 自然语言回复 + 提议的改动卡集合 +
/// 每张卡的最终状态。`changeSet` 在调用失败时为 null（`error` 为 true，
/// `reply` 持有错误文本）。`createdAt` 为 UTC RFC 3339 date-time（审计时间）。
class AssistantTurn {
  const AssistantTurn({
    required this.id,
    required this.planId,
    required this.userMessage,
    required this.reply,
    required this.createdAt,
    required this.cardStatuses,
    this.changeSet,
    this.error = false,
  });

  final String id;
  final String planId;
  final String userMessage;
  final String reply;
  final PlanChangeSet? changeSet;
  final DateTime createdAt;
  final bool error;
  final Map<String, ChangeCardStatus> cardStatuses;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'plan_id': planId,
    'user_message': userMessage,
    'reply': reply,
    if (changeSet != null) 'change_set': changeSet!.toJson(),
    'created_at': createdAt.toIso8601String(),
    'error': error,
    'card_statuses': _encodeStatuses(cardStatuses),
  };

  factory AssistantTurn.fromJson(Map<String, dynamic> json) => AssistantTurn(
    id: json['id'] as String,
    planId: json['plan_id'] as String,
    userMessage: json['user_message'] as String,
    reply: json['reply'] as String,
    changeSet: json['change_set'] == null
        ? null
        : PlanChangeSet.fromJson(json['change_set'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['created_at'] as String),
    error: (json['error'] as bool?) ?? false,
    cardStatuses: _decodeStatuses(json['card_statuses']),
  );

  static Map<String, String> _encodeStatuses(
    Map<String, ChangeCardStatus> statuses,
  ) {
    final out = <String, String>{};
    statuses.forEach((cardId, status) => out[cardId] = status.name);
    return out;
  }

  static Map<String, ChangeCardStatus> _decodeStatuses(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, ChangeCardStatus>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) continue;
      final status = decodeChangeCardStatus(entry.value as String);
      if (status != null) out[entry.key as String] = status;
    }
    return out;
  }

  @override
  String toString() =>
      'AssistantTurn(id: $id, planId: $planId, error: $error, '
      'cards: ${cardStatuses.length})';
}
