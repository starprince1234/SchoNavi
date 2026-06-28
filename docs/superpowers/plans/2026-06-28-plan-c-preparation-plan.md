# Plan C: 备赛计划 MVP 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从竞赛详情页"开始备赛"创建个人备赛计划；计划基于本地模板生成（通用阶段骨架 + 类别/赛事 JSON），AI 仅补充可选任务与个性化建议，AI 失败/未配置/畸形时自动用标准模板，不阻断创建。支持"我的备赛"列表、计划详情（倒计时/进度/阶段时间轴/任务清单/编辑）、归档与"继续备赛"判定。

**Architecture:**
- 领域：`PreparationPlan` 聚合根 + `PreparationPhase`/`PreparationTask`/`CompetitionSnapshot` + 枚举（`PreparationPlanStatus`/`WeeklyCommitment`/`ExperienceLevel`/`PreparationTaskKind`）。
- 模板：Dart 强类型通用骨架（必做任务锁死）+ JSON assets（类别/赛事覆盖）。`PreparationTemplateProvider` 抽象，v1 仅本地实现，预留远程接入点。
- 生成：`PreparationPlanGenerator` — 加载模板 → 叠加类别/赛事 → 按经验补基础 → 按每周投入预算选可选任务 → AI 个性化（合并，丢弃非法/重复/超量）→ 客户端确定性排期（合并相邻阶段压缩）。
- 持久化：`LocalPreparationPlanRepository`（key `competition_preparation_plans.v1`）+ watch Stream。
- AI：本地 LLM 模式 `llm.complete(jsonMode)`；HTTP 模式 `POST /api/v1/preparation-plans/generate`（OpenAPI 写作 `/preparation-plans/generate`）+ `fake_backend.dart` handler。
- UI：创建表单 + 列表页 + 详情页 + 抽屉入口 + 详情页"开始备赛/继续备赛"按钮接入。

**Tech Stack:** Flutter, Riverpod, go_router, SharedPreferences（LocalStore）, Dio, LlmClient, 现有冷调系统。

**关联 spec:** §2(D4–D14)、§4.2–4.5、§7、§8、§9、§10、§11。

**依赖:** Plan B 完成（详情页"开始备赛"按钮占位）。Plan C 任务可并行于 Plan A/B 之后，但需 Plan B 的详情页与目录查询。

## Global Constraints

- 沿用 slate/indigo/cyan，44px 触控，语义标签，大字体/375px 不溢出。
- AI 不生成/修改官方比赛日期；不删除模板必做任务；未知阶段/重复 templateKey/超量/非法字段全部丢弃。
- 阶段日期/任务 dueDate 全部客户端确定性计算，clamp 到 [今天, 目标日期]；可用天数 < 阶段数时按顺序合并相邻阶段，每最终阶段 ≥1 天；总天数 < 14 天顶部警示但仍生成。
- 同一竞赛最多一个未归档计划；归档后才能创建新计划。
- 计划存 `CompetitionSnapshot`（name/category + 规则摘要），目录更新不影响已有计划。
- 表单经验等级从 `UserProfile` 预填、不回写；明确提示"AI 模式会发送档案"。
- TDD，频繁提交。每任务 `flutter test <file>` + `flutter analyze`。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/domain/entities/preparation_plan.dart` | 聚合根 + 枚举 + `CompetitionSnapshot`/`CompetitionRulesSummary` + `copyWith`/`fromJson`/`toJson`（新建） |
| `lib/domain/entities/preparation_template.dart` | 模板数据类（阶段/任务/estimatedHours/templateKey）（新建） |
| `lib/data/fixtures/preparation_templates.dart` | Dart 通用阶段骨架 + 必做任务（新建） |
| `assets/preparation_templates/category_templates.json` | 类别模板（新建 + pubspec 注册） |
| `assets/preparation_templates/competition_overrides.json` | 赛事覆盖（新建 + pubspec 注册） |
| `lib/domain/repositories/preparation_template_provider.dart` | 模板来源抽象（新建） |
| `lib/data/local/local_preparation_template_provider.dart` | 本地实现：Dart 骨架 + JSON assets 合并（新建） |
| `lib/domain/repositories/preparation_plan_repository.dart` | 持久化接口（新建） |
| `lib/data/local/local_preparation_plan_repository.dart` | LocalStore 实现 + watch（新建） |
| `lib/domain/services/preparation_plan_generator.dart` | 生成器：模板叠加 + 预算 + 排期 + 合并（新建） |
| `lib/domain/services/preparation_scheduler.dart` | 确定性排期（阶段占比 + 相邻合并 + clamp）（新建） |
| `lib/data/ai/ai_preparation_personalizer.dart` | LLM 个性化（本地模式）（新建） |
| `lib/data/http/http_preparation_personalizer.dart` | HTTP 模式 `POST /preparation-plans/generate`（新建） |
| `lib/data/mock/fake_preparation_backend.dart` | fake handler（新建） |
| `lib/data/dto/preparation_plan_dtos.dart` | 请求/响应 DTO + envelope（新建） |
| `lib/core/di/providers.dart` | 注册各 provider（修改） |
| `lib/features/preparation/providers/preparation_providers.dart` | `preparationPlanRepositoryProvider`、`preparationPlanListProvider`、`preparationPlanGeneratorProvider`、`activePlanForCompetitionProvider`（新建） |
| `lib/features/preparation/pages/preparation_plan_form_page.dart` | 创建表单（新建） |
| `lib/features/preparation/pages/preparation_plans_page.dart` | "我的备赛"列表（新建） |
| `lib/features/preparation/pages/preparation_plan_detail_page.dart` | 计划详情（新建） |
| `lib/features/preparation/widgets/preparation_plan_list_tile.dart` | 列表行（新建） |
| `lib/features/preparation/widgets/preparation_phase_timeline.dart` | 阶段时间轴（新建） |
| `lib/features/preparation/widgets/preparation_task_list.dart` | 任务清单（新建） |
| `lib/features/preparation/widgets/preparation_countdown.dart` | 倒计时 + 负荷警示（新建） |
| `lib/core/router/app_router.dart` | 注册 `/preparation-plans`、`/preparation-plans/:id`、`/preparation-plans/new`（修改） |
| `lib/shared/widgets/app_menu_drawer.dart` | 加"我的备赛"入口（修改） |
| `lib/features/competition_recommendation/pages/competition_detail_page.dart` | 接入"开始备赛/继续备赛"按钮（修改，Plan B 占位） |
| `pubspec.yaml` | 注册 assets（修改） |
| `docs/api-contract.md`、`docs/openapi.yaml` | 加 `/preparation-plans/generate` 契约（修改） |

---

## Task C1: 领域模型 PreparationPlan + 枚举 + 序列化

**Files:**
- Create: `lib/domain/entities/preparation_plan.dart`
- Test: `test/domain/entities/preparation_plan_test.dart`

**Interfaces:**
- Produces: `PreparationPlanStatus{active,archived}`、`WeeklyCommitment{hours3to5,hours6to10,hours11to15,hours16plus}`（含 `hoursPerWeek` int）、`ExperienceLevel{beginner,intermediate,experienced}`、`PreparationTaskKind{required,optional,userAdded}`、`CompetitionRulesSummary{signupTime,contestTime,teamSize,format,organizer,officialUrl}`、`CompetitionSnapshot{id,name,category,rulesSummary}`、`PreparationTask{id,templateKey?,title,kind,estimatedHours,dueDate,note?,completedAt?}`（`completed => completedAt!=null`）、`PreparationPhase{key,title,startDate,endDate,tasks,personalizedAdvice?}`、`PreparationPlan{id,competition,targetDate,weeklyCommitment,experienceLevel,status,phases,personalizedSummary?,createdAt,updatedAt}`。全部带 `fromJson`/`toJson`/`copyWith`。

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/entities/preparation_plan_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

void main() {
  group('PreparationTask', () {
    test('completedAt != null 即完成', () {
      final t = PreparationTask(
        id: 't1', title: '组队', kind: PreparationTaskKind.required,
        estimatedHours: 4, dueDate: DateTime(2026, 7, 1),
        completedAt: DateTime(2026, 6, 28),
      );
      expect(t.completed, isTrue);
    });
    test('completedAt null 即未完成', () {
      final t = PreparationTask(
        id: 't1', title: '组队', kind: PreparationTaskKind.required,
        estimatedHours: 4, dueDate: DateTime(2026, 7, 1),
      );
      expect(t.completed, isFalse);
    });
  });

  group('WeeklyCommitment', () {
    test('hoursPerWeek', () {
      expect(WeeklyCommitment.hours3to5.hoursPerWeek, 5);
      expect(WeeklyCommitment.hours6to10.hoursPerWeek, 10);
      expect(WeeklyCommitment.hours11to15.hoursPerWeek, 15);
      expect(WeeklyCommitment.hours16plus.hoursPerWeek, 16);
    });
  });

  group('序列化', () {
    test('plan toJson/fromJson 往返', () {
      final plan = PreparationPlan(
        id: 'p1',
        competition: CompetitionSnapshot(
          id: 'comp_icpc', name: 'ACM-ICPC', category: '计算机类',
          rulesSummary: CompetitionRulesSummary(
            signupTime: '4月', contestTime: '9-12月', teamSize: '3人',
            format: '编程', organizer: 'ACM', officialUrl: 'https://x',
          ),
        ),
        targetDate: DateTime(2026, 9, 1),
        weeklyCommitment: WeeklyCommitment.hours6to10,
        experienceLevel: ExperienceLevel.beginner,
        status: PreparationPlanStatus.active,
        phases: [
          PreparationPhase(
            key: 'team_formation', title: '组队',
            startDate: DateTime(2026, 6, 28), endDate: DateTime(2026, 7, 5),
            tasks: [
              PreparationTask(id: 't1', templateKey: 'team_form', title: '组建三人队伍',
                kind: PreparationTaskKind.required, estimatedHours: 3,
                dueDate: DateTime(2026, 7, 1), note: '找算法强的队友'),
            ],
            personalizedAdvice: '建议按算法/几何/DP 分工',
          ),
        ],
        personalizedSummary: '整体偏算法训练',
        createdAt: DateTime(2026, 6, 28),
        updatedAt: DateTime(2026, 6, 28),
      );
      final json = plan.toJson();
      final back = PreparationPlan.fromJson(json);
      expect(back.id, 'p1');
      expect(back.competition.name, 'ACM-ICPC');
      expect(back.weeklyCommitment, WeeklyCommitment.hours6to10);
      expect(back.phases.length, 1);
      expect(back.phases[0].tasks[0].templateKey, 'team_form');
      expect(back.phases[0].tasks[0].note, '找算法强的队友');
      expect(back.phases[0].tasks[0].completed, isFalse);
      expect(back.personalizedSummary, '整体偏算法训练');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/preparation_plan_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

实现 `lib/domain/entities/preparation_plan.dart`：所有枚举 + 数据类（不可变、`const` 构造、`copyWith`、`fromJson`/`toJson`）。日期序列化用 `toIso8601String()` / `DateTime.parse`。`CompetitionSnapshot` 内嵌 `CompetitionRulesSummary`。`PreparationTask.completed => completedAt != null`。`WeeklyCommitment` 加 `int get hoursPerWeek`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/entities/preparation_plan_test.dart`
Expected: PASS（4 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/preparation_plan.dart test/domain/entities/preparation_plan_test.dart
git commit -m "feat(preparation): 备赛计划领域模型 + 序列化"
```

---

## Task C2: 模板数据类 + Dart 通用骨架

**Files:**
- Create: `lib/domain/entities/preparation_template.dart`
- Create: `lib/data/fixtures/preparation_templates.dart`
- Test: `test/data/fixtures/preparation_templates_test.dart`

**Interfaces:**
- Produces: `PreparationTemplatePhase{key,title,weight,requiredTasks,optionalTasks}`、`PreparationTemplateTask{templateKey,title,estimatedHours}`、`PreparationTemplate{phases}`。`weight` = 该阶段建议时长占比（double，总和归一）。
- `defaultPreparationTemplate()` → `PreparationTemplate`，5 阶段：`team_formation`(0.15)/`topic_selection`(0.20)/`proposal_writing`(0.35)/`submission_polish`(0.15)/`defense_prep`(0.15)，每阶段 1-3 个必做任务（含 templateKey + estimatedHours）。

- [ ] **Step 1: Write the failing test**

```dart
// test/data/fixtures/preparation_templates_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/fixtures/preparation_templates.dart';

void main() {
  test('默认模板含 5 阶段且权重和约为 1', () {
    final t = defaultPreparationTemplate();
    expect(t.phases.length, 5);
    expect(t.phases.map((p) => p.key), contains('team_formation'));
    final sum = t.phases.fold<double>(0, (a, p) => a + p.weight);
    expect((sum - 1.0).abs(), lessThan(0.001));
  });

  test('每阶段至少 1 个必做任务且必做任务有 templateKey', () {
    final t = defaultPreparationTemplate();
    for (final p in t.phases) {
      expect(p.requiredTasks, isNotEmpty);
      for (final task in p.requiredTasks) {
        expect(task.templateKey, isNotNull);
        expect(task.estimatedHours, greaterThan(0));
      }
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/fixtures/preparation_templates_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/entities/preparation_template.dart
class PreparationTemplateTask {
  const PreparationTemplateTask({required this.templateKey, required this.title, required this.estimatedHours});
  final String templateKey;
  final String title;
  final double estimatedHours;
  factory PreparationTemplateTask.fromJson(Map<String, dynamic> j) =>
      PreparationTemplateTask(
        templateKey: j['template_key'] as String,
        title: j['title'] as String,
        estimatedHours: (j['estimated_hours'] as num).toDouble(),
      );
}

class PreparationTemplatePhase {
  const PreparationTemplatePhase({
    required this.key, required this.title, required this.weight,
    required this.requiredTasks, required this.optionalTasks,
  });
  final String key;
  final String title;
  final double weight; // 建议时长占比
  final List<PreparationTemplateTask> requiredTasks;
  final List<PreparationTemplateTask> optionalTasks;
  factory PreparationTemplatePhase.fromJson(Map<String, dynamic> j) =>
      PreparationTemplatePhase(
        key: j['key'] as String,
        title: j['title'] as String,
        weight: (j['weight'] as num).toDouble(),
        requiredTasks: (j['required_tasks'] as List).map((e) =>
            PreparationTemplateTask.fromJson(e as Map<String, dynamic>)).toList(),
        optionalTasks: ((j['optional_tasks'] as List?) ?? const [])
            .map((e) => PreparationTemplateTask.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class PreparationTemplate {
  const PreparationTemplate({required this.phases});
  final List<PreparationTemplatePhase> phases;
}
```

```dart
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
    optionalTasks: const []),
  PreparationTemplatePhase(key: 'defense_prep', title: '答辩准备', weight: 0.15,
    requiredTasks: [
      PreparationTemplateTask(templateKey: 'slides', title: '制作答辩 PPT', estimatedHours: 4),
      PreparationTemplateTask(templateKey: 'rehearse', title: '至少一次模拟答辩', estimatedHours: 3),
    ],
    optionalTasks: const []),
]);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/fixtures/preparation_templates_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/preparation_template.dart lib/data/fixtures/preparation_templates.dart test/data/fixtures/preparation_templates_test.dart
git commit -m "feat(preparation): 模板数据类 + Dart 通用骨架"
```

---

## Task C3: JSON 类别模板 + 赛事覆盖 assets

**Files:**
- Create: `assets/preparation_templates/category_templates.json`
- Create: `assets/preparation_templates/competition_overrides.json`
- Modify: `pubspec.yaml`（注册 assets）
- Test: `test/data/fixtures/preparation_templates_json_test.dart`

**Interfaces:**
- `category_templates.json` 顶层为 `Map<category, {phases: [{key, required_tasks:[...], optional_tasks:[...]}]}>`。类别键：`计算机类`/`电子与信息类`/`理学类`/`经管类`/`综合与创业类`/`语言与艺术类`。
- `competition_overrides.json` 顶层为 `Map<competitionId, {phases: [...]}>`（至少覆盖 `comp_icpc`/`comp_lanqiao`）。

- [ ] **Step 1: Write the failing test**

```dart
// test/data/fixtures/preparation_templates_json_test.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:scho_navi/domain/entities/preparation_template.dart';

Future<Map<String, dynamic>> _load(String path) async {
  final raw = await rootBundle.loadString(path);
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 注册 asset bundle（默认即用包内 assets，无需额外 mock）
  });

  test('category_templates.json 可解析且每类别阶段任务结构合法', () async {
    final m = await _load('assets/preparation_templates/category_templates.json');
    expect(m, isNotEmpty);
    for (final entry in m.entries) {
      final phases = (entry.value as Map)['phases'] as List;
      for (final p in phases) {
        final pj = p as Map<String, dynamic>;
        expect(pj['key'], isNotNull);
        final req = (pj['required_tasks'] as List?) ?? const [];
        for (final t in req) {
          expect((t as Map)['template_key'], isNotNull);
          expect((t)['estimated_hours'], isNotNull);
        }
      }
    }
  });

  test('competition_overrides.json 含 comp_icpc', () async {
    final m = await _load('assets/preparation_templates/competition_overrides.json');
    expect(m['comp_icpc'], isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/fixtures/preparation_templates_json_test.dart`
Expected: FAIL — assets 不存在/未注册。

- [ ] **Step 3: Write minimal implementation**

创建 `assets/preparation_templates/category_templates.json`：

```json
{
  "计算机类": {
    "phases": [
      {
        "key": "proposal_writing",
        "required_tasks": [
          {"template_key": "cs_env", "title": "搭建开发/算法环境", "estimated_hours": 3},
          {"template_key": "cs_impl", "title": "完成核心算法/功能实现", "estimated_hours": 16}
        ],
        "optional_tasks": [
          {"template_key": "cs_benchmark", "title": "准备性能/正确性测试集", "estimated_hours": 4}
        ]
      }
    ]
  },
  "经管类": {
    "phases": [
      {
        "key": "proposal_writing",
        "required_tasks": [
          {"template_key": "biz_research", "title": "完成市场调研与问卷", "estimated_hours": 8},
          {"template_key": "biz_finance", "title": "搭建财务模型", "estimated_hours": 6}
        ],
        "optional_tasks": [
          {"template_key": "biz_canvas", "title": "绘制商业模式画布", "estimated_hours": 2}
        ]
      }
    ]
  },
  "电子与信息类": {
    "phases": [
      {"key": "proposal_writing", "required_tasks": [
        {"template_key": "ee_design", "title": "完成硬件/系统方案设计", "estimated_hours": 10}
      ], "optional_tasks": []}
    ]
  },
  "理学类": {
    "phases": [
      {"key": "proposal_writing", "required_tasks": [
        {"template_key": "sci_exp", "title": "设计实验/推导方案", "estimated_hours": 10}
      ], "optional_tasks": []}
    ]
  },
  "综合与创业类": {
    "phases": [
      {"key": "proposal_writing", "required_tasks": [
        {"template_key": "ent_bp", "title": "撰写商业计划书", "estimated_hours": 14}
      ], "optional_tasks": []}
    ]
  },
  "语言与艺术类": {
    "phases": [
      {"key": "proposal_writing", "required_tasks": [
        {"template_key": "art_work", "title": "完成作品创作", "estimated_hours": 14}
      ], "optional_tasks": []}
    ]
  }
}
```

创建 `assets/preparation_templates/competition_overrides.json`：

```json
{
  "comp_icpc": {
    "phases": [
      {"key": "team_formation", "required_tasks": [
        {"template_key": "icpc_trio", "title": "固定三人分工（算法/几何/DP）", "estimated_hours": 2}
      ], "optional_tasks": []},
      {"key": "proposal_writing", "required_tasks": [
        {"template_key": "icpc_train", "title": "系统训练数据结构与算法", "estimated_hours": 30}
      ], "optional_tasks": [
        {"template_key": "icpc_mock", "title": "按 5 小时节奏做模拟赛", "estimated_hours": 8}
      ]}
    ]
  },
  "comp_lanqiao": {
    "phases": [
      {"key": "proposal_writing", "required_tasks": [
        {"template_key": "lanqiao_past", "title": "刷历年省赛真题", "estimated_hours": 16}
      ], "optional_tasks": [
        {"template_key": "lanqiao_template", "title": "按目标语言整理模板", "estimated_hours": 4}
      ]}
    ]
  }
}
```

`pubspec.yaml` 在 `flutter.assets` 下加：

```yaml
  - assets/preparation_templates/category_templates.json
  - assets/preparation_templates/competition_overrides.json
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/fixtures/preparation_templates_json_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add assets/preparation_templates/ pubspec.yaml test/data/fixtures/preparation_templates_json_test.dart
git commit -m "feat(preparation): JSON 类别模板 + 赛事覆盖 assets"
```

---

## Task C4: PreparationTemplateProvider + 本地实现

**Files:**
- Create: `lib/domain/repositories/preparation_template_provider.dart`
- Create: `lib/data/local/local_preparation_template_provider.dart`
- Test: `test/data/local/local_preparation_template_provider_test.dart`

**Interfaces:**
- Produces: `PreparationTemplateProvider.load() -> Future<PreparationTemplate>`。
- `LocalPreparationTemplateProvider`：`load()` 返回 Dart 默认模板，叠加 JSON 类别模板（按传入的 category）+ 赛事覆盖（按 competitionId）。构造：`LocalPreparationTemplateProvider({required AssetBundle bundle})`。`load({String? category, String? competitionId})`。
- 合并规则：以 Dart 模板为基础；对每个 JSON 阶段（同 key），把其 `required_tasks`/`optional_tasks` 追加到对应阶段（去重 by templateKey）。JSON 加载失败/解析异常 → 仅返回 Dart 默认模板，不抛错。

- [ ] **Step 1: Write the failing test**

```dart
// test/data/local/local_preparation_template_provider_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/local/local_preparation_template_provider.dart';

class _StubBundle extends CachingAssetBundle {
  final Map<String, String> assets;
  _StubBundle(this.assets);
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final v = assets[key];
    if (v == null) throw Exception('missing $key');
    return v;
  }
}

void main() {
  test('加载计算机类叠加任务', () async {
    final bundle = _StubBundle({
      'assets/preparation_templates/category_templates.json': '''
{"计算机类":{"phases":[{"key":"proposal_writing","required_tasks":[{"template_key":"cs_impl","title":"实现","estimated_hours":16}],"optional_tasks":[]}]}}''',
      'assets/preparation_templates/competition_overrides.json': '{}',
    });
    final p = LocalPreparationTemplateProvider(bundle: bundle);
    final t = await p.load(category: '计算机类');
    final writing = t.phases.firstWhere((p) => p.key == 'proposal_writing');
    expect(writing.requiredTasks.any((t) => t.templateKey == 'cs_impl'), isTrue);
    // Dart 必做仍在
    expect(writing.requiredTasks.any((t) => t.templateKey == 'outline'), isTrue);
  });

  test('JSON 缺失时降级到 Dart 默认', () async {
    final bundle = _StubBundle({}); // 两个 asset 都缺
    final p = LocalPreparationTemplateProvider(bundle: bundle);
    final t = await p.load(category: '计算机类');
    expect(t.phases.length, 5); // Dart 默认 5 阶段
  });

  test('赛事覆盖追加任务', () async {
    final bundle = _StubBundle({
      'assets/preparation_templates/category_templates.json': '{}',
      'assets/preparation_templates/competition_overrides.json': '''
{"comp_icpc":{"phases":[{"key":"proposal_writing","required_tasks":[{"template_key":"icpc_train","title":"训练","estimated_hours":30}],"optional_tasks":[]}]}}''',
    });
    final p = LocalPreparationTemplateProvider(bundle: bundle);
    final t = await p.load(competitionId: 'comp_icpc');
    final writing = t.phases.firstWhere((p) => p.key == 'proposal_writing');
    expect(writing.requiredTasks.any((t) => t.templateKey == 'icpc_train'), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/local/local_preparation_template_provider_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/repositories/preparation_template_provider.dart
import '../entities/preparation_template.dart';

abstract interface class PreparationTemplateProvider {
  Future<PreparationTemplate> load({String? category, String? competitionId});
}
```

```dart
// lib/data/local/local_preparation_template_provider.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/preparation_template.dart';
import '../../domain/repositories/preparation_template_provider.dart';
import '../fixtures/preparation_templates.dart';

class LocalPreparationTemplateProvider implements PreparationTemplateProvider {
  LocalPreparationTemplateProvider({required this.bundle});
  final AssetBundle bundle;

  @override
  Future<PreparationTemplate> load({String? category, String? competitionId}) async {
    final base = defaultPreparationTemplate();
    final byKey = {for (final p in base.phases) p.key: p};
    final mergedRequired = <String, List<PreparationTemplateTask>>{
      for (final p in base.phases) p.key: [...p.requiredTasks]
    };
    final mergedOptional = <String, List<PreparationTemplateTask>>{
      for (final p in base.phases) p.key: [...p.optionalTasks]
    };

    Future<void> applyJson(String assetPath, Map<String, dynamic> Function() pick) async {
      try {
        final raw = await bundle.loadString(assetPath);
        final root = jsonDecode(raw) as Map<String, dynamic>;
        final entry = pick();
        if (entry.isEmpty) return;
        final phases = (entry['phases'] as List?) ?? const [];
        for (final p in phases) {
          final pj = p as Map<String, dynamic>;
          final key = pj['key'] as String;
          if (!byKey.containsKey(key)) continue; // 未知阶段丢弃
          for (final t in (pj['required_tasks'] as List?) ?? const []) {
            final task = PreparationTemplateTask.fromJson(t as Map<String, dynamic>);
            if (!mergedRequired[key]!.any((x) => x.templateKey == task.templateKey)) {
              mergedRequired[key]!.add(task);
            }
          }
          for (final t in (pj['optional_tasks'] as List?) ?? const []) {
            final task = PreparationTemplateTask.fromJson(t as Map<String, dynamic>);
            if (!mergedOptional[key]!.any((x) => x.templateKey == task.templateKey)) {
              mergedOptional[key]!.add(task);
            }
          }
        }
      } catch (_) {
        // 降级：忽略该层 JSON
      }
    }

    if (category != null) {
      await applyJson('assets/preparation_templates/category_templates.json',
          () => (root) => root[category] as Map<String, dynamic>... );
      // 注：applyJson 的 pick 签名见下方修正——pick 接收已 decode 的 root。
    }
    // 见 Step 3 说明：实际把 applyJson 重构为 applyEntry(Map root, String key)
    ...
    return PreparationTemplate(phases: base.phases.map((p) => PreparationTemplatePhase(
      key: p.key, title: p.title, weight: p.weight,
      requiredTasks: mergedRequired[p.key]!, optionalTasks: mergedOptional[p.key]!,
    )).toList());
  }
}
```

> 实施说明：上面 `applyJson` 的 `pick` 闭包签名有歧义。实施时改为：
> ```dart
> Future<void> applyEntry(Map<String, dynamic> root, String entryKey) async { ... 同上逻辑，用 root[entryKey] ... }
> ```
> 然后分别：`if (category != null) { try { final root = jsonDecode(await bundle.loadString(categoryPath)); applyEntry(root, category); } catch(_){} }`；`if (competitionId != null) { try { final root = jsonDecode(await bundle.loadString(overridePath)); applyEntry(root, competitionId); } catch(_){} }`。即两次独立 try/catch，各自降级。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/local/local_preparation_template_provider_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/preparation_template_provider.dart lib/data/local/local_preparation_template_provider.dart test/data/local/local_preparation_template_provider_test.dart
git commit -m "feat(preparation): 模板来源抽象 + 本地实现"
```

---

## Task C5: 确定性排期 PreparationScheduler

**Files:**
- Create: `lib/domain/services/preparation_scheduler.dart`
- Test: `test/domain/services/preparation_scheduler_test.dart`

**Interfaces:**
- Produces: `PreparationScheduler.schedule({required List<PreparationTemplatePhase> phases, required DateTime today, required DateTime targetDate}) -> List<({String key, DateTime startDate, DateTime endDate})>`。
- 规则：
  1. `totalDays = targetDate.difference(today).inDays`（≥1）。
  2. 若 `totalDays < phases.length`：按顺序合并相邻阶段，直到 `finalPhases.length <= totalDays`；每个最终阶段 ≥1 天。
  3. 否则按 `weight` 比例分配（归一化 weight，每阶段 ≥1 天，余数补到权重最大的阶段）。
  4. 阶段 `startDate`/`endDate` 顺序填充 `[today, targetDate]`，相邻阶段 endDate = 下一段 startDate - 1day（或同日连续）。
- 另：`dueDateForTask(phaseStart, phaseEnd, today, targetDate)` 把任务 dueDate 设为 phaseEnd（clamp 到 [today, targetDate]）。
- `isTightSchedule(today, targetDate)` → `totalDays < 14`。

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/services/preparation_scheduler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/preparation_template.dart';
import 'package:scho_navi/domain/services/preparation_scheduler.dart';

List<PreparationTemplatePhase> _phases() => [
  const PreparationTemplatePhase(key: 'a', title: 'A', weight: 0.2, requiredTasks: [], optionalTasks: []),
  const PreparationTemplatePhase(key: 'b', title: 'B', weight: 0.3, requiredTasks: [], optionalTasks: []),
  const PreparationTemplatePhase(key: 'c', title: 'C', weight: 0.5, requiredTasks: [], optionalTasks: []),
];

void main() {
  test('宽裕：按权重分配，覆盖 [today, targetDate]', () {
    final s = PreparationScheduler.schedule(
      phases: _phases(), today: DateTime(2026, 6, 28), targetDate: DateTime(2026, 9, 1));
    expect(s.length, 3);
    expect(s.first.startDate, DateTime(2026, 6, 28));
    expect(s.last.endDate, DateTime(2026, 9, 1));
    // 阶段连续不重叠
    for (var i = 1; i < s.length; i++) {
      expect(s[i].startDate.isAfter(s[i - 1].startDate), isTrue);
    }
  });

  test('压缩：5 天 3 阶段 -> 合并相邻使每段 >=1 天', () {
    final today = DateTime(2026, 6, 28);
    final s = PreparationScheduler.schedule(
      phases: _phases(), today: today, targetDate: today.add(const Duration(days: 5)));
    expect(s.length, lessThanOrEqualTo(5));
    for (final p in s) {
      expect(p.endDate.difference(p.startDate).inDays, greaterThanOrEqualTo(0));
    }
    expect(s.first.startDate, today);
    expect(s.last.endDate, today.add(const Duration(days: 5)));
  });

  test('极短：1 天 -> 合并为 1 段', () {
    final today = DateTime(2026, 6, 28);
    final s = PreparationScheduler.schedule(
      phases: _phases(), today: today, targetDate: today);
    expect(s.length, 1);
    expect(s.first.startDate, today);
    expect(s.first.endDate, today);
  });

  test('isTightSchedule < 14 天', () {
    expect(PreparationScheduler.isTightSchedule(DateTime(2026,6,28), DateTime(2026,7,5)), isTrue);
    expect(PreparationScheduler.isTightSchedule(DateTime(2026,6,28), DateTime(2026,9,1)), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/services/preparation_scheduler_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

实现 `PreparationScheduler`：归一化权重 → 按比例分 `totalDays`（每段 `max(1, round(weightNorm * totalDays))`，调整末段使总和 == totalDays）。若 `totalDays < phases.length`：从末尾向前合并相邻阶段直到 `len <= totalDays`（合并后 key 用前段 key、title 用 "A+B"，endDate 取后段）。生成连续日期区间。

```dart
class PreparationScheduler {
  static List<({String key, DateTime startDate, DateTime endDate})> schedule({
    required List<PreparationTemplatePhase> phases,
    required DateTime today,
    required DateTime targetDate,
  }) {
    final total = targetDate.difference(today).inDays;
    if (total <= 0) {
      return [(
        key: phases.map((p) => p.key).join('+'),
        startDate: today,
        endDate: targetDate,
      )];
    }
    // 合并相邻阶段直到数量 <= total
    var keys = phases.map((p) => p.key).toList();
    var weights = phases.map((p) => p.weight).toList();
    while (keys.length > total) {
      // 从末尾合并到前一段
      final lastW = weights.removeLast();
      final lastK = keys.removeLast();
      weights[keys.length - 1] += lastW;
      keys[keys.length - 1] = '${keys[keys.length - 1]}+$lastK';
    }
    final wSum = weights.fold<double>(0, (a, w) => a + w);
    final days = List<int>.generate(keys.length, (i) {
      final d = (weights[i] / wSum * total).round();
      return d < 1 ? 1 : d;
    });
    // 修正总和
    var diff = total - days.fold(0, (a, d) => a + d);
    while (diff != 0) {
      final idx = diff > 0 ? days.indexWhere((d) => true) : 0; // 加到第一段或从最大段调
      // 简单策略：差额全补到/扣自权重最大段
      final maxIdx = _argMax(days);
      if (diff > 0) { days[maxIdx] += 1; diff -= 1; }
      else { if (days[maxIdx] > 1) { days[maxIdx] -= 1; diff += 1; } else break; }
    }
    final out = <({String key, DateTime startDate, DateTime endDate})>[];
    var cursor = today;
    for (var i = 0; i < keys.length; i++) {
      final end = cursor.add(Duration(days: days[i] - 1));
      out.add((key: keys[i], startDate: cursor, endDate: i == keys.length - 1 ? targetDate : end));
      cursor = end.add(const Duration(days: 1));
    }
    if (out.isNotEmpty) out[out.length - 1] = (key: out.last.key, startDate: out.last.startDate, endDate: targetDate);
    return out;
  }

  static int _argMax(List<int> xs) {
    var mi = 0; for (var i = 1; i < xs.length; i++) if (xs[i] > xs[mi]) mi = i; return mi;
  }

  static bool isTightSchedule(DateTime today, DateTime targetDate) =>
      targetDate.difference(today).inDays < 14;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/services/preparation_scheduler_test.dart`
Expected: PASS（4 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/services/preparation_scheduler.dart test/domain/services/preparation_scheduler_test.dart
git commit -m "feat(preparation): 确定性排期(相邻合并压缩)"
```

---

## Task C6: PreparationPlanRepository 接口 + LocalStore 实现

**Files:**
- Create: `lib/domain/repositories/preparation_plan_repository.dart`
- Create: `lib/data/local/local_preparation_plan_repository.dart`
- Test: `test/data/local/local_preparation_plan_repository_test.dart`

**Interfaces:**
- Produces: `PreparationPlanRepository { List<PreparationPlan> list(); PreparationPlan? findById(String id); PreparationPlan? activeForCompetition(String competitionId); Stream<List<PreparationPlan>> watch(); Future<PreparationPlan> save(PreparationPlan plan); Future<void> archive(String id); Future<void> delete(String id); }`。
- `LocalPreparationPlanRepository(LocalStore store, {DateTime Function()? now})`：key `competition_preparation_plans.v1`，`StreamController.broadcast`，损坏条目降级忽略。`save` 时 `updatedAt = now()`。`activeForCompetition` 返回 `status==active && competition.id==competitionId` 的第一个。
- 序列化：`PreparationPlan.toJson()`/`fromJson()`（Task C1 已建），存为 `JsonList`。

- [ ] **Step 1: Write the failing test**

```dart
// test/data/local/local_preparation_plan_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';
import 'package:scho_navi/data/local/local_preparation_plan_repository.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

PreparationPlan _plan({required String id, required String compId, PreparationPlanStatus status = PreparationPlanStatus.active}) =>
    PreparationPlan(
      id: id,
      competition: CompetitionSnapshot(id: compId, name: 'C', category: '计算机类',
        rulesSummary: CompetitionRulesSummary(signupTime: '', contestTime: '', teamSize: '', format: '', organizer: '', officialUrl: null)),
      targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.beginner,
      status: status,
      phases: const [],
      createdAt: DateTime(2026, 6, 28), updatedAt: DateTime(2026, 6, 28),
    );

void main() {
  late LocalPreparationPlanRepository repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalPreparationPlanRepository(SharedPreferencesLocalStore(await SharedPreferences.getInstance()));
  });

  test('save 后 list/watch 可见', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    expect(repo.list().length, 1);
    final firstEvt = await repo.watch().first;
    expect(firstEvt.length, 1);
  });

  test('activeForCompetition 返回进行中计划', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    final a = repo.activeForCompetition('c1');
    expect(a, isNotNull);
    expect(a!.id, 'p1');
    expect(repo.activeForCompetition('c2'), isNull);
  });

  test('归档后 activeForCompetition 为 null', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    await repo.archive('p1');
    expect(repo.activeForCompetition('c1'), isNull);
    expect(repo.findById('p1')!.status, PreparationPlanStatus.archived);
  });

  test('同一竞赛最多一个 active：save 第二个同竞赛 plan 仍存为独立条目（由生成器/页面保证唯一，仓库不强制）', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    await repo.save(_plan(id: 'p2', compId: 'c1'));
    expect(repo.list().length, 2);
  });

  test('delete 移除', () async {
    await repo.save(_plan(id: 'p1', compId: 'c1'));
    await repo.delete('p1');
    expect(repo.list(), isEmpty);
  });

  test('损坏数据降级忽略', () async {
    // 直接写坏 JSON 到 store
    final store = SharedPreferencesLocalStore(await SharedPreferences.getInstance());
    await store.setJsonList(LocalPreparationPlanRepository.storageKey, [
      {'id': 'bad', 'competition': null}, // 缺字段
    ]);
    expect(repo.list(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/local/local_preparation_plan_repository_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/repositories/preparation_plan_repository.dart
import '../entities/preparation_plan.dart';

abstract interface class PreparationPlanRepository {
  List<PreparationPlan> list();
  PreparationPlan? findById(String id);
  PreparationPlan? activeForCompetition(String competitionId);
  Stream<List<PreparationPlan>> watch();
  Future<PreparationPlan> save(PreparationPlan plan);
  Future<void> archive(String id);
  Future<void> delete(String id);
}
```

`LocalPreparationPlanRepository`：仿 `LocalHistoryRepository` 结构。`storageKey = 'competition_preparation_plans.v1'`。`_readAll` 遍历 JsonList，逐条 try `_parsePlan`，失败跳过。`save` 替换同 id 条目并写回 + emit。`archive` 改 status=archived 写回。`dispose()` 关闭 controller。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/local/local_preparation_plan_repository_test.dart`
Expected: PASS（6 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/preparation_plan_repository.dart lib/data/local/local_preparation_plan_repository.dart test/data/local/local_preparation_plan_repository_test.dart
git commit -m "feat(preparation): 计划持久化仓储 + watch"
```

---

## Task C7: AI 个性化（本地 LLM + HTTP + DTO + fake）

**Files:**
- Create: `lib/data/dto/preparation_plan_dtos.dart`
- Create: `lib/data/ai/ai_preparation_personalizer.dart`
- Create: `lib/data/http/http_preparation_personalizer.dart`
- Create: `lib/data/mock/fake_preparation_backend.dart`
- Modify: `lib/data/mock/fake_backend.dart`（注册 handler）
- Test: `test/data/ai/ai_preparation_personalizer_test.dart`、`test/data/http/http_preparation_personalizer_test.dart`

**Interfaces:**
- `PreparationPersonalizer`（抽象）：`Future<PreparationPersonalizationResult> personalize({required PreparationPersonalizationRequest req})`。
- `PreparationPersonalizationRequest {CompetitionSnapshot competition, DateTime targetDate, WeeklyCommitment weeklyCommitment, ExperienceLevel experienceLevel, List<String> phaseKeys, UserProfile? profile}`。
- `PreparationPersonalizationResult {List<PreparationPhasePersonalization> phases, String? globalAdvice}`；`PreparationPhasePersonalization {String key, List<PreparationOptionalTaskSuggestion> optionalTasks, String? personalizedAdvice}`；`PreparationOptionalTaskSuggestion {String? templateKey, String title, double estimatedHours}`。
- 失败/未配置/超时/畸形：返回 `Failure`（由生成器兜底）。校验：未知 phaseKey 丢弃、重复 templateKey 丢弃、超量（每阶段 >3 可选）丢弃、非法字段丢弃。
- 本地：`AiPreparationPersonalizer(LlmClient llm)`，`llm.complete(jsonMode: true)`，提示词约束输出 `{phases:[{key, optionalTasks:[{templateKey?,title,estimatedHours}], personalizedAdvice}], globalAdvice}`。
- HTTP：`HttpPreparationPersonalizer(Dio dio)`，`POST /api/v1/preparation-plans/generate`，请求体见 spec §7.2，用 `guardApi` + envelope 解码。
- fake handler：返回固定合理 JSON，覆盖 `comp_icpc`。

- [ ] **Step 1: Write the failing test (本地)**

```dart
// test/data/ai/ai_preparation_personalizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_preparation_personalizer.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

class _StubLlm implements LlmClient {
  _StubLlm(this._out);
  final Result<String> _out;
  @override
  Future<Result<String>> complete({required List<LlmMessage> messages, bool jsonMode = false, double? temperature}) async => _out;
  @override
  bool get isConfigured => true;
}

PreparationPersonalizationRequest _req() => PreparationPersonalizationRequest(
  competition: CompetitionSnapshot(id: 'comp_icpc', name: 'ACM-ICPC', category: '计算机类',
    rulesSummary: CompetitionRulesSummary(signupTime: '', contestTime: '', teamSize: '', format: '', organizer: '', officialUrl: null)),
  targetDate: DateTime(2026, 9, 1),
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner,
  phaseKeys: const ['team_formation', 'topic_selection', 'proposal_writing', 'submission_polish', 'defense_prep'],
  profile: null,
);

void main() {
  test('解析合法 JSON', () async {
    final llm = _StubLlm(Success('{"phases":[{"key":"proposal_writing","optionalTasks":[{"templateKey":"ai_algo","title":"强化训练","estimatedHours":10}],"personalizedAdvice":"多刷真题"}],"globalAdvice":"整体偏算法"}'));
    final p = AiPreparationPersonalizer(llm);
    final r = await p.personalize(req: _req());
    expect(r, isA<Success<PreparationPersonalizationResult>>());
    final data = (r as Success<PreparationPersonalizationResult>).data;
    expect(data.phases.length, 1);
    expect(data.phases[0].optionalTasks[0].title, '强化训练');
    expect(data.globalAdvice, '整体偏算法');
  });

  test('未知 phaseKey 丢弃', () async {
    final llm = _StubLlm(Success('{"phases":[{"key":"unknown_phase","optionalTasks":[]}]}'));
    final r = await AiPreparationPersonalizer(llm).personalize(req: _req());
    final data = (r as Success).data as PreparationPersonalizationResult;
    expect(data.phases, isEmpty);
  });

  test('畸形 JSON 返回 Failure', () async {
    final llm = _StubLlm(Success('not json'));
    final r = await AiPreparationPersonalizer(llm).personalize(req: _req());
    expect(r, isA<Failure<PreparationPersonalizationResult>>());
  });

  test('Llm 未配置返回 Failure', () async {
    final llm = _StubLlm(Failure(Exception('not configured')));
    final r = await AiPreparationPersonalizer(llm).personalize(req: _req());
    expect(r, isA<Failure<PreparationPersonalizationResult>>());
  });
}
```

注：`LlmClient` 接口签名以 `lib/core/ai/llm_client.dart` 为准（参考 `ai_competition_recommendation_repository.dart` 的 `llm.complete(messages:, jsonMode:, temperature:)` 用法）。`Success`/`Failure` 构造器以 `core/result/result.dart` 为准。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/ai/ai_preparation_personalizer_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

`lib/data/dto/preparation_plan_dtos.dart`：定义 request/response 序列化（`toJson`/`fromJson`），用 envelope `{code,message,data}`。

`AiPreparationPersonalizer`：仿 `AiCompetitionRecommendationRepository` 结构。系统提示词约束 AI 只返回已知 phaseKey 下的可选任务 + 建议，输出纯 JSON。解析时：未知 phaseKey 丢弃、重复 templateKey 丢弃、每阶段可选 >3 截断、非法字段跳过；解析异常 → `Failure`。Llm `Failure` 透传。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/ai/ai_preparation_personalizer_test.dart`
Expected: PASS（4 tests）。

- [ ] **Step 5: Write HTTP test + fake**

```dart
// test/data/http/http_preparation_personalizer_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/http/http_preparation_personalizer.dart';
import 'package:scho_navi/data/mock/fake_backend.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
// 复用 _req 同上结构

void main() {
  test('HTTP 调用 fake 后端返回个性化', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://fake.local'));
    dio.httpClientAdapter = FakeBackendAdapter()..registerPreparationHandler();
    final p = HttpPreparationPersonalizer(dio);
    final r = await p.personalize(req: /* 同 _req */);
    expect(r, isA<Success<PreparationPersonalizationResult>>());
    final data = (r as Success<PreparationPersonalizationResult>).data;
    expect(data.phases, isNotEmpty);
  });
}
```

实现 `HttpPreparationPersonalizer`（`guardApi` + `POST /api/v1/preparation-plans/generate` + DTO 解码）。

`lib/data/mock/fake_preparation_backend.dart`：

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

ResponseBody preparationGenerateHandler(RequestOptions options) {
  final body = options.data;
  // 固定假返回
  return ResponseBody.fromString(
    jsonEncode({
      'code': 0, 'message': 'ok',
      'data': {
        'phases': [
          {'key': 'proposal_writing', 'optionalTasks': [
            {'templateKey': 'fake_mock_train', 'title': '模拟训练', 'estimatedHours': 8},
          ], 'personalizedAdvice': '建议每周固定时段训练'}
        ],
        'globalAdvice': '保持节奏，关注官网通知',
      },
    }),
    200,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
  );
}

extension PreparationFakeRegistration on FakeBackendAdapter {
  void registerPreparationHandler() {
    register('POST', '/api/v1/preparation-plans/generate', preparationGenerateHandler);
  }
}
```

在 `fake_backend.dart` 默认 handler map 里也加：`_RouteKey('POST', '/api/v1/preparation-plans/generate'): preparationGenerateHandler`（import fake_preparation_backend.dart）。

- [ ] **Step 6: Run HTTP test**

Run: `flutter test test/data/http/http_preparation_personalizer_test.dart`
Expected: PASS。

- [ ] **Step 7: Commit**

```bash
git add lib/data/dto/preparation_plan_dtos.dart lib/data/ai/ai_preparation_personalizer.dart lib/data/http/http_preparation_personalizer.dart lib/data/mock/fake_preparation_backend.dart lib/data/mock/fake_backend.dart test/data/ai/ai_preparation_personalizer_test.dart test/data/http/http_preparation_personalizer_test.dart
git commit -m "feat(preparation): AI 个性化(本地+HTTP+DTO+fake)"
```

---

## Task C8: PreparationPlanGenerator 生成器

**Files:**
- Create: `lib/domain/services/preparation_plan_generator.dart`
- Test: `test/domain/services/preparation_plan_generator_test.dart`

**Interfaces:**
- Consumes: `PreparationTemplateProvider`、`PreparationScheduler`、`PreparationPersonalizer`。
- Produces: `PreparationPlanGenerator.generate({required CompetitionSnapshot competition, required DateTime targetDate, required WeeklyCommitment weeklyCommitment, required ExperienceLevel experienceLevel, required DateTime today, UserProfile? profile}) -> Future<PreparationPlan>`。
- 流程（spec §7.1）：
  1. `template = await provider.load(category: competition.category, competitionId: competition.id)`
  2. 按经验等级补基础：beginner 在 `team_formation`/`topic_selection` 追加额外必做任务（从一组常量补）。
  3. 按每周投入预算选可选任务：`budgetHours = weeklyCommitment.hoursPerWeek * weeks`；累计可选任务 estimatedHours 不超预算。
  4. AI 个性化（personalizer）；成功则合并可选任务到对应阶段（去重 templateKey）、写入 personalizedAdvice/globalSummary；失败则忽略。
  5. 排期：`PreparationScheduler.schedule(...)` → 给每阶段 startDate/endDate，任务 dueDate = 阶段 endDate clamp[today,targetDate]。
  6. 组装 `PreparationPlan`（id 用 `uuid` 或 `now.millisecondsSinceEpoch`，createdAt/updatedAt=today，status=active）。
  7. 必做任务标记 `kind=required`、可选 `optional`。负荷警示由 `isTightSchedule` 或必做超预算计算（返回 bool 标志挂在 plan？plan 加 `bool? overload` 字段——见实施说明）。

> 实施说明：`PreparationPlan` 加 `final bool tightSchedule;` 与 `final bool overload;` 字段（在 C1 上补，或此处补并更新 C1 测试）。生成器返回 `PreparationPlan`，详情页读 `tightSchedule`/`overload` 显示警示。

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/services/preparation_plan_generator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_preparation_personalizer.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/domain/entities/preparation_template.dart';
import 'package:scho_navi/domain/repositories/preparation_template_provider.dart';
import 'package:scho_navi/domain/services/preparation_plan_generator.dart';
import 'package:scho_navi/data/fixtures/preparation_templates.dart';

class _StaticProvider implements PreparationTemplateProvider {
  @override
  Future<PreparationTemplate> load({String? category, String? competitionId}) async => defaultPreparationTemplate();
}

class _SuccessPersonalizer implements PreparationPersonalizer {
  @override
  Future<Result<PreparationPersonalizationResult>> personalize({required PreparationPersonalizationRequest req}) async =>
      Success(PreparationPersonalizationResult(phases: [
        PreparationPhasePersonalization(key: 'proposal_writing',
          optionalTasks: [PreparationOptionalTaskSuggestion(templateKey: 'ai_x', title: 'AI 建议', estimatedHours: 6)],
          personalizedAdvice: 'AI 建议'),
      ], globalAdvice: 'AI 全局'));
}

class _FailPersonalizer implements PreparationPersonalizer {
  @override
  Future<Result<PreparationPersonalizationResult>> personalize({required PreparationPersonalizationRequest req}) async =>
      Failure(Exception('boom'));
}

CompetitionSnapshot _comp() => CompetitionSnapshot(id: 'comp_icpc', name: 'ACM-ICPC', category: '计算机类',
  rulesSummary: CompetitionRulesSummary(signupTime: '', contestTime: '', teamSize: '', format: '', organizer: '', officialUrl: null));

void main() {
  test('生成含 5 阶段 + 必做任务 + 排期日期', () async {
    final g = PreparationPlanGenerator(templateProvider: _StaticProvider(), personalizer: _SuccessPersonalizer());
    final plan = await g.generate(
      competition: _comp(), targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10, experienceLevel: ExperienceLevel.beginner,
      today: DateTime(2026, 6, 28), profile: null);
    expect(plan.phases.length, 5);
    expect(plan.phases.every((p) => p.tasks.any((t) => t.kind == PreparationTaskKind.required)), isTrue);
    expect(plan.phases.first.startDate, DateTime(2026, 6, 28));
    expect(plan.phases.last.endDate, DateTime(2026, 9, 1));
    // AI 可选任务被合并
    final writing = plan.phases.firstWhere((p) => p.key == 'proposal_writing');
    expect(writing.tasks.any((t) => t.templateKey == 'ai_x'), isTrue);
    expect(plan.personalizedSummary, 'AI 全局');
  });

  test('AI 失败时仍生成标准计划且必做不丢', () async {
    final g = PreparationPlanGenerator(templateProvider: _StaticProvider(), personalizer: _FailPersonalizer());
    final plan = await g.generate(
      competition: _comp(), targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10, experienceLevel: ExperienceLevel.experienced,
      today: DateTime(2026, 6, 28), profile: null);
    expect(plan.phases.length, 5);
    expect(plan.phases.every((p) => p.tasks.any((t) => t.kind == PreparationTaskKind.required)), isTrue);
    expect(plan.personalizedSummary, isNull);
  });

  test('临近目标日期压缩排期 + tightSchedule 标志', () async {
    final g = PreparationPlanGenerator(templateProvider: _StaticProvider(), personalizer: _FailPersonalizer());
    final plan = await g.generate(
      competition: _comp(), targetDate: DateTime(2026, 7, 5),
      weeklyCommitment: WeeklyCommitment.hours16plus, experienceLevel: ExperienceLevel.experienced,
      today: DateTime(2026, 6, 28), profile: null);
    expect(plan.tightSchedule, isTrue);
    expect(plan.phases.length, lessThanOrEqualTo(7));
  });

  test('任务 dueDate clamp 到 [today, targetDate]', () async {
    final g = PreparationPlanGenerator(templateProvider: _StaticProvider(), personalizer: _FailPersonalizer());
    final plan = await g.generate(
      competition: _comp(), targetDate: DateTime(2026, 9, 1),
      weeklyCommitment: WeeklyCommitment.hours6to10, experienceLevel: ExperienceLevel.intermediate,
      today: DateTime(2026, 6, 28), profile: null);
    for (final p in plan.phases) {
      for (final t in p.tasks) {
        expect(!t.dueDate.isBefore(DateTime(2026, 6, 28)), isTrue);
        expect(!t.dueDate.isAfter(DateTime(2026, 9, 1)), isTrue);
      }
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/services/preparation_plan_generator_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

实现 `PreparationPlanGenerator`，按 §7.1 流程。生成 plan id：`'pp_${today.millisecondsSinceEpoch}'`（避免引入 uuid 依赖；若项目已有 uuid 则用之）。预算选择可选任务：按阶段顺序累计 estimatedHours ≤ `budgetHours`，超出的可选任务不选。`overload` = 必做总 estimatedHours > budgetHours。`tightSchedule` = `PreparationScheduler.isTightSchedule(today, targetDate)`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/services/preparation_plan_generator_test.dart`
Expected: PASS（4 tests）。

- [ ] **Step 5: 先补 C1 的 tightSchedule/overload 字段并跑 C1+C8**

若 C1 的 `PreparationPlan` 未含 `tightSchedule`/`overload`，回 `lib/domain/entities/preparation_plan.dart` 加 `final bool tightSchedule; final bool overload;`（默认 false）并更新 `fromJson/toJson`/C1 测试往返。

Run: `flutter test test/domain/entities/preparation_plan_test.dart test/domain/services/preparation_plan_generator_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/domain/services/preparation_plan_generator.dart lib/domain/entities/preparation_plan.dart test/domain/services/preparation_plan_generator_test.dart test/domain/entities/preparation_plan_test.dart
git commit -m "feat(preparation): 计划生成器(模板叠加+预算+排期+AI合并+兜底)"
```

---

## Task C9: Providers 注册

**Files:**
- Create: `lib/features/preparation/providers/preparation_providers.dart`
- Modify: `lib/core/di/providers.dart`
- Test: `test/features/preparation/providers/preparation_providers_test.dart`

**Interfaces:**
- `preparationPlanRepositoryProvider` → `LocalPreparationPlanRepository(localStoreProvider)`（autoDispose? 否，需 watch 跨页 — 用普通 Provider，dispose 在 app 级）。
- `preparationTemplateProvider` → `LocalPreparationTemplateProvider(bundle: rootBundle)`。
- `preparationPersonalizerProvider` → 按 `DataSource` 切换：llm → `AiPreparationPersonalizer(llmClientProvider)`；http → `HttpPreparationPersonalizer(dioProvider)`。
- `preparationPlanGeneratorProvider` → `PreparationPlanGenerator(templateProvider, personalizer)`。
- `preparationPlanListProvider` → `StreamProvider<List<PreparationPlan>>`（watch repo.watch()）。
- `activePlanForCompetitionProvider`（family `<String, PreparationPlan?>`）→ 同步查 `repo.activeForCompetition(id)`（或 StreamProvider.family）。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/preparation/providers/preparation_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  test('save 后 list stream 推送', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(preparationPlanRepositoryProvider);
    await repo.save(PreparationPlan(
      id: 'p1',
      competition: CompetitionSnapshot(id: 'c1', name: 'C', category: '计算机类',
        rulesSummary: CompetitionRulesSummary(signupTime:'',contestTime:'',teamSize:'',format:'',organizer:'',officialUrl:null)),
      targetDate: DateTime(2026,9,1), weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.beginner, status: PreparationPlanStatus.active,
      phases: const [], tightSchedule: false, overload: false,
      createdAt: DateTime(2026,6,28), updatedAt: DateTime(2026,6,28),
    ));
    final list = await container.read(preparationPlanListProvider.future);
    expect(list.length, 1);
  });

  test('activePlanForCompetition 命中', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(preparationPlanRepositoryProvider);
    await repo.save(PreparationPlan(
      id: 'p1',
      competition: CompetitionSnapshot(id: 'c1', name: 'C', category: '计算机类',
        rulesSummary: CompetitionRulesSummary(signupTime:'',contestTime:'',teamSize:'',format:'',organizer:'',officialUrl:null)),
      targetDate: DateTime(2026,9,1), weeklyCommitment: WeeklyCommitment.hours6to10,
      experienceLevel: ExperienceLevel.beginner, status: PreparationPlanStatus.active,
      phases: const [], tightSchedule: false, overload: false,
      createdAt: DateTime(2026,6,28), updatedAt: DateTime(2026,6,28),
    ));
    expect(container.read(activePlanForCompetitionProvider('c1'))?.id, 'p1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/preparation/providers/preparation_providers_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/preparation/providers/preparation_providers.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../data/ai/ai_preparation_personalizer.dart';
import '../../../data/http/http_preparation_personalizer.dart';
import '../../../data/local/local_preparation_plan_repository.dart';
import '../../../data/local/local_preparation_template_provider.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/repositories/preparation_plan_repository.dart';
import '../../../domain/repositories/preparation_template_provider.dart';
import '../../../domain/services/preparation_plan_generator.dart';

final preparationPlanRepositoryProvider = Provider<PreparationPlanRepository>((ref) {
  final repo = LocalPreparationPlanRepository(ref.watch(localStoreProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final preparationTemplateProvider = Provider<PreparationTemplateProvider>(
  (_) => LocalPreparationTemplateProvider(bundle: rootBundle),
);

final preparationPersonalizerProvider = Provider<PreparationPersonalizer>((ref) {
  return switch (ref.watch(appConfigProvider).dataSource) {
    DataSource.llm => AiPreparationPersonalizer(ref.watch(llmClientProvider)),
    DataSource.http => HttpPreparationPersonalizer(ref.watch(dioProvider)),
  };
});

final preparationPlanGeneratorProvider = Provider<PreparationPlanGenerator>((ref) =>
    PreparationPlanGenerator(
      templateProvider: ref.watch(preparationTemplateProvider),
      personalizer: ref.watch(preparationPersonalizerProvider),
    ));

final preparationPlanListProvider = StreamProvider<List<PreparationPlan>>((ref) =>
    ref.watch(preparationPlanRepositoryProvider).watch());

final activePlanForCompetitionProvider =
    Provider.family<PreparationPlan?, String>((ref, competitionId) {
  final repo = ref.watch(preparationPlanRepositoryProvider);
  // 同步查：list 在内存
  return repo.activeForCompetition(competitionId);
});
```

注：`localStoreProvider` 是否已 export 在 `core/di/providers.dart`——确认存在（drawer/history 用到）。`rootBundle` 来自 `flutter/services.dart`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/preparation/providers/preparation_providers_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/preparation/providers/preparation_providers.dart test/features/preparation/providers/preparation_providers_test.dart
git commit -m "feat(preparation): Riverpod providers 注册"
```

---

## Task C10: 创建表单 PreparationPlanFormPage

**Files:**
- Create: `lib/features/preparation/pages/preparation_plan_form_page.dart`
- Test: `test/features/preparation/pages/preparation_plan_form_page_test.dart`

**Interfaces:**
- 构造：`PreparationPlanFormPage({required CompetitionSnapshot competition})`（competition 来自详情页）。
- 表单字段：目标日期（DatePicker，必须晚于当天）、每周投入（4 档 SegmentedButton/单选）、当前水平（3 档，从 `UserProfile` 预填不回写）。
- 提示文案："AI 模式会发送你的档案用于个性化建议"（仅当 `appConfig.dataSource == llm && llm.isConfigured` 时显示）。
- 提交：校验目标日期 > 今天 → 调 `preparationPlanGeneratorProvider.generate(...)` → 保存到 repo → `context.goReplacement('/preparation-plans/${plan.id}')`（或 push 详情）。
- 生成中显示加载（按钮禁用 + 进度）。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/preparation/pages/preparation_plan_form_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plan_form_page.dart';

CompetitionSnapshot _comp() => CompetitionSnapshot(id: 'comp_icpc', name: 'ACM-ICPC', category: '计算机类',
  rulesSummary: CompetitionRulesSummary(signupTime:'',contestTime:'',teamSize:'',format:'',organizer:'',officialUrl:null));

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('渲染三字段 + AI 提示 + 创建按钮', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [], // 用默认 provider（模板/兜底 personalizer）
      child: MaterialApp(home: PreparationPlanFormPage(competition: _comp())),
    ));
    expect(find.textContaining('目标日期'), findsOneWidget);
    expect(find.textContaining('每周投入'), findsOneWidget);
    expect(find.textContaining('当前水平'), findsOneWidget);
    expect(find.textContaining('创建'), findsOneWidget);
  });

  testWidgets('未选目标日期时创建按钮禁用/提示', (t) async {
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: PreparationPlanFormPage(competition: _comp()))));
    // 初始无日期，点击创建应弹校验
    await t.tap(find.textContaining('创建'));
    await t.pumpAndSettle();
    expect(find.textContaining('请选择'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to fails**

Run: `flutter test test/features/preparation/pages/preparation_plan_form_page_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

实现表单：`DatePicker` 选目标日期（`firstDate: today`，校验 `targetDate.isAfter(today)`）、`SegmentedButton<WeeklyCommitment>`、`SegmentedButton<ExperienceLevel>`（预填 `ref.read(profileProvider)` 的水平映射，若无则 beginner）。提交按钮调 generator，加载态用 `CircularProgressIndicator`。AI 提示 Row（`Icons.info_outline` + 文案），条件渲染。生成完成后 `context.pushReplacement('/preparation-plans/${plan.id}')`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/preparation/pages/preparation_plan_form_page_test.dart`
Expected: PASS（2 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/preparation/pages/preparation_plan_form_page.dart test/features/preparation/pages/preparation_plan_form_page_test.dart
git commit -m "feat(preparation): 创建备赛计划表单"
```

---

## Task C11: 计划详情页 PreparationPlanDetailPage

**Files:**
- Create: `lib/features/preparation/pages/preparation_plan_detail_page.dart`
- Create: `lib/features/preparation/widgets/preparation_countdown.dart`
- Create: `lib/features/preparation/widgets/preparation_phase_timeline.dart`
- Create: `lib/features/preparation/widgets/preparation_task_list.dart`
- Test: `test/features/preparation/pages/preparation_plan_detail_page_test.dart`

**Interfaces:**
- 构造：`PreparationPlanDetailPage({required String planId})`。
- 顶部：倒计时（`PreparationCountdown`，剩余天数 = targetDate - today）、总进度（完成任务数/总任务数，进度条）、当前阶段（today 落在哪个阶段）。`tightSchedule`/`overload` 为 true 时顶部警示横幅。
- 阶段时间轴（`PreparationPhaseTimeline`）：每阶段标题 + 日期区间 + 进度 + 当前阶段高亮。
- 任务清单（`PreparationTaskList`）：按阶段分组，每任务 checkbox（完成/撤销）+ 标题 + dueDate + 必做/可选/用户标记 + 备注 + 编辑/删除（必做不可删）。添加任务按钮（每阶段可加 userAdded 任务）。
- 操作：修改目标日期（弹 DatePicker，仅重算未完成任务 dueDate，保留完成+备注）、归档、删除（二次确认 `AlertDialog`）。
- 状态：通过 `preparationPlanRepositoryProvider` watch 单 plan（或 `findById` + 局部 setState 保存后刷新）。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/preparation/pages/preparation_plan_detail_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plan_detail_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

PreparationPlan _plan() => PreparationPlan(
  id: 'p1',
  competition: CompetitionSnapshot(id: 'c1', name: 'ACM-ICPC', category: '计算机类',
    rulesSummary: CompetitionRulesSummary(signupTime:'',contestTime:'',teamSize:'',format:'',organizer:'',officialUrl:null)),
  targetDate: DateTime(2026, 9, 1),
  weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner,
  status: PreparationPlanStatus.active,
  phases: [
    PreparationPhase(key: 'team_formation', title: '组队',
      startDate: DateTime(2026,6,28), endDate: DateTime(2026,7,5),
      tasks: [
        PreparationTask(id: 't1', templateKey: 'team_form', title: '组建队伍', kind: PreparationTaskKind.required,
          estimatedHours: 3, dueDate: DateTime(2026,7,1)),
      ]),
  ],
  tightSchedule: false, overload: false,
  createdAt: DateTime(2026,6,28), updatedAt: DateTime(2026,6,28),
);

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('渲染倒计时+进度+时间轴+任务', (t) async {
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: PreparationPlanDetailPage(planId: 'p1'))));
    // 预置 plan
    final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await container.read(preparationPlanRepositoryProvider).save(_plan());
    await t.pumpAndSettle();
    expect(find.textContaining('剩余'), findsOneWidget);
    expect(find.text('组队'), findsOneWidget);
    expect(find.text('组建队伍'), findsOneWidget);
  });

  testWidgets('勾选任务标记完成', (t) async {
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: PreparationPlanDetailPage(planId: 'p1'))));
    final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await container.read(preparationPlanRepositoryProvider).save(_plan());
    await t.pumpAndSettle();
    await t.tap(find.byType(Checkbox));
    await t.pumpAndSettle();
    final plan = container.read(preparationPlanRepositoryProvider).findById('p1')!;
    expect(plan.phases[0].tasks[0].completed, isTrue);
  });

  testWidgets('删除必做任务被阻止', (t) async {
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: PreparationPlanDetailPage(planId: 'p1'))));
    final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await container.read(preparationPlanRepositoryProvider).save(_plan());
    await t.pumpAndSettle();
    // 必做任务的删除按钮不存在或禁用
    expect(find.byIcon(Icons.delete_outline), findsNothing); // 必做无删除按钮
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/preparation/pages/preparation_plan_detail_page_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

实现详情页 + 三个子 widget。任务完成/撤销：`repo.save(plan.copyWith(phases: updated))`。添加任务：弹 dialog 收集 title/dueDate，`kind=userAdded`。编辑任务：title/note/dueDate。修改目标日期：DatePicker → 对未完成任务重算 dueDate（按阶段占比或保持阶段内相对位置，简单实现：重跑 scheduler 给阶段日期，未完成任务 dueDate 设为新阶段 endDate）。归档/删除二次确认。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/preparation/pages/preparation_plan_detail_page_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/preparation/pages/preparation_plan_detail_page.dart lib/features/preparation/widgets/preparation_countdown.dart lib/features/preparation/widgets/preparation_phase_timeline.dart lib/features/preparation/widgets/preparation_task_list.dart test/features/preparation/pages/preparation_plan_detail_page_test.dart
git commit -m "feat(preparation): 计划详情页(倒计时/时间轴/任务清单/编辑)"
```

---

## Task C12: 我的备赛列表页 PreparationPlansPage + 列表行

**Files:**
- Create: `lib/features/preparation/pages/preparation_plans_page.dart`
- Create: `lib/features/preparation/widgets/preparation_plan_list_tile.dart`
- Test: `test/features/preparation/pages/preparation_plans_page_test.dart`

**Interfaces:**
- `PreparationPlansPage`：AppBar"我的备赛"。`watch(preparationPlanListProvider)` → 渲染列表行（`PreparationPlanListTile`：赛事名 + 剩余天数 + 完成度 + 进入详情）。活动/归档筛选（顶部 `SegmentedButton` 或 `TabBar`：进行中/已归档，默认进行中，归档默认隐藏）。空态 `EmptyView`。点击行 `context.push('/preparation-plans/${plan.id}')`。
- 剩余天数 = `max(0, targetDate.difference(today).inDays)`。完成度 = `completed/total`。

- [ ] **Step 1: Write the failing test**

```dart
// test/features/preparation/pages/preparation_plans_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plans_page.dart';
import 'package:scho_navi/features/preparation/providers/preparation_providers.dart';

PreparationPlan _plan({String id = 'p1', PreparationPlanStatus status = PreparationPlanStatus.active}) => PreparationPlan(
  id: id,
  competition: CompetitionSnapshot(id: 'c1', name: 'ACM-ICPC', category: '计算机类',
    rulesSummary: CompetitionRulesSummary(signupTime:'',contestTime:'',teamSize:'',format:'',organizer:'',officialUrl:null)),
  targetDate: DateTime(2026,9,1), weeklyCommitment: WeeklyCommitment.hours6to10,
  experienceLevel: ExperienceLevel.beginner, status: status,
  phases: [PreparationPhase(key:'t', title:'组队', startDate: DateTime(2026,6,28), endDate: DateTime(2026,7,5),
    tasks: [PreparationTask(id:'t1', templateKey:'k', title:'组建', kind: PreparationTaskKind.required, estimatedHours:3, dueDate: DateTime(2026,7,1))])],
  tightSchedule: false, overload: false, createdAt: DateTime(2026,6,28), updatedAt: DateTime(2026,6,28),
);

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('默认显示进行中，归档隐藏', (t) async {
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: PreparationPlansPage())));
    final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await container.read(preparationPlanRepositoryProvider).save(_plan(id: 'p1'));
    await container.read(preparationPlanRepositoryProvider).save(_plan(id: 'p2', status: PreparationPlanStatus.archived));
    await t.pumpAndSettle();
    expect(find.text('ACM-ICPC'), findsOneWidget); // 只一个（进行中）
  });

  testWidgets('切到归档筛选显示归档', (t) async {
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: PreparationPlansPage())));
    final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    await container.read(preparationPlanRepositoryProvider).save(_plan(id: 'p2', status: PreparationPlanStatus.archived));
    await t.pumpAndSettle();
    await t.tap(find.text('已归档'));
    await t.pumpAndSettle();
    expect(find.text('ACM-ICPC'), findsOneWidget);
  });

  testWidgets('空态显示提示', (t) async {
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: PreparationPlansPage())));
    await t.pumpAndSettle();
    expect(find.textContaining('暂无'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/preparation/pages/preparation_plans_page_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: Write minimal implementation**

实现列表页 + 行 widget。筛选用 `SegmentedButton<_PlanFilter>{active, archived}`，默认 active。列表按 `updatedAt` 倒序。行用 `BentoTile` 风格（圆角描边），44px 触控。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/preparation/pages/preparation_plans_page_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/preparation/pages/preparation_plans_page.dart lib/features/preparation/widgets/preparation_plan_list_tile.dart test/features/preparation/pages/preparation_plans_page_test.dart
git commit -m "feat(preparation): 我的备赛列表页"
```

---

## Task C13: 路由 + 抽屉入口 + 详情页接入"开始备赛"

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/shared/widgets/app_menu_drawer.dart`
- Modify: `lib/features/competition_recommendation/pages/competition_detail_page.dart`
- Test: 扩展详情页测试 + 抽屉测试

**Interfaces:**
- 路由：`/preparation-plans` → `PreparationPlansPage`；`/preparation-plans/new?competitionId=...` → `PreparationPlanFormPage`（从详情页进入，需构造 `CompetitionSnapshot`：用 `competitionCatalogRepositoryProvider.findById` 取基底 + snapshot 化）；`/preparation-plans/:id` → `PreparationPlanDetailPage`。
- 抽屉：`AppMenuDrawer` 加 `_DrawerTile(icon: Icons.flag_outlined, label: '我的备赛', onTap: () => _navigate(context, '/preparation-plans'))`，放在"我的收藏"之后。
- 详情页"开始备赛/继续备赛"按钮：
  - `watch(activePlanForCompetitionProvider(competitionId))` → 有则"继续备赛"→ `context.push('/preparation-plans/${active.id}')`；无则"开始备赛"→ `context.push('/preparation-plans/new?competitionId=$competitionId')`。
  - 构造 `CompetitionSnapshot`：从目录 `findById` 取 `RecommendedCompetition` → 转为 snapshot（id/name/category + rulesSummary）。form 页也可按 id 自取。

- [ ] **Step 1: Write the failing test**

扩展 `competition_detail_page_test.dart`：

```dart
testWidgets('无进行中计划显示"开始备赛"且可点击', (t) async {
  SharedPreferences.setMockInitialValues({});
  await t.pumpWidget(const ProviderScope(child: MaterialApp(home: CompetitionDetailPage(competitionId: 'comp_icpc'))));
  await t.pumpAndSettle();
  final btn = find.text('开始备赛');
  expect(btn, findsOneWidget);
  await t.tap(btn);
  await t.pumpAndSettle();
  // 进入表单页（断言表单标题或字段）
  expect(find.textContaining('目标日期'), findsOneWidget);
});

testWidgets('有进行中计划显示"继续备赛"', (t) async {
  SharedPreferences.setMockInitialValues({});
  // 预存一个 active plan for comp_icpc
  await t.pumpWidget(ProviderScope(child: MaterialApp(home: CompetitionDetailPage(competitionId: 'comp_icpc'))));
  final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  await container.read(preparationPlanRepositoryProvider).save(PreparationPlan(
    id: 'p1',
    competition: CompetitionSnapshot(id: 'comp_icpc', name: 'ACM-ICPC', category: '计算机类',
      rulesSummary: CompetitionRulesSummary(signupTime:'',contestTime:'',teamSize:'',format:'',organizer:'',officialUrl:null)),
    targetDate: DateTime(2026,9,1), weeklyCommitment: WeeklyCommitment.hours6to10,
    experienceLevel: ExperienceLevel.beginner, status: PreparationPlanStatus.active,
    phases: const [], tightSchedule: false, overload: false,
    createdAt: DateTime(2026,6,28), updatedAt: DateTime(2026,6,28),
  ));
  await t.pumpAndSettle();
  expect(find.text('继续备赛'), findsOneWidget);
});
```

抽屉测试：

```dart
// test/shared/widgets/app_menu_drawer_test.dart（扩展或新建）
testWidgets('抽屉含"我的备赛"', (t) async {
  SharedPreferences.setMockInitialValues({});
  await t.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(endDrawer: AppMenuDrawer(), body: SizedBox()))));
  await t.dragFrom(const Offset(1000, 200), const Offset(-300, 0)); // 右抽屉
  await t.pumpAndSettle();
  expect(find.text('我的备赛'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/competition_recommendation/pages/competition_detail_page_test.dart test/shared/widgets/app_menu_drawer_test.dart`
Expected: FAIL — 按钮仍 disabled，抽屉无"我的备赛"。

- [ ] **Step 3: Write minimal implementation**

路由 `app_router.dart` 加三条路由 + import。抽屉加 tile。详情页把备赛按钮 `onPressed: null` 改为按 active plan 切换文案与回调，构造 snapshot：

```dart
final active = ref.watch(activePlanForCompetitionProvider(competitionId));
...
OutlinedButton.icon(
  onPressed: () {
    if (active != null) {
      context.push('/preparation-plans/${active.id}');
    } else {
      context.push('/preparation-plans/new?competitionId=$competitionId');
    }
  },
  icon: const Icon(Icons.flag_outlined),
  label: Text(active != null ? '继续备赛' : '开始备赛'),
)
```

`/preparation-plans/new` 页面按 `competitionId` 从目录取基底构造 `CompetitionSnapshot` 传入 form。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/competition_recommendation/pages/competition_detail_page_test.dart test/shared/widgets/app_menu_drawer_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/core/router/app_router.dart lib/shared/widgets/app_menu_drawer.dart lib/features/competition_recommendation/pages/competition_detail_page.dart test/
git commit -m "feat(preparation): 路由+抽屉入口+详情页接入开始备赛"
```

---

## Task C14: HTTP 契约文档更新

**Files:**
- Modify: `docs/api-contract.md`
- Modify: `docs/openapi.yaml`

- [ ] **Step 1: 加端点契约**

在 `api-contract.md` 加 `POST /preparation-plans/generate` 段：请求体（competition/targetDate/weeklyCommitment/experienceLevel/profile?）、响应信封 data 结构（phases[{key,optionalTasks[{templateKey?,title,estimatedHours}],personalizedAdvice}],globalAdvice）、错误码。

在 `openapi.yaml` paths 加 `/preparation-plans/generate`（POST），requestBody schema 与 responses 200 信封 schema。server base 已为 `/api/v1`。

- [ ] **Step 2: Commit**

```bash
git add docs/api-contract.md docs/openapi.yaml
git commit -m "docs(api): 新增备赛计划生成端点契约"
```

---

## Task C15: 验证与收尾

- [ ] **Step 1: Run analyze**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: PASS。记录总数对比基线。

- [ ] **Step 3: 无障碍/375px/大字/深色**

widget test 覆盖：列表页、详情页、表单页在 375 宽 + textScale 1.5 + dark 下无 overflow。

- [ ] **Step 4: 手动路径演练（可选，run skill）**

从首页竞赛卡 → 详情 → 开始备赛 → 填表 → 生成 → 详情 → 勾任务 → 修改日期 → 归档 → 我的备赛列表筛选。AI 未配置时走标准模板兜底。

- [ ] **Step 5: Commit & 更新记忆**

```bash
git add -A
git commit -m "test(preparation): 无障碍与大字体验证"
```

更新 `schonavi-roadmap-status.md`：Plan C 完成，备赛计划 MVP 上线；更新 `schonavi-aigc-competition-rubric.md` 相关进度（大模型应用能力维度补强：竞赛流式/原地响应 + 备赛个性化生成）。

---

## Plan C 自检

- spec §4.2 模型 + CompetitionSnapshot 单一快照 → C1 ✓（删除重复 source*）
- spec §4.2 PreparationTaskKind + completedAt 推导 + templateKey/estimatedHours → C1 ✓
- spec §4.3 Dart 通用骨架 + 必做锁死 → C2 ✓
- spec §4.4 JSON 类别/赛事覆盖 → C3 ✓
- spec §4.5 PreparationTemplateProvider 抽象 + 本地实现（v1 不远程）→ C4 ✓
- spec §7.1 生成顺序 → C8 ✓
- spec §7.2 AI 个性化 + 校验丢弃 + 兜底 → C7/C8 ✓
- spec §7.3 确定性排期 + 相邻合并 + clamp + 警示 → C5/C8 ✓
- spec §7.4 编辑语义（必做不可删、改日期重排未完成、归档/删除二次确认）→ C11 ✓
- spec §8 路由/表单预填不回写/AI 发送档案提示/抽屉入口 → C10/C13 ✓
- spec §9 持久化 key + watch + 损坏降级 + HTTP 契约 + fake → C6/C7/C14 ✓
- spec §10 测试覆盖（生成/压缩/预算/AI兜底/持久化降级/继续备赛判定）→ C5/C6/C7/C8/C11/C13 ✓
- spec §11 Assumptions（无 SSE/无团队/无云同步）→ 范围控制 ✓
- D10 每周投入预算纳入 v1 → C8 ✓
- D11 预填+提示 → C10 ✓
- D13 卡片只放官网、备赛在详情页 → Plan B/C13 ✓
- D14 列表按计划、归档默认隐藏+筛选 → C12 ✓
