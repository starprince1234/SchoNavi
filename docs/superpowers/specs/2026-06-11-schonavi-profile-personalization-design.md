# SchoNavi 设计 · 个人档案 → 个性化推荐（结构化 + AI 抽取 + 档案注入）

- 版本：v1（2026-06-11，首稿——实现前可再细化）
- 关系：建立在 **M1–M5 + Bento Phase 0/1/2（均已实现并 commit）** 之上。这是**用户三个新故事**收敛后的聚焦立项：
  - 故事①（可维护性 / 原子化组件）：本 spec 把 profile 功能做成 **atoms→molecules→organisms→pages 的样板**，并顺手清理 home/email 的 profile 重复；其余页面的原子化按需逐步并入既有工作，不在本轮强推。
  - 故事②（UI 精致度 / 交互体验）：复用 Bento 系统（`core/haptics`、`AnimatedEntrance`、`BentoTile`），档案流做到"真 App"质感。
  - 故事③（个人信息 → 更准推荐）：**本 spec 的主线与优先项**。
- 直击参赛短板：当前推荐主链路 `getRecommendations({required String prompt})` **完全不读 `UserProfile`**，profile 仅用于套磁/匹配。把完整背景接入推荐，是「大模型应用能力」维度最直接的增益（见 `schonavi-aigc-competition-rubric`）。
- 前置：DeepSeek key 冒烟 `flutter run --dart-define=LLM_API_KEY=...`；mock 兜底全程保留（断网可演示）。
- 开发约定：沿用仓库既有分层 + Riverpod 3.2.1 手写 provider + Mock/Result + TDD（不在此重复，见 `schonavi-dev-conventions`）。

---

## 1. 目标与策略

让用户用**完整、结构化的个人背景**换取**更精准、可感知"懂我"的导师推荐**，同时把这块新功能做成代码原子化与 UI 精致度的样板。

**四个已锁定的关键决策**（brainstorm 产出）：

| # | 决策 | 选择 |
|---|---|---|
| 1 | 录入 / 解析模型 | **混合**：关键字段结构化录入；竞赛/科研等"成果"自由文本 → **LLM 抽取成可编辑条目**，用户确认后入库 |
| 2 | 推荐如何变准 | **基线注入**：推荐时把"完整档案 + 查询"一起喂 LLM，背景影响排序与理由。本轮不做证据链/定位画像 |
| 3 | 界面结构 | **首填向导(B) → 档案中心(C)**：新用户走分步向导，完成即落到 `/profile` 中心；之后查看/编辑都在中心 |
| 4 | 向导触发时机 | **即时触发**：首页/推荐照常可用；首次发起推荐或点"我的档案"时弹引导进向导（可跳过），与现有开屏引导解耦 |

---

## 2. 范围

**In**
- `UserProfile` 结构化扩展（性别、目标阶段、成绩、竞赛、科研）。
- AI 成果抽取仓储（自由文本 → 结构化条目，mock|ai 切换）。
- 推荐注入（`getRecommendations` 加性 `profile` 参数 + 响应式 `profileProvider`）。
- 首填向导(B) + 档案中心(C) + 即时触发 sheet + 入口。
- 隐私透明（本地存储声明 + AI 发送声明 + 清除）。
- profile 功能原子化样板 + 合并 home/email 现有 profile 重复 UI。

**Out / 非目标**
- 可解释证据链 / 申请定位画像 / 套磁预演（原 Bento spec Phase 3/4/5）——日后并入既有 spec。
- 后端 / 账号 / profile 云同步——`DataSource.http` 仍抛 `UnimplementedError`。
- 全 App 原子化重构——只做 profile 样板 + 顺手清理；其余按需。
- 深色模式精修、语音输入。
- 录取概率预测——延续既有非目标，仅信息性。

---

## 3. 数据模型（全部加性，旧档案照常加载）

`domain/entities/`，遵循"一实体一文件"：扩展 `user_profile.dart`，新增 `academic_score.dart` / `competition.dart` / `research_item.dart`。`Gender` 与 `UserProfile` 同文件，`ResearchType` 与 `ResearchItem` 同文件。

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

  // 新增 · AI 抽取（可编辑条目）
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

**完成度计算**（用于中心页进度环，去歧义）：对以下 7 项各计权重，命中即得分，完成度 = 命中数 / 7：
1. `name` 非空　2. `gender != null`　3. `school` 与 `major` 均非空　4. `targetDegree` 非空　5. `score?.gpa != null`　6. `researchInterests.isNotEmpty`　7. `competitions.isNotEmpty || research.isNotEmpty`

`isEmpty` 扩展为：上述全部未命中。缺失字段一律显示「暂无信息」，绝不渲染 null。

---

## 4. AI 成果抽取

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

- **`AiProfileExtractionRepository(llm)`**：`llm.complete(jsonMode:true, temperature:0.2)`。系统提示词要求：仅依据用户输入抽取，**不编造未提及的奖项/论文**；`level/award/type` 归一到枚举/常见取值，拿不准就留空；缺字段给空字符串/`other`；输出单一 JSON。解析时坏 JSON → `Failure(ServerException())`，逐条 `Competition/ResearchItem` 字段缺省兜底。
- **`MockProfileExtractionRepository`**：关键词/正则朴素解析（识别"银牌/一等奖/论文/专利/项目"等），离线/演示兜底；保证 `mock` 模式可跑、可测、确定性。
- **di**：`profileExtractionRepositoryProvider` 按 `appConfigProvider.dataSource` switch（`mock` 默认 / `ai` 用 `llmClientProvider` / `http` → `UnimplementedError`），与既有仓储 provider 同构。

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

- **`AiRecommendationRepository`**：在既有 user 消息中追加「学生档案」段（姓名可略，重点性别/阶段/目标/GPA/排名/研究兴趣/竞赛/科研的紧凑 JSON）；系统提示词增规则：**结合学生背景排序，`reason` 适当引用背景**（如"你有 ACM 区域赛银牌，与 TA 算法方向契合"），但仍**只引用候选导师事实、不编造**。`profile == null || profile.isEmpty` → 不追加该段，行为与现状完全一致（**加性安全**）。
- **`MockRecommendationRepository`**：接收 `profile` 但忽略（保持离线确定性）。
- **响应式 `profileProvider`**（新增于 `features/profile/providers/profile_provider.dart`，属 feature 状态）：
  ```dart
  final profileProvider = NotifierProvider<ProfileController, UserProfile>(ProfileController.new);
  class ProfileController extends Notifier<UserProfile> {
    UserProfile build() => ref.read(profileRepositoryProvider).load();   // 初值
    Future<void> save(UserProfile p) async { state = p; await ref.read(profileRepositoryProvider).save(p); }
    // 便捷 update：copyWith 局部字段后 save
  }
  ```
- **`recommendationProvider`** 改为读取并依赖档案：
  ```dart
  final recommendationProvider = FutureProvider.family<RecommendationResult, String>((ref, prompt) async {
    final profile = ref.watch(profileProvider);              // 档案变更 → 自动失效重算
    final repo = ref.watch(recommendationRepositoryProvider);
    final result = await repo.getRecommendations(prompt: prompt, profile: profile);
    return switch (result) { Success(:final data) => data, Failure(:final error) => throw error };
  });
  ```
  family key 仍为 `prompt`；档案从 `profileProvider` 读取，变更时该 provider 重新执行。

---

## 6. 界面与交互

### 6.1 流程接线
- **入口**：首页 `AppBar` 加「我的档案」图标（设置图标旁）；设置页加一行「我的背景档案」。均导航 `/profile`。
- **即时触发**：`home_page` 的 `_submit()` 在跳 `/recommendation` 前判断：`profileProvider` 为空 **且** 未记 `profile_prompt_dismissed` flag → 弹 `ProfilePromptSheet`（底部 sheet，拖拽手柄）。「去完善」→ `/profile/wizard`；「先跳过」→ 写 `profile_prompt_dismissed=true`（localStore）后照常跳推荐。点「我的档案」时若档案为空，同样进向导。
- **统一档案**：套磁页旧的 `showProfileSheet`（6 字段 sheet）**并入**新档案流——`email_page` / `match_page` 改读 `profileProvider`；旧 `profile_sheet.dart` 删除或改为薄跳转到 `/profile`。完善一次，三处受益。
- **路由**（`app_router.dart`）：新增 `/profile`（中心 C）、`/profile/wizard`（首填 B），均用 `sharedAxisPage` 转场。现有开屏 `seenOnboarding` redirect 逻辑不动。

### 6.2 首填向导(B)
分 3 步，`WizardScaffold`（头 + `StepDots` + 滚动体 + 底部 sticky「上一步/下一步」条）承载：
- **① 基本信息**：姓名、性别(`ChoiceChipGroup`)、学校、专业、当前阶段、目标阶段。
- **② 成绩 & 方向**：`GpaField`（GPA 值 + 量纲 chips + 排名）、研究兴趣(`FieldChips` 追加)。
- **③ 成果**：自由文本框 → 「✨ AI 整理成条目」→ `AchievementsEditor` 展示抽取出的竞赛/科研条目，可逐条编辑/删除 →「完成」。

**渐进保存（去歧义）**：每次「下一步」即把该步字段经 `profileProvider.save` 落盘；③ 的抽取条目在「完成」时持久化（抽取出的条目默认纳入，删除即移除）。故中途退出 App 不丢已填内容；首填完成后导航替换到 `/profile`。

### 6.3 档案中心(C) — `/profile`
- `ProfileSummaryHeader`：`CompletionRing`（0→N% 滚动动画）+「越完整 · 推荐越准」+「用我的档案推荐」CTA（→ 首页搜索 / 直接推荐）。
- `ProfileSectionTile` 列表：基本信息 ✓ / 成绩 ✓ / 研究兴趣 N 个 / 竞赛 N 项 › / 科研 N 项 ›。点分区 → 底部可拖拽 sheet 内聚焦编辑（复用向导同款 organism）。
- 底部「＋ 粘贴自述，AI 帮你填」入口（复用 `AchievementsEditor`）。

### 6.4 精致度（故事②）
完成度环 0→N 滚动；AI 抽取中 `AchievementsEditor` 用 `ShimmerSkeleton` 占位；haptics：chip `selectionClick`、下一步 `lightImpact`、抽取完成 `mediumImpact`、保存 `lightImpact`；底部 sticky 操作条（拇指可达 ≥48dp）；中心页卡片 `AnimatedEntrance` 错峰入场；编辑用可拖拽底部 sheet。尊重 `MediaQuery.textScaler`、图标按钮加 `Semantics`。

---

## 7. 原子化组件架构（故事①）

按 atoms → molecules → organisms → pages 分层，每个 organism 用构造参数 + 回调通信、可独立 widget 测、可被向导与中心复用。

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
  AchievementsEditor（自由文本 + ✨AI整理 → 抽取 review 列表）  ← AI 抽取核心
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

- **本地存储**：档案仅经 `LocalProfileRepository`（SharedPreferences，key `user_profile.v1`，加性扩展无需升 key）存本机，不上传后端。
- **解析即发送**：AI 模式下档案字段随推荐/抽取请求发送给大模型用于解析。向导首屏与设置页各明示一行：「资料仅保存在本机；AI 模式下会随请求发送给大模型用于解析与推荐」。
- **可清除**：设置页「清除本地资料」覆盖档案清除。
- **天然印证**：现有「讲解模式」(`showAiTrace`) 开启时，trace 中可见档案确被带入 prompt——透明度与"大模型应用能力"录屏证据兼得。

---

## 9. 架构与接线

- **分层不变**：`presentation(features/profile) → domain(entities + repo 接口) ← data(ai/mock/local)`，横切 `core`。
- **新增 provider**：`profileExtractionRepositoryProvider`（`core/di/providers.dart`，按 dataSource 切）；`profileProvider`（`features/profile/providers/profile_provider.dart`，`NotifierProvider`，feature 状态）。
- **mock 兜底**全程保留；AI 模式 `--dart-define` 注入 key。
- **大模型应用模式展示**（作品说明清单可加项）：结构化输出（抽取 jsonMode → 实体）、事实接地（抽取不编造 + 推荐只引用候选事实）、个性化生成（档案注入推荐理由）。

---

## 10. 测试策略（TDD，先写测试）

| 测试 | 覆盖 |
|---|---|
| `user_profile_test` | 新字段、`isEmpty`、完成度% 计算（边界） |
| `local_profile_repository_test` | 新字段序列化 + **旧 v1 JSON 向后兼容加载** |
| `ai_profile_extraction_repository_test` | 竞赛/科研解析、枚举归一、字段缺省兜底、坏 JSON→Failure |
| `mock_profile_extraction_repository_test` | 朴素解析形状（离线兜底、确定性） |
| `achievements_extraction_provider_test` | idle→loading→data/error、mock/ai 切换 |
| `profile_provider_test` | 初值加载、save 落盘、状态广播 |
| `ai_recommendation_repository_test`(扩展) | 档案注入 prompt；**空档案 → 行为不变**（加性安全） |
| `recommendation_provider_test`(扩展) | 档案透传、档案变更触发重算 |
| widget | `basic_info_form` / `score_and_interests_form` / `achievements_editor`(抽取→review) / `profile_wizard_page`(步进+渐进保存+完成→中心) / `profile_page`(分区+完成环+CTA) / `profile_prompt_sheet`(去完善/跳过) / `completion_ring` / `choice_chip_group` / `gpa_field` |

> **唯一回归风险**：`recommendationProvider` 现 watch `profileProvider`，后者 build 读 `profileRepositoryProvider.load()`（需 SharedPreferences mock）。既有推荐相关测试需补 `sharedPreferencesProvider` override 或把 `profileProvider` override 成空档案——与 `appConfigProvider` 迁移同类，可控。**基线**：现有 67 测试文件 + `flutter analyze` 全绿。

---

## 11. 文件清单

**新增**
- `domain/entities/`：扩展 `user_profile.dart`(+`Gender`)；`academic_score.dart`、`competition.dart`、`research_item.dart`(+`ResearchType`)。
- `domain/repositories/profile_extraction_repository.dart`（+`AchievementDraft`）。
- `data/ai/ai_profile_extraction_repository.dart`、`data/mock/mock_profile_extraction_repository.dart`。
- `features/profile/`：`pages/profile_page.dart`、`pages/profile_wizard_page.dart`；`providers/profile_provider.dart`、`providers/achievements_extraction_provider.dart`；`widgets/`（basic_info_form / score_and_interests_form / achievements_editor / achievement_item_card / gpa_field / profile_section_tile / profile_summary_header / wizard_scaffold / profile_prompt_sheet）。
- `shared/widgets/`：`labeled_text_field.dart`、`choice_chip_group.dart`、`completion_ring.dart`、`step_dots.dart`。

**改动**
- `domain/repositories/recommendation_repository.dart`（+`profile`）。
- `data/ai/ai_recommendation_repository.dart`（档案段 + 提示词）、`data/mock/mock_recommendation_repository.dart`（接收+忽略 profile）。
- `core/di/providers.dart`（+`profileProvider`、+`profileExtractionRepositoryProvider`）。
- `features/recommendation/providers/recommendation_provider.dart`（watch+传 profile）。
- `features/home/pages/home_page.dart`（档案入口 + 即时触发）、`features/settings/pages/settings_page.dart`（入口 + 隐私行 + 清除）。
- `features/email/`（删/改 `widgets/profile_sheet.dart`、`pages/email_page.dart` 读 `profileProvider`）、`features/match/pages/match_page.dart`（读 `profileProvider`）。
- `core/router/app_router.dart`（+`/profile`、`/profile/wizard`）。
- `data/local/local_profile_repository.dart`（新字段序列化/反序列化）。

---

## 12. 分期实施（writing-plans 阶段细拆）

| 阶段 | 内容 | 依赖 |
|---|---|---|
| **A · 数据模型** | `UserProfile` 扩展 + 值对象 + `LocalProfileRepository` 序列化 + 向后兼容测试 | — |
| **B · AI 抽取** | `ProfileExtractionRepository` + ai/mock + di + 解析测试 | A |
| **C · 推荐注入** | `getRecommendations(+profile)` + `profileProvider` + ai/mock + provider 改造 + 回归修复 | A |
| **D · 原子组件** | 新 atoms/molecules（LabeledTextField/ChoiceChipGroup/CompletionRing/StepDots/GpaField/WizardScaffold…）+ widget 测 | — |
| **E · 向导 + 中心 + 触发 + 入口** | `ProfileWizardPage`/`ProfilePage`/`ProfilePromptSheet`/路由/入口 + 合并 email-match profile | B,C,D |
| **F · 隐私文案 + 打磨 + 回归** | 隐私行/清除、haptics/动效/三态、`flutter analyze` + 全绿 | E |

---

## 13. 风险与缓解

| 风险 | 缓解 |
|---|---|
| LLM 抽取出错（错绑奖项/论文） | 抽取后**强制人工 review 可编辑**；提示词"不编造未提及"；mock 兜底 |
| 档案注入致推荐幻觉 | 推荐仍只引用候选导师事实 + 既有免责；档案只影响排序/措辞 |
| `recommendationProvider` 重构破既有测试 | 经 `profileProvider` override 空档案迁移（同 `appConfigProvider` 模式） |
| 向导过长劝退 | 即时触发可跳过 + 渐进保存 + 中心页随时补全 + 完成度动机 |
| 隐私顾虑 | 本地存储 + 明示发送 + 可清除 + 讲解模式可见 |

---

## 14. 范围外 / Backlog

- 可解释证据链 / 申请定位画像 / 套磁预演（原 Bento Phase 3/4/5）——日后并入既有 spec。
- profile 云同步 / 后端 / 账号（V1.0，`DataSource.http`）。
- 全 App 原子化重构（其余页面按需逐步）。
- 深色模式精修、语音输入。

---

## 15. 开放问题 / 偏差

1. **「用我的档案推荐」CTA 落点**：跳首页搜索（让用户补一句查询）还是直接以档案为 query 触发推荐？实现时定，倾向前者（保留用户当下意图）。
2. **抽取条目去重**：同一成果多次抽取是否去重——本轮简单"追加 + 人工删"，不做自动去重。
3. **GPA 量纲取值**：先给 4.0 / 4.3 / 4.5 / 5.0 / 100 五档 + 自由输入，实现时按需增减。
