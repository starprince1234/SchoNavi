// lib/data/fixtures/preparation_templates.dart
import '../../domain/entities/preparation_plan.dart'
    show CompetitionTimelineType;
import '../../domain/entities/preparation_template.dart';

/// 永久离线兜底：按时间线类型返回阶段骨架 + 最低可用必做任务。AI 不可删除必做任务。
/// 窗口型无答辩阶段；提交型在 [includeDefense] 为 true 时追加 defense_prep。
PreparationTemplate defaultPreparationTemplate(
  CompetitionTimelineType type, {
  bool includeDefense = false,
}) => type == CompetitionTimelineType.eventWindow
    ? _windowTemplate()
    : _submissionTemplate(includeDefense: includeDefense);

PreparationTemplate _windowTemplate() => const PreparationTemplate(
  phases: [
    PreparationTemplatePhase(
      key: 'team_formation',
      title: '组队',
      weight: 0.15,
      requiredTasks: [
        PreparationTemplateTask(
          templateKey: 'team_form',
          title: '组建队伍并明确分工',
          estimatedHours: 3,
        ),
      ],
      optionalTasks: [],
    ),
    PreparationTemplatePhase(
      key: 'rules_review',
      title: '规则研读',
      weight: 0.15,
      requiredTasks: [
        PreparationTemplateTask(
          templateKey: 'rules_read',
          title: '研读竞赛规则与评分',
          estimatedHours: 2,
        ),
      ],
      optionalTasks: [],
    ),
    PreparationTemplatePhase(
      key: 'skill_training',
      title: '专项训练',
      weight: 0.35,
      requiredTasks: [
        PreparationTemplateTask(
          templateKey: 'train_core',
          title: '核心技能专项训练',
          estimatedHours: 12,
        ),
      ],
      optionalTasks: [
        PreparationTemplateTask(
          templateKey: 'train_extra',
          title: '薄弱点补强',
          estimatedHours: 6,
        ),
      ],
    ),
    PreparationTemplatePhase(
      key: 'mock_event',
      title: '模拟比赛',
      weight: 0.20,
      requiredTasks: [
        PreparationTemplateTask(
          templateKey: 'mock_run',
          title: '完整模拟一场',
          estimatedHours: 5,
        ),
      ],
      optionalTasks: [],
    ),
    PreparationTemplatePhase(
      key: 'final_check',
      title: '赛前检查',
      weight: 0.15,
      requiredTasks: [
        PreparationTemplateTask(
          templateKey: 'env_check',
          title: '环境与装备检查',
          estimatedHours: 1,
        ),
      ],
      optionalTasks: [],
    ),
  ],
);

PreparationTemplate _submissionTemplate({required bool includeDefense}) {
  final phases = <PreparationTemplatePhase>[
    const PreparationTemplatePhase(
      key: 'team_formation',
      title: '组队',
      weight: 0.15,
      requiredTasks: [
        PreparationTemplateTask(
          templateKey: 'team_form',
          title: '组建队伍并明确分工',
          estimatedHours: 3,
        ),
      ],
      optionalTasks: [],
    ),
    const PreparationTemplatePhase(
      key: 'topic_selection',
      title: '选题',
      weight: 0.20,
      requiredTasks: [
        PreparationTemplateTask(
          templateKey: 'topic_decide',
          title: '确定选题并立项',
          estimatedHours: 2,
        ),
      ],
      optionalTasks: [],
    ),
    const PreparationTemplatePhase(
      key: 'proposal_writing',
      title: '方案撰写',
      weight: 0.35,
      requiredTasks: [
        PreparationTemplateTask(
          templateKey: 'draft',
          title: '完成初稿',
          estimatedHours: 12,
        ),
      ],
      optionalTasks: [],
    ),
    const PreparationTemplatePhase(
      key: 'submission_polish',
      title: '打磨提交',
      weight: 0.15,
      requiredTasks: [
        PreparationTemplateTask(
          templateKey: 'submit',
          title: '按官网要求提交',
          estimatedHours: 1,
        ),
      ],
      optionalTasks: [],
    ),
  ];
  if (includeDefense) {
    phases.add(
      const PreparationTemplatePhase(
        key: 'defense_prep',
        title: '答辩准备',
        weight: 0.15,
        requiredTasks: [
          PreparationTemplateTask(
            templateKey: 'slides',
            title: '制作答辩 PPT',
            estimatedHours: 4,
          ),
        ],
        optionalTasks: [],
      ),
    );
  }
  return PreparationTemplate(phases: phases);
}
