# SchoNavi 设计 · 个人档案 → 个性化推荐（结构化 + AI 抽取 + 档案注入）

- 版本：v2（2026-06-11；v1→v2：去除"假分析"实现、明确数据/分析分层、新增真实后端 API 设计）
- 关系：建立在 **M1–M5 + Bento Phase 0/1/2（均已实现并 commit）** 之上。这是**用户三个新故事**收敛后的聚焦立项：
  - 故事①（可维护性 / 原子化组件）：把 profile 功能做成 **atoms→molecules→organisms→pages 样板**，并顺手清理 home/email 的 profile 重复；其余页面原子化按需逐步，不在本轮强推。
  - 故事②（UI 精致度 / 交互体验）：复用 Bento 系统（`core/haptics`、`AnimatedEntrance`、`BentoTile`），档案流做到"真 App"质感。
  - 故事③（个人信息 → 更准推荐）：**本 spec 主线与优先项**。
- 直击参赛短板：当前推荐主链路 `getRecommendations({required String prompt})` **完全不读 `UserProfile`**。把完整背景接入推荐，是「大模型应用能力」最直接的增益（见 `schonavi-aigc-competition-rubric`）。
- 前置：DeepSeek key 冒烟 `flutter run --dart-define=LLM_API_KEY=...`；**导师事实数据始终来自本地库**（`MockDb`），AI 仅负责"智能"。
- 开发约定：沿用既有分层 + Riverpod 3.2.1 手写 provider + Result/sealed + TDD（见 `schonavi-dev-conventions`）。

---

## 1. 目标与策略

让用户用**完整、结构化的个人背景**换取**更精准、可感知"懂我"的导师推荐**，同时把这块新功能做成代码原子化与 UI 精致度的样板。

**关键决策（brainstorm 产出）**

| # | 决策 | 选择 |
|---|---|---|
| 1 | 录入 / 解析模型 | **混合**：关键字段结构化录入；竞赛/科研等"成果"自由文本 → **LLM 抽取成可编辑条目**，用户确认后入库（亦可手动增删，不硬依赖 AI） |
| 2 | 推荐如何变准 | **基线注入**：推荐时把"完整档案 + 查询"一起喂 LLM，背景影响排序与理由。本轮不做证据链/定位画像 |
| 3 | 界面结构 | **首填向导(B) → 档案中心(C)**：新用户走分步向导，完成即落到 `/profile` 中心；之后查看/编辑都在中心 |
| 4 | 向导触发时机 | **即时触发**：首页/推荐照常可用；首次发起推荐或点"我的档案"时弹引导进向导（可跳过），与开屏引导解耦 |

**数据 vs 分析（v2 明确，贯穿全文）**
- **数据类**（事实）：导师库、用户档案存取。导师来自本地 `MockDb`（real AI ≠ real backend，无后端时事实只能本地）；档案本地存储。真实后端到位 → 切 `DataSource.http`。
- **分析/生成类**（智能）：推荐排序与理由、成果抽取（及既有匹配/对比/对话/套磁）。**恒为真实 AI**，不做"假分析"实现（本轮新功能严格如此；既有分析仓储的 mock 分支待 §15 清退）。真实后端到位 → 切 HTTP（后端代执行 LLM）。
- 自动化测试用**假 `LlmClient`**（喂固定 JSON，沿用现有 `_FakeLlm` 模式）保证离线、确定、零成本——无需"假分析仓储"。

---

## 2. 范围

**In**
- `UserProfile` 结构化扩展（性别、目标阶段、成绩、竞赛、科研）。
- AI 成果抽取仓储（自由文本 → 结构化条目，**仅 AI 实现**）。
- 推荐注入（`getRecommendations` 加性 `profile` 参数 + 响应式 `profileProvider`）。
- 首填向导(B) + 档案中心(C) + 即时触发 sheet + 入口。
- 隐私透明（本地存储声明 + AI 发送声明 + 清除）。
- profile 功能原子化样板 + 合并 home/email 现有 profile 重复 UI。
- **真实后端数据源设计（§10）**——设计先行，实现留 V1.0。

**Out / 非目标**
- 可解释证据链 / 申请定位画像 / 套磁预演（原 Bento Phase 3/4/5）——日后并入既有 spec。
- 后端 / 账号 / profile 云同步的**实现**——`DataSource.http` 仍抛 `UnimplementedError`（仅设计）。
- 清退既有"假分析"仓储（`MockRecommendationRepository`/`MockMatchAnalysisRepository`/`MockComparisonRepository`/`MockChatRepository`/`MockOutreachEmailRepository`）——独立小清理，见 §15，不在本轮（避免在 profile spec 里动既有 di/测试）。
- 全 App 原子化重构、深色模式精修、语音输入。
- 录取概率预测——延续既有非目标，仅信息性。

---

## 3. 数据模型（全部加性，旧档案照常加载）

`domain/entities/`，"一实体一文件"：扩展 `user_profile.dart`，新增 `academic_score.dart` / `competition.dart` / `research_item.dart`。`Gender` 与 `UserProfile` 同文件，`ResearchType` 与 `ResearchItem` 同文件。

```dart
class UserProfile {
  // 既有
  final String? name;
  final String? degreeStage;          // 当前阶段：本科在读 / 硕士在读 / 已毕业…
  final String? school;
  final String? major;
  final List<String> researchInterests;
  final String? highlights;            // 保留：自由补充文本

  // 新增 · 结构化（向导手填）
  final Gender? gender;                // 男 / 女 / 其他 / 不愿透露
  final String? targetDegree;          // 目标阶段：申请硕士 / 申请博士
  final AcademicScore? score;          // GPA + 量纲 + 排名

  // 新增 · 成果条目（AI 抽取或手填，可编辑）
  final List<Competition> competitions;
  final List<ResearchItem> research;
}

enum Gender { male, female, other, undisclosed }   // UI：男/女/其他/不愿透露

class AcademicScore {                  // academic_score.dart
  final double? gpa;                   // 例 3.8
  final double? scale;                 // 量纲：4.0 / 4.3 / 4.5 / 5.0 / 100
  final String? rank;                  // 自由文本，例 "前 5%"、"3/120"
}

class Competition {                    // competition.dart
  final String name;                   // 例 "ACM-ICPC 区域赛"
  final String? level;                 // 国际 / 国家级 / 省级 / 校级
  final String? award;                 // 例 "银牌"、"一等奖"
  final String? year;                  // 自由文本，例 "2024"
}

enum ResearchType { paper, project, patent, other }   // research_item.dart

class ResearchItem {                   // research_item.dart
  final ResearchType type;
  final String title;
  final String? role;                  // 例 "第一作者"、"项目负责人"
  final String? venueOrStatus;         // 例 "EI 会议 / 已发表 / 在投"
  final String? year;
}
```

**完成度计算**（中心页进度环，去歧义）：以下 7 项各计权重，命中即得分，完成度 = 命中数 / 7：
1. `name` 非空　2. `gender != null`　3. `school` 与 `major` 均非空　4. `targetDegree` 非空　5. `score?.gpa != null`　6. `researchInterests.isNotEmpty`　7. `competitions.isNotEmpty || research.isNotEmpty`

`isEmpty` 扩展为：上述全部未命中。缺失字段一律显示「暂无信息」，绝不渲染 null。

---

## 4. AI 成果抽取（仅 AI 实现）

```dart
// domain/repositories/profile_extraction_repository.dart
abstract interface class ProfileExtractionRepository {
  Future<Result<AchievementDraft>> extract({required String rawText});
}
class AchievementDraft {
  final List<Competition> competitions;
  final List<ResearchItem> research;
}
```

- **`AiProfileExtractionRepository(llm)`**：`llm.complete(jsonMode:true, temperature:0.2)`。系统提示词：仅依据用户输入抽取，**不编造未提及的奖项/论文**；`level/award/type` 归一到枚举/常见取值，拿不准留空；缺字段给空串/`other`；输出单一 JSON。坏 JSON → `Failure(ServerException())`，逐条字段缺省兜底。
- **无 `Mock` 实现**（属"分析类"）。`DataSource.http` 到位后新增 `HttpProfileExtractionRepository`（后端代执行，§10）。
- **降级**：无 key / 非 AI 时，`AchievementsEditor` 的「AI 整理」按钮禁用并提示，用户仍可**手动增删**竞赛/科研条目——结构化数据不硬依赖 AI。
- **测试**：用 `_FakeLlm` 喂固定抽取 JSON / 坏 JSON / `Failure` 测解析（沿用现有模式），离线确定。

---

## 5. 推荐注入（基线层）

```dart
// domain/repositories/recommendation_repository.dart —— 加性可选参数
Future<Result<RecommendationResult>> getRecommendations({
  required String prompt,
  UserProfile? profile,        // 新增
  String? sessionId,
});
```

- **`AiRecommendationRepository`**：候选导师仍来自 `ProfessorCandidateSource`（本地 `MockDb`，**事实接地不变**）；在 user 消息追加「学生档案」紧凑 JSON 段；系统提示词增规则：**结合背景排序，`reason` 适当引用背景**（如"你有 ACM 区域赛银牌，与 TA 算法方向契合"），但**只引用候选导师事实、不编造**。`profile == null || profile.isEmpty` → 不追加该段，行为与现状完全一致（**加性安全**）。
- **`MockRecommendationRepository`**（既有）：仅为满足接口签名加 `UserProfile? profile` 形参并忽略；本 spec 不为其加逻辑（它属待清退的"假分析"，见 §15）。
- **响应式 `profileProvider`**（新增于 `features/profile/providers/profile_provider.dart`，feature 状态）：
  ```dart
  final profileProvider = NotifierProvider<ProfileController, UserProfile>(ProfileController.new);
  class ProfileController extends Notifier<UserProfile> {
    UserProfile build() => ref.read(profileRepositoryProvider).load();   // 初值
    Future<void> save(UserProfile p) async { state = p; await ref.read(profileRepositoryProvider).save(p); }
    // 便捷 update：copyWith 局部字段后 save
  }
  ```
- **`recommendationProvider`** 读取并依赖档案：
  ```dart
  final recommendationProvider = FutureProvider.family<RecommendationResult, String>((ref, prompt) async {
    final profile = ref.watch(profileProvider);              // 档案变更 → 自动失效重算
    final repo = ref.watch(recommendationRepositoryProvider);
    final result = await repo.getRecommendations(prompt: prompt, profile: profile);
    return switch (result) { Success(:final data) => data, Failure(:final error) => throw error };
  });
  ```

---

## 6. 界面与交互

### 6.1 流程接线
- **入口**：首页 `AppBar` 加「我的档案」图标（设置旁）；设置页加一行「我的背景档案」。均导航 `/profile`。
- **即时触发**：`home_page._submit()` 跳 `/recommendation` 前判断：`profileProvider` 为空 **且** 未记 `profile_prompt_dismissed` flag → 弹 `ProfilePromptSheet`（拖拽手柄）。「去完善」→ `/profile/wizard`；「先跳过」→ 写 `profile_prompt_dismissed=true`（localStore）后照常推荐。点「我的档案」时若空也进向导。
- **统一档案**：套磁页旧 `showProfileSheet`（6 字段 sheet）**并入**新档案流——`email_page`/`match_page` 改读 `profileProvider`；旧 `profile_sheet.dart` 删除或改薄跳转 `/profile`。完善一次，三处受益。
- **路由**（`app_router.dart`）：新增 `/profile`（中心）、`/profile/wizard`（首填），用 `sharedAxisPage`。开屏 `seenOnboarding` redirect 不动。

### 6.2 首填向导(B)
3 步，`WizardScaffold`（头 + `StepDots` + 滚动体 + 底部 sticky「上一步/下一步」条）承载：
- **① 基本信息**：姓名、性别(`ChoiceChipGroup`)、学校、专业、当前阶段、目标阶段。
- **② 成绩 & 方向**：`GpaField`（GPA 值 + 量纲 chips + 排名）、研究兴趣(`FieldChips` 追加)。
- **③ 成果**：自由文本框 →「✨ AI 整理成条目」(AI 模式可用) →/或 手动添加 → `AchievementsEditor` 列出竞赛/科研条目，逐条编辑/删除 →「完成」。

**渐进保存（去歧义）**：每次「下一步」即把该步字段经 `profileProvider.save` 落盘；③ 条目在「完成」时持久化（抽取条目默认纳入，删除即移除）。中途退出 App 不丢已填内容；首填完成后导航替换到 `/profile`。

### 6.3 档案中心(C) — `/profile`
- `ProfileSummaryHeader`：`CompletionRing`（0→N% 滚动动画）+「越完整 · 推荐越准」+「用我的档案推荐」CTA。
- `ProfileSectionTile` 列表：基本信息 ✓ / 成绩 ✓ / 研究兴趣 N 个 / 竞赛 N 项 › / 科研 N 项 ›。点分区 → 底部可拖拽 sheet 内聚焦编辑（复用向导同款 organism）。
- 底部「＋ 粘贴自述，AI 帮你填」入口（复用 `AchievementsEditor`）。

### 6.4 精致度（故事②）
完成度环 0→N 滚动；AI 抽取中 `AchievementsEditor` 用 `ShimmerSkeleton` 占位；haptics：chip `selectionClick`、下一步 `lightImpact`、抽取完成 `mediumImpact`、保存 `lightImpact`；底部 sticky 操作条（拇指可达 ≥48dp）；中心页卡片 `AnimatedEntrance` 错峰入场；编辑用可拖拽底部 sheet。尊重 `MediaQuery.textScaler`、图标按钮加 `Semantics`。

---

## 7. 原子化组件架构（故事①）

atoms → molecules → organisms → pages。每个 organism 用构造参数 + 回调通信、可独立 widget 测、可被向导与中心复用。

```
atoms（shared/widgets，全局复用）
  既有: BentoTile · StatTile · FieldChips · SectionHeader · ShimmerSkeleton
  新增: LabeledTextField（把 home/email 内联的 _field 提升为原子）
        ChoiceChipGroup（单选 chips：性别 / GPA量纲 / 竞赛级别 / 科研类型 通用）
        CompletionRing（带 0→N 动画的进度环，可复用到匹配分）
        StepDots（向导进度点）
molecules（features/profile/widgets）
  GpaField（GPA值 + 量纲chips + 排名）
  AchievementItemCard（单条竞赛/科研：展示 + 编辑 + 删除）
  ProfileSectionTile（中心页分区卡：标题 + 状态/摘要 + ›）
  WizardScaffold（头 + StepDots + 滚动体 + 底部 sticky 上/下步条）
organisms（自包含、可独立测）
  BasicInfoForm · ScoreAndInterestsForm
  AchievementsEditor（手动条目编辑 + 可选「AI 整理」加速 → 抽取 review）  ← AI 抽取核心
  ProfileSummaryHeader（完成度环 + CTA）
  ProfilePromptSheet（即时触发）
pages / state（features/profile/）
  ProfileWizardPage（用 WizardScaffold 串 3 个 organism）
  ProfilePage（中心：Header + ProfileSectionTile 列表 + AI补全；点分区 → 同一 organism 在 sheet 聚焦编辑）
  providers: profileProvider(NotifierProvider, 全局当前档案)
             achievementsExtractionProvider(抽取调用 AsyncValue)
```

**复用要点**：中心页编辑"基本信息"与向导第①步用**同一个 `BasicInfoForm`**——一处定义、两处复用，这是原子化的核心收益。

---

## 8. 隐私与透明（故事③的知情交换）

- **本地存储**：档案仅经 `LocalProfileRepository`（SharedPreferences，key `user_profile.v1`，加性扩展无需升 key）存本机，不上传。
- **解析即发送**：AI 模式下档案字段随推荐/抽取请求发送给大模型用于解析。向导首屏与设置页各明示一行：「资料仅保存在本机；AI 模式下会随请求发送给大模型用于解析与推荐」。
- **可清除**：设置页「清除本地资料」覆盖档案清除。
- **天然印证**：现有「讲解模式」(`showAiTrace`) 开启时，trace 中可见档案确被带入 prompt——透明度与"大模型应用能力"录屏证据兼得。

---

## 9. 架构与接线

- **分层不变**：`presentation(features/profile) → domain(entities + repo 接口) ← data(ai/local)`，横切 `core`。
- **数据 vs 分析**（v2 原则）：
  - 数据类仓储（`professorRepositoryProvider`/`professorCandidateSourceProvider`/`profileRepositoryProvider`）→ 本地，后端到位切 HTTP。
  - 分析类仓储（推荐/抽取/匹配…）→ **目标恒 AI**。本轮**新增**的 `profileExtractionRepositoryProvider` 即按此：恒返回 `AiProfileExtractionRepository`、**无 mock 分支**，`DataSource.http` 切 `HttpProfileExtractionRepository`（§10）。既有推荐/匹配等仓储**暂留** mock 分支，待 §15 清退后统一为此形态。
- **新增 provider**：`profileExtractionRepositoryProvider`（`core/di/providers.dart`）；`profileProvider`（`features/profile/providers/`）。
- **导师事实接地不变**：推荐候选始终来自本地库；AI 只排序/措辞，不造导师。
- **大模型应用模式展示**（作品说明清单）：结构化输出（抽取 jsonMode → 实体）、事实接地（不编造）、个性化生成（档案注入理由）。

---

## 10. HTTP / 真实后端数据源设计（设计先行，实现留 V1.0）

> 目的：`DataSource.http` 暂仍抛 `UnimplementedError`，但**接口契约现在定清**，使"presentation/domain 零改动切换数据源"名副其实，也为真实后端预留位置。前提：真实后端**既服务导师数据、也服务端代执行 LLM**（隐藏 key、集中提示词）。

**约定**：REST/JSON，`baseUrl` 经 `AppConfig` 注入；鉴权 `Authorization: Bearer <token>`（V1.0 账号体系）；错误体 `{code,message}` 映射到既有 `AppException` → `Failure`；解析经 `data/dto/`（已存在 DTO 边界）。

**端点契约**

| 类型 | 端点 | 请求 | 响应 |
|---|---|---|---|
| 数据·导师候选 | `GET /api/professors?query=&limit=` | — | `[{id,name,university,college,title,researchFields[],bio?,homepageUrl?}]` |
| 数据·导师详情 | `GET /api/professors/{id}` | — | 单个导师对象 |
| 数据·档案（可选云同步） | `GET /api/profile` · `PUT /api/profile` | `UserProfile` JSON | `UserProfile` JSON |
| 分析·推荐 | `POST /api/recommendations` | `{prompt, profile}` | `RecommendationResult`（后端接地自有导师库 + LLM） |
| 分析·成果抽取 | `POST /api/profile/extract-achievements` | `{rawText}` | `AchievementDraft` |
| 分析·匹配（既有功能） | `POST /api/match-analysis` | `{professorId, profile}` | `MatchAnalysis` |

**仓储映射**：`HttpProfessorRepository` / `HttpProfileRepository` / `HttpRecommendationRepository` / `HttpProfileExtractionRepository` …，各实现对应 domain 接口、命中上表端点、经 DTO 解析。客户端不再持有 LLM key（迁移到后端）。

**迁移影响**：切到 `http` 时，`core/di` 各 provider 的 `case DataSource.http` 由抛错改为返回上述 Http 实现；entities/presentation/测试结构不变（仓储抽象的回报）。本轮**只落契约文档，不写实现**。

---

## 11. 测试策略（TDD，先写测试；分析类一律假 `LlmClient`）

| 测试 | 覆盖 |
|---|---|
| `user_profile_test` | 新字段、`isEmpty`、完成度% 计算（边界） |
| `local_profile_repository_test` | 新字段序列化 + **旧 v1 JSON 向后兼容加载** |
| `ai_profile_extraction_repository_test` | `_FakeLlm` 喂 JSON：竞赛/科研解析、枚举归一、字段缺省、坏 JSON→Failure |
| `achievements_extraction_provider_test` | idle→loading→data/error（注入假仓储/假 LLM） |
| `profile_provider_test` | 初值加载、save 落盘、状态广播 |
| `ai_recommendation_repository_test`(扩展) | `_FakeLlm`：档案注入 prompt；**空档案 → 行为不变**（加性安全） |
| `recommendation_provider_test`(扩展) | 档案透传、档案变更触发重算（override `profileProvider`） |
| widget | `basic_info_form` / `score_and_interests_form` / `achievements_editor`(手动增删 + AI 整理→review) / `profile_wizard_page`(步进+渐进保存+完成→中心) / `profile_page`(分区+完成环+CTA) / `profile_prompt_sheet`(去完善/跳过) / `completion_ring` / `choice_chip_group` / `gpa_field` |

> **唯一回归点**：`recommendationProvider` 现 watch `profileProvider`，后者 build 读 `profileRepositoryProvider.load()`（需 SharedPreferences mock）。既有推荐相关测试补 `sharedPreferencesProvider` override 或把 `profileProvider` override 成空档案——与 `appConfigProvider` 迁移同类。**基线**：现有 67 测试文件 + `flutter analyze` 全绿。

---

## 12. 文件清单

**新增**
- `domain/entities/`：扩展 `user_profile.dart`(+`Gender`)；`academic_score.dart`、`competition.dart`、`research_item.dart`(+`ResearchType`)。
- `domain/repositories/profile_extraction_repository.dart`（+`AchievementDraft`）。
- `data/ai/ai_profile_extraction_repository.dart`。（**不新增 mock 抽取实现**）
- `features/profile/`：`pages/profile_page.dart`、`pages/profile_wizard_page.dart`；`providers/profile_provider.dart`、`providers/achievements_extraction_provider.dart`；`widgets/`（basic_info_form / score_and_interests_form / achievements_editor / achievement_item_card / gpa_field / profile_section_tile / profile_summary_header / wizard_scaffold / profile_prompt_sheet）。
- `shared/widgets/`：`labeled_text_field.dart`、`choice_chip_group.dart`、`completion_ring.dart`、`step_dots.dart`。

**改动**
- `domain/repositories/recommendation_repository.dart`（+`profile`）。
- `data/ai/ai_recommendation_repository.dart`（档案段 + 提示词）、`data/mock/mock_recommendation_repository.dart`（仅加形参并忽略）。
- `core/di/providers.dart`（+`profileExtractionRepositoryProvider`）。
- `features/recommendation/providers/recommendation_provider.dart`（watch+传 profile）。
- `features/home/pages/home_page.dart`（档案入口 + 即时触发）、`features/settings/pages/settings_page.dart`（入口 + 隐私行 + 清除）。
- `features/email/`（删/改 `widgets/profile_sheet.dart`、`pages/email_page.dart` 读 `profileProvider`）、`features/match/pages/match_page.dart`（读 `profileProvider`）。
- `core/router/app_router.dart`（+`/profile`、`/profile/wizard`）。
- `data/local/local_profile_repository.dart`（新字段序列化/反序列化）。

---

## 13. 分期实施（writing-plans 阶段细拆）

| 阶段 | 内容 | 依赖 |
|---|---|---|
| **A · 数据模型** | `UserProfile` 扩展 + 值对象 + `LocalProfileRepository` 序列化 + 向后兼容测试 | — |
| **B · AI 抽取** | `ProfileExtractionRepository` + AI 实现 + di + `_FakeLlm` 解析测试 | A |
| **C · 推荐注入** | `getRecommendations(+profile)` + `profileProvider` + AI 实现改造 + 回归修复 | A |
| **D · 原子组件** | 新 atoms/molecules（LabeledTextField/ChoiceChipGroup/CompletionRing/StepDots/GpaField/WizardScaffold…）+ widget 测 | — |
| **E · 向导 + 中心 + 触发 + 入口** | `ProfileWizardPage`/`ProfilePage`/`ProfilePromptSheet`/路由/入口 + 合并 email-match profile | B,C,D |
| **F · 隐私文案 + 打磨 + 回归** | 隐私行/清除、haptics/动效/三态、`flutter analyze` + 全绿 | E |

> 真实后端（§10）为设计交付，不入实施阶段；如需可另开 V1.0 plan。

---

## 14. 风险与缓解

| 风险 | 缓解 |
|---|---|
| LLM 抽取出错（错绑奖项/论文） | 抽取后**强制人工 review 可编辑** + 可纯手填；提示词"不编造"；`_FakeLlm` 测解析 |
| 档案注入致推荐幻觉 | 推荐仍只引用本地候选导师事实 + 既有免责；档案只影响排序/措辞 |
| `recommendationProvider` 重构破既有测试 | 经 `profileProvider` override 空档案迁移（同 `appConfigProvider` 模式） |
| 向导过长劝退 | 即时触发可跳过 + 渐进保存 + 中心页随时补全 + 完成度动机 |
| 无 AI 时抽取不可用 | 「AI 整理」按钮降级禁用，结构化条目可手填，不阻断流程 |
| 隐私顾虑 | 本地存储 + 明示发送 + 可清除 + 讲解模式可见 |

---

## 15. 范围外 / Backlog

- **清退既有"假分析"仓储**：`MockRecommendationRepository`/`MockMatchAnalysisRepository`/`MockComparisonRepository`/`MockChatRepository`/`MockOutreachEmailRepository` 及其 `core/di` mock 分支——既有 AI 仓储测试已用 `_FakeLlm`，这些可在独立小清理中移除（同时确认无 widget/provider 测依赖）。不在本 spec，避免牵动既有 di/测试。
- 可解释证据链 / 申请定位画像 / 套磁预演（原 Bento Phase 3/4/5）——并入既有 spec。
- 真实后端**实现**（§10 契约的 Http 仓储 + 账号 + profile 云同步）——V1.0。
- 全 App 原子化重构、深色模式精修、语音输入。

---

## 16. 开放问题 / 偏差

1. **「用我的档案推荐」CTA 落点**：跳首页搜索（默认，保留用户当下意图）还是直接以档案为 query 触发推荐？实现时定。
2. **抽取条目去重**：本轮简单"追加 + 人工删"，不做自动去重。
3. **GPA 量纲取值**：先给 4.0 / 4.3 / 4.5 / 5.0 / 100 五档 + 自由输入，按需增减。
4. **既有假分析清退时机**：本 spec 仅声明方向（§15），是否本轮顺带清理由你定；默认作独立后续。
