import '../../core/calendar_date.dart';

/// 备赛计划状态
enum PreparationPlanStatus { active, archived }

/// 每周投入时间
enum WeeklyCommitment { hours3to5, hours6to10, hours11to15, hours16plus }

extension WeeklyCommitmentHours on WeeklyCommitment {
  int get hoursPerWeek => switch (this) {
    WeeklyCommitment.hours3to5 => 5,
    WeeklyCommitment.hours6to10 => 10,
    WeeklyCommitment.hours11to15 => 15,
    WeeklyCommitment.hours16plus => 16,
  };
}

/// 竞赛经验等级
enum ExperienceLevel { beginner, intermediate, experienced }

/// 赛事时间模型：窗口型（比赛集中在几天）/ 提交型（作品提交到 DDL）。
enum CompetitionTimelineType { eventWindow, submission }

/// 备赛任务类型
enum PreparationTaskKind { required, optional, userAdded }

/// 竞赛规则摘要
class CompetitionRulesSummary {
  const CompetitionRulesSummary({
    required this.signupTime,
    required this.contestTime,
    required this.teamSize,
    required this.format,
    required this.organizer,
    this.officialUrl,
  });

  final String signupTime;
  final String contestTime;
  final String teamSize;
  final String format;
  final String organizer;
  final String? officialUrl;

  CompetitionRulesSummary copyWith({
    String? signupTime,
    String? contestTime,
    String? teamSize,
    String? format,
    String? organizer,
    String? officialUrl,
  }) => CompetitionRulesSummary(
    signupTime: signupTime ?? this.signupTime,
    contestTime: contestTime ?? this.contestTime,
    teamSize: teamSize ?? this.teamSize,
    format: format ?? this.format,
    organizer: organizer ?? this.organizer,
    officialUrl: officialUrl ?? this.officialUrl,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'signup_time': signupTime,
    'contest_time': contestTime,
    'team_size': teamSize,
    'format': format,
    'organizer': organizer,
    if (officialUrl != null) 'official_url': officialUrl,
  };

  factory CompetitionRulesSummary.fromJson(Map<String, dynamic> json) =>
      CompetitionRulesSummary(
        signupTime: json['signup_time'] as String,
        contestTime: json['contest_time'] as String,
        teamSize: json['team_size'] as String,
        format: json['format'] as String,
        organizer: json['organizer'] as String,
        officialUrl: json['official_url'] as String?,
      );
}

/// 竞赛快照
class CompetitionSnapshot {
  const CompetitionSnapshot({
    required this.id,
    required this.name,
    required this.category,
    required this.rulesSummary,
  });

  final String id;
  final String name;
  final String category;
  final CompetitionRulesSummary rulesSummary;

  CompetitionSnapshot copyWith({
    String? id,
    String? name,
    String? category,
    CompetitionRulesSummary? rulesSummary,
  }) => CompetitionSnapshot(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    rulesSummary: rulesSummary ?? this.rulesSummary,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'category': category,
    'rules_summary': rulesSummary.toJson(),
  };

  factory CompetitionSnapshot.fromJson(Map<String, dynamic> json) =>
      CompetitionSnapshot(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        rulesSummary: CompetitionRulesSummary.fromJson(
          json['rules_summary'] as Map<String, dynamic>,
        ),
      );
}

/// 备赛任务
class PreparationTask {
  const PreparationTask({
    required this.id,
    this.templateKey,
    required this.title,
    required this.kind,
    required this.estimatedHours,
    required this.dueDate,
    this.note,
    this.completedAt,
  });

  final String id;
  final String? templateKey;
  final String title;
  final PreparationTaskKind kind;
  final int estimatedHours;
  final DateTime dueDate;
  final String? note;
  final DateTime? completedAt;

  bool get completed => completedAt != null;

  PreparationTask copyWith({
    String? id,
    String? templateKey,
    String? title,
    PreparationTaskKind? kind,
    int? estimatedHours,
    DateTime? dueDate,
    String? note,
    DateTime? completedAt,
  }) => PreparationTask(
    id: id ?? this.id,
    templateKey: templateKey ?? this.templateKey,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    estimatedHours: estimatedHours ?? this.estimatedHours,
    dueDate: dueDate ?? this.dueDate,
    note: note ?? this.note,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    if (templateKey != null) 'template_key': templateKey,
    'title': title,
    'kind': kind.name,
    'estimated_hours': estimatedHours,
    'due_date': dueDate.toIso8601String(),
    if (note != null) 'note': note,
    if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
  };

  factory PreparationTask.fromJson(Map<String, dynamic> json) =>
      PreparationTask(
        id: json['id'] as String,
        templateKey: json['template_key'] as String?,
        title: json['title'] as String,
        kind: PreparationTaskKind.values.byName(json['kind'] as String),
        estimatedHours: json['estimated_hours'] as int,
        dueDate: DateTime.parse(json['due_date'] as String),
        note: json['note'] as String?,
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'] as String),
      );
}

/// 备赛阶段
class PreparationPhase {
  const PreparationPhase({
    required this.key,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.tasks,
    this.personalizedAdvice,
  });

  final String key;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final List<PreparationTask> tasks;
  final String? personalizedAdvice;

  PreparationPhase copyWith({
    String? key,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    List<PreparationTask>? tasks,
    String? personalizedAdvice,
  }) => PreparationPhase(
    key: key ?? this.key,
    title: title ?? this.title,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    tasks: tasks ?? this.tasks,
    personalizedAdvice: personalizedAdvice ?? this.personalizedAdvice,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'title': title,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    if (personalizedAdvice != null) 'personalized_advice': personalizedAdvice,
  };

  factory PreparationPhase.fromJson(Map<String, dynamic> json) =>
      PreparationPhase(
        key: json['key'] as String,
        title: json['title'] as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        tasks: (json['tasks'] as List<dynamic>)
            .map((e) => PreparationTask.fromJson(e as Map<String, dynamic>))
            .toList(),
        personalizedAdvice: json['personalized_advice'] as String?,
      );
}

/// 备赛计划
class PreparationPlan {
  const PreparationPlan({
    required this.id,
    required this.competition,
    required this.targetDate,
    this.timelineType = CompetitionTimelineType.submission,
    this.eventEndDate,
    this.defenseDate,
    this.revision = 0,
    required this.weeklyCommitment,
    required this.experienceLevel,
    required this.status,
    required this.phases,
    this.personalizedSummary,
    required this.createdAt,
    required this.updatedAt,
    this.tightSchedule = false,
    this.overload = false,
  });

  final String id;
  final CompetitionSnapshot competition;
  final DateTime targetDate;
  final CompetitionTimelineType timelineType;
  final DateTime? eventEndDate;
  final DateTime? defenseDate;
  final int revision;
  final WeeklyCommitment weeklyCommitment;
  final ExperienceLevel experienceLevel;
  final PreparationPlanStatus status;
  final List<PreparationPhase> phases;
  final String? personalizedSummary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool tightSchedule;
  final bool overload;

  PreparationPlan copyWith({
    String? id,
    CompetitionSnapshot? competition,
    DateTime? targetDate,
    CompetitionTimelineType? timelineType,
    DateTime? eventEndDate,
    DateTime? defenseDate,
    int? revision,
    WeeklyCommitment? weeklyCommitment,
    ExperienceLevel? experienceLevel,
    PreparationPlanStatus? status,
    List<PreparationPhase>? phases,
    String? personalizedSummary,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? tightSchedule,
    bool? overload,
  }) => PreparationPlan(
    id: id ?? this.id,
    competition: competition ?? this.competition,
    targetDate: targetDate ?? this.targetDate,
    timelineType: timelineType ?? this.timelineType,
    eventEndDate: eventEndDate ?? this.eventEndDate,
    defenseDate: defenseDate ?? this.defenseDate,
    revision: revision ?? this.revision,
    weeklyCommitment: weeklyCommitment ?? this.weeklyCommitment,
    experienceLevel: experienceLevel ?? this.experienceLevel,
    status: status ?? this.status,
    phases: phases ?? this.phases,
    personalizedSummary: personalizedSummary ?? this.personalizedSummary,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tightSchedule: tightSchedule ?? this.tightSchedule,
    overload: overload ?? this.overload,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'competition': competition.toJson(),
    'target_date': targetDate.toIso8601String(),
    'timeline_type': timelineType.name,
    if (eventEndDate != null)
      'event_end_date': CalendarDate.toIsoDay(eventEndDate!),
    if (defenseDate != null)
      'defense_date': CalendarDate.toIsoDay(defenseDate!),
    'revision': revision,
    'weekly_commitment': weeklyCommitment.name,
    'experience_level': experienceLevel.name,
    'status': status.name,
    'phases': phases.map((p) => p.toJson()).toList(),
    if (personalizedSummary != null)
      'personalized_summary': personalizedSummary,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'tight_schedule': tightSchedule,
    'overload': overload,
  };

  factory PreparationPlan.fromJson(Map<String, dynamic> json) =>
      PreparationPlan(
        id: json['id'] as String,
        competition: CompetitionSnapshot.fromJson(
          json['competition'] as Map<String, dynamic>,
        ),
        targetDate: DateTime.parse(json['target_date'] as String),
        timelineType: CompetitionTimelineType.values.byName(
          (json['timeline_type'] as String?) ?? 'submission',
        ),
        eventEndDate: json['event_end_date'] == null
            ? null
            : CalendarDate.parseIsoDay(json['event_end_date'] as String),
        defenseDate: json['defense_date'] == null
            ? null
            : CalendarDate.parseIsoDay(json['defense_date'] as String),
        revision: (json['revision'] as int?) ?? 0,
        weeklyCommitment: WeeklyCommitment.values.byName(
          json['weekly_commitment'] as String,
        ),
        experienceLevel: ExperienceLevel.values.byName(
          json['experience_level'] as String,
        ),
        status: PreparationPlanStatus.values.byName(json['status'] as String),
        phases: (json['phases'] as List<dynamic>)
            .map((e) => PreparationPhase.fromJson(e as Map<String, dynamic>))
            .toList(),
        personalizedSummary: json['personalized_summary'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        tightSchedule: json['tight_schedule'] as bool? ?? false,
        overload: json['overload'] as bool? ?? false,
      );
}
