// lib/domain/services/preparation_plan_generator.dart
import '../entities/preparation_plan.dart';
import '../entities/preparation_template.dart';
import '../entities/user_profile.dart';
import '../repositories/preparation_template_provider.dart';
import '../../core/result/result.dart';
import '../../data/ai/ai_preparation_personalizer.dart';
import 'preparation_scheduler.dart';

/// 备赛计划生成器（spec §7.1）：模板 → 经验补基础 → 预算选可选 →
/// AI 个性化合并 → 排期 → 组装 [PreparationPlan]。
///
/// AI 失败时兜底返回标准模板计划（无 personalizedSummary），必做任务始终保留。
class PreparationPlanGenerator {
  PreparationPlanGenerator({
    required this.templateProvider,
    required this.personalizer,
  });

  final PreparationTemplateProvider templateProvider;
  final PreparationPersonalizer personalizer;

  /// beginner 在组队/选题阶段追加的额外必做任务（spec §7.1 经验补基础）。
  static const _beginnerExtraTasks = <String, List<PreparationTemplateTask>>{
    'team_formation': [
      PreparationTemplateTask(
        templateKey: 'team_intro',
        title: '了解竞赛规则与历届回顾',
        estimatedHours: 2,
      ),
    ],
    'topic_selection': [
      PreparationTemplateTask(
        templateKey: 'topic_brainstorm',
        title: '团队头脑风暴候选选题',
        estimatedHours: 2,
      ),
    ],
  };

  Future<PreparationPlan> generate({
    required CompetitionSnapshot competition,
    required DateTime targetDate,
    required WeeklyCommitment weeklyCommitment,
    required ExperienceLevel experienceLevel,
    required DateTime today,
    UserProfile? profile,
  }) async {
    // 1. 加载模板。
    // P2.4 临时：固定 submission + 含答辩，保持旧行为；P2.5 改为按赛事时间线真实传入。
    final template = await templateProvider.load(
      timelineType: CompetitionTimelineType.submission,
      includeDefense: true,
      category: competition.category,
      competitionId: competition.id,
    );

    // 2. 经验补基础：beginner 在指定阶段追加额外必做任务。
    final phases = <PreparationTemplatePhase>[];
    for (final phase in template.phases) {
      var requiredTasks = phase.requiredTasks;
      if (experienceLevel == ExperienceLevel.beginner) {
        final extra = _beginnerExtraTasks[phase.key];
        if (extra != null && extra.isNotEmpty) {
          requiredTasks = [...requiredTasks, ...extra];
        }
      }
      phases.add(
        PreparationTemplatePhase(
          key: phase.key,
          title: phase.title,
          weight: phase.weight,
          requiredTasks: requiredTasks,
          optionalTasks: phase.optionalTasks,
        ),
      );
    }

    // 3. 预算选可选任务：累计 estimatedHours 不超 budgetHours。
    final totalDays = targetDate.difference(today).inDays;
    final weeks = totalDays <= 0 ? 0 : totalDays / 7;
    final budgetHours = weeklyCommitment.hoursPerWeek * weeks;

    // 必做总工时（用于 overload 判定）。
    final requiredTotalHours = phases.fold<double>(
      0,
      (a, p) =>
          a + p.requiredTasks.fold<double>(0, (b, t) => b + t.estimatedHours),
    );

    // 按阶段顺序累计可选任务 estimatedHours，超出预算则不选。
    var optionalBudgetUsed = 0.0;
    final selectedOptionalByPhase = <String, List<PreparationTemplateTask>>{};
    for (final phase in phases) {
      final picked = <PreparationTemplateTask>[];
      for (final task in phase.optionalTasks) {
        if (optionalBudgetUsed + task.estimatedHours > budgetHours) continue;
        optionalBudgetUsed += task.estimatedHours;
        picked.add(task);
      }
      selectedOptionalByPhase[phase.key] = picked;
    }

    // 4. AI 个性化（成功则合并可选任务 + 写入建议；失败忽略）。
    final aiPhaseByKey = <String, PreparationPhasePersonalization>{};
    String? globalAdvice;
    final phaseKeys = phases.map((p) => p.key).toList();
    final aiResult = await personalizer.personalize(
      req: PreparationPersonalizationRequest(
        competition: competition,
        targetDate: targetDate,
        weeklyCommitment: weeklyCommitment,
        experienceLevel: experienceLevel,
        phaseKeys: phaseKeys,
        profile: profile,
      ),
    );
    if (aiResult is Success<PreparationPersonalizationResult>) {
      final result = aiResult.data;
      globalAdvice = result.globalAdvice;
      for (final ap in result.phases) {
        aiPhaseByKey[ap.key] = ap;
      }
    }

    // 5. 排期：得到每阶段 startDate/endDate。
    final schedule = PreparationScheduler.schedule(
      phases: phases,
      today: today,
      targetDate: targetDate,
    );

    // 构建每阶段的 tasks：required + 预算选中的 optional + AI 合并的 optional。
    final planPhases = <PreparationPhase>[];
    var taskSeq = 0;
    for (final phase in phases) {
      final seg = _segmentForPhase(phase.key, schedule);
      final dueDate = _clamp(seg.endDate, today, targetDate);

      final tasks = <PreparationTask>[];
      // 必做任务。
      for (final t in phase.requiredTasks) {
        tasks.add(
          PreparationTask(
            id: 'task_${taskSeq++}',
            templateKey: t.templateKey,
            title: t.title,
            kind: PreparationTaskKind.required,
            estimatedHours: t.estimatedHours.round(),
            dueDate: dueDate,
          ),
        );
      }
      // 已选模板可选任务。
      final selectedKeys = <String>{};
      for (final t in selectedOptionalByPhase[phase.key] ?? const []) {
        selectedKeys.add(t.templateKey);
        tasks.add(
          PreparationTask(
            id: 'task_${taskSeq++}',
            templateKey: t.templateKey,
            title: t.title,
            kind: PreparationTaskKind.optional,
            estimatedHours: t.estimatedHours.round(),
            dueDate: dueDate,
          ),
        );
      }
      // AI 合并的可选任务（去重 templateKey）。
      final aiPhase = aiPhaseByKey[phase.key];
      if (aiPhase != null) {
        for (final at in aiPhase.optionalTasks) {
          final tk = at.templateKey;
          if (tk != null && selectedKeys.contains(tk)) {
            continue;
          }
          if (tk != null) selectedKeys.add(tk);
          tasks.add(
            PreparationTask(
              id: 'task_${taskSeq++}',
              templateKey: tk,
              title: at.title,
              kind: PreparationTaskKind.optional,
              estimatedHours: at.estimatedHours.round(),
              dueDate: dueDate,
            ),
          );
        }
      }

      planPhases.add(
        PreparationPhase(
          key: phase.key,
          title: phase.title,
          startDate: seg.startDate,
          endDate: seg.endDate,
          tasks: tasks,
          personalizedAdvice: aiPhase?.personalizedAdvice,
        ),
      );
    }

    // 7. 警示标志。
    final tightSchedule = PreparationScheduler.isTightSchedule(
      today,
      targetDate,
    );
    final overload = requiredTotalHours > budgetHours;

    // 6. 组装计划。
    return PreparationPlan(
      id: 'pp_${today.millisecondsSinceEpoch}',
      competition: competition,
      targetDate: targetDate,
      weeklyCommitment: weeklyCommitment,
      experienceLevel: experienceLevel,
      status: PreparationPlanStatus.active,
      phases: planPhases,
      personalizedSummary: globalAdvice,
      createdAt: today,
      updatedAt: today,
      tightSchedule: tightSchedule,
      overload: overload,
    );
  }

  /// 找到 phaseKey 所属的排期段：当 schedule 段 key 为合并形如 "a+b" 时，
  /// 含该 phaseKey 的段即为该阶段的段。
  _Segment _segmentForPhase(
    String phaseKey,
    List<({String key, DateTime startDate, DateTime endDate})> schedule,
  ) {
    for (final seg in schedule) {
      if (seg.key == phaseKey || seg.key.split('+').contains(phaseKey)) {
        return _Segment(seg.startDate, seg.endDate);
      }
    }
    // 退化兜底：找不到时用最后一段（不应发生）。
    final last = schedule.last;
    return _Segment(last.startDate, last.endDate);
  }

  DateTime _clamp(DateTime v, DateTime lo, DateTime hi) {
    if (v.isBefore(lo)) return lo;
    if (v.isAfter(hi)) return hi;
    return v;
  }
}

class _Segment {
  const _Segment(this.startDate, this.endDate);
  final DateTime startDate;
  final DateTime endDate;
}
