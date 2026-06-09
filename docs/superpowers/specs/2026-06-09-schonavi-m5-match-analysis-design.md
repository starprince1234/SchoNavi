# SchoNavi M5 · 背景匹配分析设计

- 版本：v1（2026-06-09，首稿——M5 实现前可再细化）
- 关系：引用 `2026-06-09-schonavi-m1-llm-core-design.md`（`LlmClient`/接地/DI）与 `...-m3-outreach-email-design.md`（复用 `UserProfile`/`ProfileRepository`）。
- 前置：M1 已落地；M3 已引入 `UserProfile` 本地档（M5 直接复用，不重复录入）。

---

## 1. 目标与价值

输入【学生背景】+ 选定【某导师】，大模型生成**匹配分析报告**：匹配点、差距/短板、可执行的准备建议。把"我适不适合 / 还差什么 / 怎么补"讲清，是高价值的生成式决策辅助，服务「应用价值 / 大模型应用能力」。

**非目标**：录取概率预测（明确不做、不打包票，只做信息性分析）；与多位导师同时匹配（单导师；多位用 M4 对比）。

---

## 2. 新增领域模型

```dart
// domain/entities/match_analysis.dart
class MatchAnalysis {
  const MatchAnalysis({
    required this.professorId,
    required this.summary,       // 总体匹配概述（非概率）
    required this.strengths,     // 你的匹配点
    required this.gaps,          // 差距/短板
    required this.suggestions,   // 可执行准备建议
  });
  final String professorId;
  final String summary;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> suggestions;
}
```

复用 M3 的 `UserProfile` 与 `ProfileRepository`（无新本地模型）。

## 3. 新增仓储接口

```dart
// domain/repositories/match_analysis_repository.dart
abstract interface class MatchAnalysisRepository {
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  });
}
```

- `AiMatchAnalysisRepository`：`LlmClient.complete(jsonMode:true)`；接地——导师事实取自 `Professor`，学生信息仅用 `profile`，不编造；输出强调"信息性、非录取预测"。
- `MockMatchAnalysisRepository`：模板（离线/测试）。

## 4. 交互流程

导师详情页新增「匹配分析」按钮（与「生成套磁邮件」并列）→
1. `profile.isEmpty` → 复用 M3 背景填写 sheet（保存本地）。
2. `analyze(...)` → loading →
3. 分析报告页：`summary` + 三段列表（匹配点 / 差距 / 建议，图标分区）+ 顶部免责提示"仅供参考，非录取预测"。
- 新增 feature `features/match/`（`pages/match_page.dart` + `providers/match_provider.dart`）。路由 `/match?pid=<professorId>`。

## 5. Prompt 设计（要点）

system：你是帮学生做"导师-背景匹配分析"的助手。据【导师】与【学生背景】输出 JSON（json）：`{summary, strengths[], gaps[], suggestions[]}`。规则：strengths=学生与该导师方向/要求的契合点；gaps=可能的短板（基于学生已提供信息，缺信息则指出"建议补充X"，不臆测）；suggestions=具体可执行准备（如补哪类基础、读哪方向论文、准备什么材料）；summary 客观概述，**严禁给出录取概率或"一定能/不能"的结论**；不得编造学生未提供的经历。
user：`【导师】{name,title,university,college,researchFields,bio}\n【学生背景】{profile 各字段}`。

## 6. DI

```dart
final matchAnalysisRepositoryProvider = Provider<MatchAnalysisRepository>((ref) {
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.mock: return MockMatchAnalysisRepository();
    case DataSource.ai:   return AiMatchAnalysisRepository(ref.watch(llmClientProvider));
    case DataSource.http: throw UnimplementedError('V1.0');
  }
});
```

## 7. 测试策略（TDD）

| 测试 | 覆盖 |
|---|---|
| `ai_match_analysis_repository_test` | 假 LlmClient JSON → 解析 `MatchAnalysis`（四部分）；坏 JSON→Failure；prompt 含导师方向与 profile |
| `mock_match_analysis_repository_test` | 含 strengths/gaps/suggestions 非空 |
| `match_provider_test` | 无 profile→提示填写；loading/done/error |
| `match_page_test`（widget） | 三段渲染 + 免责提示；重新生成 |
| `match_entry_point_test` | 详情页按钮跳 `/match?pid=` |
| `match_analysis_repository_provider_test` | 默认 mock 接线 |

## 8. 偏差/开放问题

1. **不预测录取概率**：伦理与可信度考量，仅信息性分析，UI 明确免责。
2. **复用 M3 `UserProfile`**：若 M3 未先实现，M5 需把 `UserProfile`/`ProfileRepository` 一并纳入（建议 M3 先做）。
3. **简历解析自动填背景**：主设计明确不做（Q7），背景仍手填。
