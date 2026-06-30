# 备赛功能升级：智能备赛日历 + AI 助手设计

- 日期：2026-06-29
- 状态：修订完成，待复审
- 关联：`docs/superpowers/specs/2026-06-28-competition-recommendation-preparation-design.md`（备赛 MVP 前身）
- 分支：iter4rc1
- 本次修订：补齐旧数据迁移、日历日期协议、双段模板与排期、改动卡 schema、原子应用、助手历史、手工编辑语义及 LLM/HTTP/Fake 实现矩阵

## 1. 主题与范围

把备赛功能从「一次性生成计划 + 手工改」升级为 **智能备赛日历 + 随时唤出的 AI 助手**。AI 负责水平诊断、计划个性化和调整建议；日期计算、模板必做任务、安全校验和最终写入均由确定性代码负责。

### 1.1 设计目标

- 充分体现 AIGC 价值，同时保持计划事实和日期可验证。
- 统一处理窗口型赛事（比赛集中在几天）与提交型赛事（作品提交到 DDL，可选答辩）。
- 让用户水平从「自行猜档」变为「AI 诊断 + 用户确认或覆盖」。
- AI 调整以结构化改动卡呈现，逐条确认，不直接写计划。
- 用户消息保留气泡；AI 回复改为全宽无气泡布局，对齐主流 AI 对话产品。
- 保持本地模板、手工编辑和离线演示可用；AI 失败不得破坏已有计划。

### 1.2 设计原则

- **客户端确定性**：阶段筛选、日期排期、改动卡校验和计划写入由 Dart 代码完成。
- **AI 只提议**：LLM 只能在给定竞赛、阶段和任务范围内诊断或提出建议，不得自行应用。
- **按日建模**：赛事锚点和任务截止日是日历日期，不是时间戳。
- **逐条可审计**：每张卡有稳定 ID、状态、理由和应用结果，重复点击必须幂等。
- **向后兼容**：升级不得因新增字段静默丢弃 `competition_preparation_plans.v1` 中的旧计划。

### 1.3 本 spec 的 5 个部分

| 部分 | 内容 | 依赖 |
|---|---|---|
| P0 聊天气泡拆分 | AI 回复全宽 + 行距 + 圆圈红感叹号错误态 | 无 |
| P1 自建日期选择器 | 单日、区间、多锚点三模式 | 无 |
| P2 双段时间模型 | 日历日期协议、时间类型、模板筛选、分段排期和兼容迁移 | P1 |
| P3 水平诊断 | 两问诊断、用户确认、类目画像持久化 | 无 |
| P4 AI 助手改日历 | 对话、结构化改动卡、逐条原子应用和历史状态 | P0、P2 |

### 1.4 不在本 spec

- 时间轴视觉重做（`preparation_phase_timeline.dart`），仅做适配双段时间模型所需的最小改动。
- 备赛计划持久化迁移到 Drift，仍使用 `LocalStore`/SharedPreferences。
- 团队协作、账号云同步、系统日历同步和系统通知。
- 引入新的状态管理、路由、持久化或 HTTP 第三方库。

---

## 2. 日期、模板与领域模型

### 2.1 日历日期协议

`targetDate`、`eventEndDate`、`defenseDate`、阶段起止日和任务 `dueDate` 都是无时区的日历日期：

- Dart 内统一规范化为 `DateTime(value.year, value.month, value.day)`。
- JSON/OpenAPI 统一使用 `YYYY-MM-DD`，schema 为 `type: string, format: date`。
- `createdAt`、`updatedAt`、`diagnosedAt` 等审计时间仍用 UTC RFC 3339 `date-time`。
- generate/assistant 请求显式携带 `calendar_today: YYYY-MM-DD`，使客户端、直接 LLM 和 HTTP 后端使用同一排期基准。
- `calendar_today` 是本次本地计划操作的权威日历基准；后端只校验格式和与锚点的顺序，不用服务器时区替换它。

所有日期区间均为闭区间。创建新计划时 `targetDate > calendarToday`。

### 2.2 双段时间模型

```dart
enum CompetitionTimelineType { eventWindow, submission }
```

`PreparationPlan` 在现有字段基础上新增：

| 字段 | 窗口型 | 提交型 |
|---|---|---|
| `timelineType` | `eventWindow` | `submission` |
| `targetDate` | 比赛开始日 | 提交 DDL |
| `eventEndDate` | 比赛结束日，缺省等于 `targetDate` | null |
| `defenseDate` | null | 答辩/决赛日，可空 |
| `revision` | 计划版本号，新建为 0，每次成功保存递增 1 | 同左 |

创建与编辑约束：

- 窗口型：`eventEndDate >= targetDate`。
- 提交型：`eventEndDate == null`；若有答辩，`defenseDate > targetDate`。
- 与时间类型无关的字段必须为 null，避免出现两套锚点同时生效。
- `PreparationScheduler.isTightSchedule` 只计算 `[calendarToday, targetDate]` 的赛前/提交前区间。

### 2.3 模板选择与分段排期

不能把现有提交型五阶段模板无条件用于所有赛事。模板提供者改为按时间类型加载：

```dart
abstract interface class PreparationTemplateProvider {
  Future<PreparationTemplate> load({
    required CompetitionTimelineType timelineType,
    required bool includeDefense,
    required String category,
    required String competitionId,
  });
}
```

永久离线兜底包含两套骨架：

- 窗口型：`team_formation`、`rules_review`、`skill_training`、`mock_event`、`final_check`。
- 提交型：`team_formation`、`topic_selection`、`proposal_writing`、`submission_polish`。
- 仅当提交型且 `defenseDate != null` 时追加 `defense_prep`。

已知赛事的默认时间类型由 `lib/data/fixtures/competition_timeline_defaults.dart` 中的显式 `CompetitionTimelineDefaults` 配置按 competition ID 决定，不根据名称或自然语言赛制猜测。向导使用该值预选，用户仍可在创建计划时修改；未知赛事不设默认值，必须由用户选择。

首批明确分类：

| competition ID | 默认类型 | 依据 |
|---|---|---|
| `comp_icpc` | `eventWindow` | 现场 5 小时算法编程，按解题数和罚时排名 |
| `comp_lanqiao` | `eventWindow` | 省赛/国赛为现场或限时编程，不是作品 DDL |

因此采用「窗口型 + 重写 override」方案。`assets/preparation_templates/competition_overrides.json` 在 P2 必须同步迁移：

| competition ID | template key | 旧 phase key | 新 phase key |
|---|---|---|---|
| `comp_icpc` | `icpc_trio` | `team_formation` | `team_formation`（不变） |
| `comp_icpc` | `icpc_train` | `proposal_writing` | `skill_training` |
| `comp_icpc` | `icpc_mock` | `proposal_writing` | `mock_event` |
| `comp_lanqiao` | `lanqiao_past` | `proposal_writing` | `skill_training` |
| `comp_lanqiao` | `lanqiao_template` | `proposal_writing` | `final_check` |

类别模板和赛事覆盖项仍按稳定 phase key 叠加。运行时 release 兜底仍会忽略未知 phase key 并记录诊断日志，但仓库测试必须验证：每个已知 competition override 的 phase key 都属于该赛事默认时间类型的合法骨架；任何被忽略的已打包 override 都使测试失败，不能静默发布。

2.4 中旧计划统一映射为 `submission` 只是为了无损保留既有阶段与日期，不代表该赛事的新计划分类。已迁移的 ICPC/蓝桥杯计划继续按旧数据展示；用户新建计划时使用上述 `eventWindow` 默认值。旧计划如需切换时间模型，走显式「按新时间模型重建计划」流程，不在迁移时自动改写或丢弃任务。

AI 只能收到最终筛选后的 `phaseKeys`。

确定性排期规则：

- 窗口型：所有阶段和任务落在 `[calendarToday, targetDate]`；`eventEndDate` 只用于展示赛事窗口，不能把任何备赛任务的最晚日期延长到 `targetDate` 之后。
- 提交型提交前阶段：落在 `[calendarToday, targetDate]`。
- 提交型答辩阶段：仅 `defense_prep` 落在 `[targetDate + 1 天, defenseDate]`。
- 无 `defenseDate` 时不生成 `defense_prep`，也不生成答辩必做任务。
- 每个区间分别调用 scheduler；阶段过多时只在该区间内按既有规则合并。
- `overload` 在提交前区间和答辩区间分别计算；任一区间必做工时超过对应周投入预算时，计划级 `overload` 为 true。
- AI 个性化任务没有自行指定日期的权力，由客户端设置为所属阶段的 `endDate`。

### 2.4 旧计划兼容迁移

新增 `competition_preparation_plans.v2`，首次读取时执行一次性迁移：

1. 若 v2 已存在，直接读取 v2。
2. 若 v2 不存在，读取 v1 并逐条使用旧 schema 解码。
3. 旧计划映射为 `timelineType=submission`、`eventEndDate=null`、`defenseDate=null`、`revision=0`，保留原有阶段、任务及日期，不触发自动重排。
4. 所有可解码条目成功写入 v2 后才标记迁移完成；v1 保留，不主动删除，便于回滚。
5. 单条损坏数据可忽略，但必须保留其他合法计划并记录可诊断日志。

`PreparationPlan.fromJson` 仍应对缺失的新字段提供上述 legacy 默认值，避免测试或导入路径绕过仓库迁移时丢数据。

### 2.5 水平画像

```dart
enum DiagnosisSelectionSource { aiAccepted, manualOverride }

class LevelDiagnosis {
  final String categoryKey;                 // 规范化类目 key
  final ExperienceLevel diagnosedLevel;    // AI 原始判断
  final ExperienceLevel effectiveLevel;    // 用户最终确认的档位
  final DiagnosisSelectionSource source;
  final String rationale;
  final String? suggestion;
  final DateTime diagnosedAt;
  final Map<String, String> answers;
}
```

新增 `LevelDiagnosisStore`：

- SharedPreferences key：`level_diagnosis.v1`。
- 存储结构：`Map<categoryKey, LevelDiagnosis>`。
- AI 返回后只展示诊断结果；用户接受或手动改档后，才保存最终画像。
- 后续计划使用 `effectiveLevel`，并允许「重新诊断」覆盖。
- 新增唯一的 `CompetitionCategoryNormalizer`，统一目录、模板和画像类目别名，例如 `电子信息类 → 电子与信息类`、`创新创业类 → 综合与创业类`。

### 2.6 改动卡和助手轮次

AI 输出使用专用草稿 DTO，不直接反序列化为完整 `PreparationTask`：

```dart
enum ChangeCardType {
  moveTask,
  addTask,
  deleteTask,
  reschedulePhase,
  appendAdvice,
}

enum ChangeCardStatus { pending, rejected, applied, declined, stale }

class NewTaskDraft {
  final String title;
  final int estimatedHours;
  final DateTime dueDate;
  final String? note;
}

class PhaseScheduleDraft {
  final String phaseKey;
  final DateTime startDate;
  final DateTime endDate;
}

class PlanChangeCard {
  final String id;
  final ChangeCardType type;
  final String? targetTaskId;
  final String? targetPhaseKey;
  final DateTime? newDate;
  final NewTaskDraft? newTask;
  final List<PhaseScheduleDraft>? phaseSchedule;
  final String? adviceText;
  final String summary;
  final String rationale;
  final ChangeCardStatus status;
  final String? rejectionCode;
  final String? rejectionReason;
}

class PlanChangeSet {
  final String id;
  final int basePlanRevision;
  final List<PlanChangeCard> cards;
}
```

各类型必填字段：

| 类型 | 必填字段 | 应用语义 |
|---|---|---|
| `moveTask` | `targetTaskId`, `newDate` | 只改目标任务的 `dueDate` |
| `addTask` | `targetPhaseKey`, `newTask` | 客户端生成唯一 ID，强制 `kind=userAdded` |
| `deleteTask` | `targetTaskId` | 仅允许 `optional` 或 `userAdded` |
| `reschedulePhase` | `phaseSchedule` | 一张卡原子更新列表中明确列出的阶段边界及这些阶段的未完成任务日期 |
| `appendAdvice` | `adviceText`，`targetPhaseKey` 可空 | 有 phase key 时追加阶段建议，否则追加全局建议；以换行分隔，不覆盖原文 |

服务端在解析 LLM 原始结果后执行校验。合法卡返回 `pending`；非法卡仍可返回给前端，但必须标为 `rejected` 并带稳定 `rejectionCode` 和中文原因，接受按钮禁用。

助手历史使用独立 store，不复用导师聊天历史：

- SharedPreferences key：`preparation_assistant_history.v1`。
- 存储结构：`Map<planId, List<AssistantTurn>>`。
- 每个 turn 保存用户消息、AI reply、`PlanChangeSet` 及每张卡的最终状态。
- 每个计划最多保留最近 20 轮；发送给模型时最多取最近 10 轮，并优先保留卡片最终状态而非完整旧快照。
- 收起或重新打开抽屉后历史仍存在；删除计划时同步删除对应助手历史。

展示层复用现有 `ChatMessageBubble`，但不让 preparation domain/store 依赖 `ChatMessage`：

- 新增 UI-only `AssistantTurnMessageMapper`，把一个 `AssistantTurn` 映射为临时 user/assistant `ChatMessage`，再交给 `ChatMessageBubble` 渲染。
- 临时消息 ID 由 `planId + turnId + role` 确定性生成；role、content 和错误/完成状态从 turn 映射，recommendations 为空。
- 改动卡继续由助手抽屉在 AI 消息下方单独渲染，不塞入 `ChatMessage.relatedRecommendations`。
- 映射出的 `ChatMessage` 不持久化，也不写入 `ChatHistoryStore`；P4 不泛化 `ChatMessageBubble` 的领域参数，控制改动范围。

---

## 3. 实现接口与数据源矩阵

### 3.1 领域接口

在现有 `PreparationPersonalizer` 之外新增：

```dart
abstract interface class PreparationLevelDiagnoser {
  Future<Result<LevelDiagnosisSuggestion>> diagnose(
    LevelDiagnosisRequest request,
  );
}

abstract interface class PreparationPlanAssistant {
  Future<Result<AssistantReply>> suggestChanges(
    PlanAssistantRequest request,
  );
}
```

Provider 按现有 `DataSource` 切换：

| 能力 | `DataSource.llm` | `DataSource.http` | Fake backend |
|---|---|---|---|
| 生成个性化 | `AiPreparationPersonalizer` | `HttpPreparationPersonalizer` | generate handler |
| 水平诊断 | `AiPreparationLevelDiagnoser` | `HttpPreparationLevelDiagnoser` | diagnose handler |
| 调整建议 | `AiPreparationPlanAssistant` | `HttpPreparationPlanAssistant` | assistant handler |

Fake backend 是注入 Dio 的 HTTP 测试/离线演示 transport，不新增第三种 `DataSource`。直接 LLM 与 HTTP 实现共用同一套 DTO 校验器和改动卡 validator。

### 3.2 水平诊断 `POST /api/v1/preparation-plans/diagnose`

Request：

```json
{
  "competition": { "id": "...", "name": "...", "category": "计算机类", "rules_summary": {} },
  "profile": {},
  "answers": [
    {"question_key": "prior_experience", "answer": "拿过校级以上奖"},
    {"question_key": "domain_familiarity", "answer": "熟悉"}
  ]
}
```

Response data：

```json
{
  "level": "intermediate",
  "rationale": "根据你的参赛经历和算法熟悉度，你已具备进阶基础。",
  "suggestion": "建议按进阶档排期；时间充裕时可增加老手档训练。"
}
```

`level` 仅是 AI 建议。前端必须等待用户接受或手动覆盖后，才把 `diagnosedLevel` 和 `effectiveLevel` 写入 `LevelDiagnosisStore`。

### 3.3 生成个性化 `POST /api/v1/preparation-plans/generate`

该端点仍只返回可选任务和建议，不返回完整计划、不负责最终日期排期。请求在现有字段上新增：

```json
{
  "competition": {},
  "calendar_today": "2026-05-01",
  "target_date": "2026-05-30",
  "timeline_type": "submission",
  "event_end_date": null,
  "defense_date": "2026-06-10",
  "weekly_commitment": "hours6to10",
  "experience_level": "intermediate",
  "phase_keys": ["team_formation", "topic_selection", "proposal_writing", "submission_polish", "defense_prep"],
  "user_profile": {}
}
```

Response data 保持现有结构：

```json
{
  "phases": [
    {
      "key": "proposal_writing",
      "optional_tasks": [
        {"template_key": "ai_benchmark", "title": "补充验证实验", "estimated_hours": 4}
      ],
      "personalized_advice": "先完成核心链路，再补充对比实验。"
    }
  ],
  "global_advice": "提交前优先保证作品完整可运行。"
}
```

客户端仅接受 `phase_keys` 白名单内的结果，并在模板生成器中确定性合并和排期。

### 3.4 AI 助手 `POST /api/v1/preparation-plans/{id}/assistant`

Request：

```json
{
  "calendar_today": "2026-05-01",
  "base_plan_revision": 3,
  "plan_snapshot": {
    "id": "pp_1",
    "revision": 3,
    "competition": {},
    "target_date": "2026-05-30",
    "timeline_type": "submission",
    "event_end_date": null,
    "defense_date": "2026-06-10",
    "phases": [
      {
        "key": "proposal_writing",
        "start_date": "2026-05-10",
        "end_date": "2026-05-22",
        "tasks": [
          {
            "id": "task_core_algo",
            "title": "核心算法实现",
            "kind": "required",
            "estimated_hours": 16,
            "completed_at": null,
            "due_date": "2026-05-15"
          }
        ]
      }
    ]
  },
  "user_message": "这周期末考没空，往后挪；答辩前留个模拟答辩",
  "history": [
    {
      "role": "assistant",
      "content": "上一轮回复",
      "card_results": [{"card_id": "cc_0", "status": "applied"}]
    }
  ]
}
```

Response data：

```json
{
  "reply": "我整理了两项可单独确认的调整。",
  "change_set": {
    "id": "cs_1",
    "base_plan_revision": 3,
    "cards": [
      {
        "id": "cc_1",
        "type": "move_task",
        "target_task_id": "task_core_algo",
        "new_date": "2026-05-22",
        "summary": "把【核心算法实现】移到 5 月 22 日",
        "rationale": "避开期末考试周，同时仍早于提交 DDL。",
        "status": "pending"
      },
      {
        "id": "cc_2",
        "type": "add_task",
        "target_phase_key": "defense_prep",
        "new_task": {
          "title": "第二次模拟答辩",
          "estimated_hours": 3,
          "due_date": "2026-06-05",
          "note": "记录评委追问"
        },
        "summary": "答辩准备阶段新增一次模拟答辩",
        "rationale": "在正式答辩前预留复盘时间。",
        "status": "pending"
      }
    ]
  }
}
```

路径中的 `{id}` 必须与 `plan_snapshot.id` 一致；计划仍是本地数据，快照是服务端推理和校验的唯一事实来源。

### 3.5 改动卡安全校验

前端、直接 LLM validator 和 HTTP 后端使用同一规则；HTTP 后端为最终响应的权威校验层，客户端在应用前仍必须重新校验：

- response 最多包含 5 张卡；LLM 原始结果超量时只校验并保留前 5 张，其余丢弃并记录调试信息。
- `targetTaskId`、`targetPhaseKey` 和 `phaseSchedule.phaseKey` 必须存在于快照。
- `deleteTask` 只能删除 `optional` 或 `userAdded`；必做任务返回 `required_task_delete_forbidden`。
- `addTask` 的标题非空，`estimatedHours` 为 1–200 的整数；客户端强制创建为 `userAdded`。
- 窗口型所有可修改任务日期必须位于 `[calendarToday, targetDate]`。
- 提交型非 `defense_prep` 任务必须位于 `[calendarToday, targetDate]`。
- 提交型 `defense_prep` 任务必须位于 `[targetDate + 1 天, defenseDate]`；无 `defenseDate` 时该阶段和相关卡片均非法。
- 已完成任务不可由 AI 移动或删除；用户仍可通过手工编辑查看历史日期。
- `phaseSchedule` 只列出本卡明确要重设边界的阶段，未列出的阶段保持原边界。validator 先把草稿合并到完整计划，再对完整阶段列表检查顺序、日期范围和任意阶段间重叠；若与未列出的相邻阶段冲突，整张卡拒绝，validator 不自动移动或补入相邻阶段。若需要协调调整多个阶段，AI 必须把每个要改边界的阶段都列入同一张卡。阶段之间允许留空档，但不允许重叠或顺序反转。
- `summary` 和 `rationale` 仅用于展示，不能作为定位任务或执行操作的依据。
- JSON 解析失败时整次调用为 `Result.failure`，不得写计划。

### 3.6 原子应用、版本检查与幂等

`PreparationPlanRepository.save` 扩展为 compare-and-set 语义：新计划仅允许在 ID 不存在且 `revision == 0` 时创建；更新计划必须传 `expectedRevision`。仓库内部用单一 Future 写队列串行化所有计划变更，在真正写 SharedPreferences 前再次读取并比较 revision；冲突返回明确的 `Result.failure(ConflictException)`，不得覆盖较新的计划。

新增 `PlanChangeApplier` 领域服务。repository 每次成功更新必须把 `revision` 原子递增 1。助手 controller 持有当前 change set 的 `expectedRevision`，初始值为 `basePlanRevision`：

1. 用户点击接受时重新从 repository 读取最新计划。
2. 若计划 `revision != expectedRevision`，说明发生了手工编辑或其他写入：将该 change set 所有剩余 `pending` 卡标为 `stale`，不得应用。
3. 若版本一致，再按 3.5 对当前计划重新校验该卡。
4. 按卡片类型生成新的不可变计划并执行一次带 `expectedRevision` 的 repository `save`。
5. 保存成功后把卡标为 `applied`，把返回计划的 `revision` 更新为下一张卡的 `expectedRevision`。
6. 同一 `changeSetId + cardId` 已是 `applied` 时直接返回既有结果，不重复创建任务或追加建议。
7. 用户拒绝时标为 `declined` 并保留在历史中，不从数据模型删除；UI 可折叠已处理卡。
8. 保存失败时卡保持 `pending` 并显示错误，不得先改 UI 中的计划快照。

`reschedulePhase` 应用时保留已完成任务的历史 dueDate；未完成任务按新阶段边界 clamp。任何单卡要么全部保存成功，要么不产生计划变更。

### 3.7 OpenAPI 和文档

同步更新：

- `docs/openapi.yaml`
- `docs/api-contract.md`
- `lib/data/mock/fake_backend.dart` 注册表

三个端点均使用 API envelope。所有枚举、分类型必填字段、nullable 字段、`maxItems: 5`、日期 `format: date`、审计时间 `format: date-time` 和 rejection code 都必须进入 OpenAPI schema。

---

## 4. UI 交互流程

### 4.1 水平诊断向导

```text
开始备赛
  → Step 1 选择时间模型和日期
      窗口型：选择比赛开始/结束日期
      提交型：选择提交 DDL，可选答辩日期
  → Step 2 水平诊断（无该规范类目画像时出现）
      Q1 参赛经历：从没 / 参加过未获奖 / 获得校级以上奖
      Q2 领域熟悉度：不熟 / 一般 / 熟悉
      → 调 diagnose
      → 展示 AI 档位、理由和建议
      → 用户接受，或手动覆盖三档
      → 确认后保存 diagnosedLevel + effectiveLevel
  → Step 3 每周投入
  → 生成计划
```

已有画像时跳过问答，但展示「已按你的 X 类画像：进阶排期」，并提供「重新诊断」和「本次临时改档」。临时改档只影响本计划，不覆盖 store；重新诊断确认后才覆盖 store。

诊断失败时显示 P0 错误态，同时允许用户直接手动选择档位继续，不阻断离线流程。

### 4.2 日期选择器

自建 `PreparationDatePicker` 支持：

- 单日模式：单个 DDL 或普通任务日期。
- 区间模式：窗口型比赛开始/结束日期。
- 多锚点模式：提交 DDL + 可选答辩日期。

组件只返回规范化日历日期，不包含时分秒。无效顺序在组件内即时提示，提交按钮禁用；最终领域层仍重复校验。

### 4.3 备赛详情页

保留现有详情页骨架，新增：

- 倒计时下方的锚点条：窗口型显示「比赛 5/20–5/22」；提交型显示「提交 DDL 5/30 · 答辩 6/10」。
- 提交型有答辩时，阶段时间轴在 DDL 后单独展示答辩准备段；不把它压回提交前区间。
- 右下角「AI 助手」按钮打开底部抽屉。
- 抽屉关闭后计划页保留，重新打开时恢复该计划的助手历史。

### 4.4 AI 助手和改动卡

```text
用户发送调整诉求
  → controller 读取最新计划并固定 basePlanRevision
  → 调 assistant
  → 展示 AI 全宽回复 + 最多 5 张横滑改动卡
  → pending：接受 / 拒绝
  → rejected：展示拒绝原因，无接受按钮
  → applied / declined：折叠显示最终状态
  → stale：提示“计划已变化，请重新生成建议”
```

每张卡必须显示操作对象、变更前后值、理由和状态。接受按钮在保存期间禁用，防止重复点击。

### 4.5 手工编辑语义

手工任务增删改继续保留，并与 AI 使用相同的日期范围 validator：

- 普通阶段任务最大日期为 `targetDate`。
- `defense_prep` 任务范围为 `targetDate + 1 天` 到 `defenseDate`。
- 窗口型修改 `targetDate` 只重排未完成赛前阶段；若新开始日晚于 `eventEndDate`，要求用户同时调整结束日。
- 修改 `eventEndDate` 只更新赛事窗口展示，不重排备赛任务。
- 提交型修改 `targetDate` 只重排提交前阶段；若与现有 `defenseDate` 冲突，必须先调整或清除答辩日。
- 修改 `defenseDate` 只重排 `defense_prep`。没有已完成答辩任务时，可二次确认后清除答辩日并移除整个答辩阶段；已有完成任务时禁止清除答辩日，只允许改为仍覆盖这些历史日期的合法日期。
- 已完成任务保留原 dueDate 和 completedAt，即使锚点缩短后落在新区间外。

任何手工保存都会递增 `revision` 并更新 `updatedAt`，使基于旧快照的 pending change set 变为 stale。

### 4.6 P0 聊天气泡与错误态

- 用户消息：右侧有色气泡，最大宽度保持现有规则。
- AI 正常回复：左侧全宽、透明背景、无圆角容器，Markdown 可选择。
- AI 回复正文统一使用可测试的行高常量。
- AI 推荐卡和改动卡位于回复正文下方，不放入气泡。
- 错误态：圆圈红色感叹号 + 简短错误文案 +「查看详情」+「重试」。详情默认折叠，不直接展示敏感请求内容或 API key。
- streaming、复制、重新生成、反馈和无障碍语义不得因去气泡退化。

---

## 5. AI 提示词

### 5.1 水平诊断

```text
你是 SchoNavi 的备赛水平诊断助手。根据竞赛类目、用户档案和两个问答答案，
判断用户在该类赛事上的经验等级，并给出简短、可解释的理由与排期建议。

规则：
1. level 仅限 beginner|intermediate|experienced。
2. rationale 用中文 1–2 句，只引用输入中存在的事实。
3. suggestion 给出与档位对应的排期建议。
4. 不得声称用户获得过输入中未提供的奖项。
5. 仅输出 JSON：{"level":"...","rationale":"...","suggestion":"..."}
```

`jsonMode: true`，`temperature: 0.2`。

### 5.2 生成个性化

在现有 `AiPreparationPersonalizer` 提示词上新增：

- 输入 `calendar_today`、`timeline_type`、三个日期锚点和最终 `phase_keys`。
- 只能返回 `phase_keys` 中阶段的可选任务和建议。
- 不返回阶段日期、任务 dueDate 或必做任务删除建议。
- 有诊断画像时注明 `effectiveLevel`；AI 理由只作为上下文，不允许改变最终档位。
- `defense_prep` 只会在客户端确认存在答辩日期后出现在 phase key 白名单。

`jsonMode: true`，`temperature: 0.3`。

### 5.3 AI 助手调整建议

```text
你是 SchoNavi 的备赛日历助手。根据计划快照、用户消息和最近历史，
输出自然语言回复和最多 5 张结构化改动卡。

规则：
1. 类型仅限 move_task|add_task|delete_task|reschedule_phase|append_advice。
2. 只能引用快照中存在的 task_id 和 phase_key。
3. 必做任务、已完成任务不可删除；已完成任务不可移动。
4. 新增任务只输出 NewTaskDraft，不输出 id 或 kind。
5. 日期必须符合时间类型和阶段的合法区间。
6. reschedule_phase 必须给出受影响阶段的完整 phase_schedule。
7. 不确定如何安全修改时使用 append_advice，或返回空 cards，不要猜测。
8. summary 描述改什么，rationale 解释为什么。
9. 仅输出 JSON，不输出 Markdown 代码块。
```

`jsonMode: true`，`temperature: 0.3`。LLM 原始输出必须经过共享 validator 后才能成为接口 response。

---

## 6. 测试策略

### P0

- AI 正常回复无气泡、用户回复有气泡。
- streaming、Markdown、推荐卡、消息操作和错误态布局。
- 行高常量、44px 触控目标、大字体和语义标签。

### P1

- 单日、区间、多锚点选择。
- 日期顺序、边界、取消和规范化到本地零点。
- JSON `YYYY-MM-DD` 往返，不接受混用 date-time。

### P2

- v1 → v2 多计划迁移、单条损坏降级、迁移幂等和 v1 保留。
- 窗口型只加载窗口模板，不生成提交/答辩阶段。
- `comp_icpc`、`comp_lanqiao` 默认归为窗口型，override 迁移后所有任务落入预期 phase；已打包 override 无未知 key。
- 提交型无答辩时不生成 `defense_prep`。
- 有答辩时提交前与答辩段分别排期、预算和 overload。
- 修改三个锚点时只重排对应区间；已完成任务日期保持。

### P3

- `LevelDiagnosisStore` 增删改查和损坏数据降级。
- 类目别名规范化后复用同一画像。
- AI 接受、手动覆盖、本次临时改档和重新诊断的持久化语义。
- diagnose 的 AI、HTTP、Fake 三条路径及 DTO 校验。

### P4

- 五类卡的严格字段校验和 DTO 往返。
- 必做/已完成任务保护、阶段专属日期范围、最多 5 卡。
- rejected 卡理由、pending 接受、declined、applied、stale 状态。
- 多卡顺序应用时 expectedRevision 更新正确。
- 外部手工编辑导致剩余卡 stale。
- repository 写队列和 compare-and-set 能阻止两个并发保存互相覆盖。
- 重复接受同一卡幂等；`addTask` 不产生重复任务，`appendAdvice` 不重复追加。
- repository 保存失败时计划与卡状态均不提前提交。
- 助手历史按计划隔离、关闭重开恢复、20 轮截断和删除计划联动清理。
- `AssistantTurnMessageMapper` 的稳定 ID、role/content/status 映射正确，临时 `ChatMessage` 不进入通用聊天 store。
- assistant 的 AI、HTTP、Fake 三条路径使用同一 validator。

### 综合验证

- 运行相关 targeted `flutter test`，再运行 `flutter analyze` 和全量 `flutter test`。
- 真机或模拟器验证窗口型、无答辩提交型、有答辩提交型三条 golden path。
- 验证浅色/深色、375px 宽度、大字体、键盘遮挡和抽屉恢复。

---

## 7. 实现分期

1. **P0 聊天气泡拆分**：调整现有组件并补齐错误态、回归测试。
2. **P1 日期基础设施**：日历日期 codec、validator 和三模式日期选择器。
3. **P2 双段时间模型**：默认类型配置、ICPC/蓝桥杯 override 迁移、v2 计划迁移、按类型模板、分段 scheduler、详情页锚点和手工编辑适配。
4. **P3 水平诊断**：规范类目、store、AI/HTTP/Fake diagnoser 和向导确认流程。
5. **P4a 助手只读建议**：AI/HTTP/Fake assistant、共享 validator、历史 store 和卡片 UI，暂不开放接受。
6. **P4b 原子应用**：`PlanChangeApplier`、版本检查、幂等、五类操作和完整交互。
7. **契约收口**：同步 OpenAPI/API 文档，跑全量测试并完成三种时间场景的人工验证。

每期必须独立可验证。P4a 与 P4b 分开交付，避免在结构化输出和安全校验未稳定前开放计划写入。
