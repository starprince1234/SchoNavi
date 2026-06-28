// lib/data/fixtures/preparation_templates.dart
import '../../domain/entities/preparation_template.dart';

/// 永久离线兜底：通用阶段骨架 + 最低可用必做任务。AI 不可删除必做任务。
PreparationTemplate defaultPreparationTemplate() => const PreparationTemplate(phases: [
  PreparationTemplatePhase(key: 'team_formation', title: '组队', weight: 0.15,
    requiredTasks: [
      PreparationTemplateTask(templateKey: 'team_form', title: '组建队伍并明确分工', estimatedHours: 3),
      PreparationTemplateTask(templateKey: 'team_rules', title: '约定沟通节奏与协作工具', estimatedHours: 1),
    ],
    optionalTasks: [
      PreparationTemplateTask(templateKey: 'team_strengths', title: '梳理成员能力互补点', estimatedHours: 1),
    ]),
  PreparationTemplatePhase(key: 'topic_selection', title: '选题', weight: 0.20,
    requiredTasks: [
      PreparationTemplateTask(templateKey: 'topic_research', title: '调研历年获奖方向', estimatedHours: 4),
      PreparationTemplateTask(templateKey: 'topic_decide', title: '确定选题并写一句话立项', estimatedHours: 2),
    ],
    optionalTasks: [
      PreparationTemplateTask(templateKey: 'topic_validate', title: '找导师/学长验证可行性', estimatedHours: 2),
    ]),
  PreparationTemplatePhase(key: 'proposal_writing', title: '方案撰写', weight: 0.35,
    requiredTasks: [
      PreparationTemplateTask(templateKey: 'outline', title: '搭方案大纲', estimatedHours: 3),
      PreparationTemplateTask(templateKey: 'draft', title: '完成初稿', estimatedHours: 12),
    ],
    optionalTasks: [
      PreparationTemplateTask(templateKey: 'demo', title: '制作原型/Demo', estimatedHours: 8),
    ]),
  PreparationTemplatePhase(key: 'submission_polish', title: '打磨提交', weight: 0.15,
    requiredTasks: [
      PreparationTemplateTask(templateKey: 'polish', title: '全稿打磨与排版', estimatedHours: 4),
      PreparationTemplateTask(templateKey: 'submit', title: '按官网要求提交', estimatedHours: 1),
    ],
    optionalTasks: []),
  PreparationTemplatePhase(key: 'defense_prep', title: '答辩准备', weight: 0.15,
    requiredTasks: [
      PreparationTemplateTask(templateKey: 'slides', title: '制作答辩 PPT', estimatedHours: 4),
      PreparationTemplateTask(templateKey: 'rehearse', title: '至少一次模拟答辩', estimatedHours: 3),
    ],
    optionalTasks: []),
]);
