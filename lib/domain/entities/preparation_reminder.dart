class ReminderPreferences {
  const ReminderPreferences({
    this.enabled = false,
    this.hour = 20,
    this.minute = 0,
  });

  final bool enabled;
  final int hour;
  final int minute;

  ReminderPreferences copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderPreferences(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
  };

  factory ReminderPreferences.fromJson(Map<String, dynamic> json) {
    final hour = json['hour'] as int? ?? 20;
    final minute = json['minute'] as int? ?? 0;
    return ReminderPreferences(
      enabled: json['enabled'] as bool? ?? false,
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }
}

enum ReminderPhaseStatus { completed, active, upcoming }

class PreparationReminderPhaseSummary {
  const PreparationReminderPhaseSummary({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final ReminderPhaseStatus status;

  Map<String, dynamic> toJson() => {
    'title': title,
    'startDate': _isoDay(startDate),
    'endDate': _isoDay(endDate),
    'status': status.name,
  };
}

enum ReminderNotificationStatus { granted, denied, notRequired }

class PreparationReminderPlanSummary {
  const PreparationReminderPlanSummary({
    required this.planId,
    required this.competitionName,
    required this.targetDate,
    required this.currentPhase,
    required this.completedTasks,
    required this.totalTasks,
    this.nextTaskTitle,
    this.nextTaskDueDate,
    this.phases = const [],
  });

  final String planId;
  final String competitionName;
  final DateTime targetDate;
  final String currentPhase;
  final int completedTasks;
  final int totalTasks;
  final String? nextTaskTitle;
  final DateTime? nextTaskDueDate;
  final List<PreparationReminderPhaseSummary> phases;

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'competitionName': competitionName,
    'targetDate': _isoDay(targetDate),
    'currentPhase': currentPhase,
    'completedTasks': completedTasks,
    'totalTasks': totalTasks,
    if (nextTaskTitle != null) 'nextTaskTitle': nextTaskTitle,
    if (nextTaskDueDate != null) 'nextTaskDueDate': _isoDay(nextTaskDueDate!),
    'phases': phases.map((p) => p.toJson()).toList(growable: false),
  };
}

class PreparationReminderSnapshot {
  const PreparationReminderSnapshot({
    required this.generatedAt,
    required this.currentStreak,
    required this.preparedToday,
    required this.lastActivityDay,
    required this.plans,
  });

  static const schemaVersion = 2;

  final DateTime generatedAt;
  final int currentStreak;
  final bool preparedToday;
  final String? lastActivityDay;
  final List<PreparationReminderPlanSummary> plans;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'generatedAt': generatedAt.toIso8601String(),
    'currentStreak': currentStreak,
    'preparedToday': preparedToday,
    if (lastActivityDay != null) 'lastActivityDay': lastActivityDay,
    'plans': plans.map((plan) => plan.toJson()).toList(growable: false),
  };
}

String _isoDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
