# SchoNavi M4 · 多导师对比报告设计

- 版本：v1（2026-06-09，首稿——M4 实现前可再细化）
- 关系：引用 `2026-06-09-schonavi-m1-llm-core-design.md`（`LlmClient`/接地/DI）与主设计 §8（`/compare` 路由原列 V1.0，此处提前）。
- 前置：M1 已落地；收藏功能（V0.2）已存在，作为选取入口。

---

## 1. 目标与价值

让用户**勾选 2-3 位导师**（从收藏或推荐结果），由大模型生成**结构化横向对比 + 选择建议**。把分散信息整合为决策，是生成式 AI 的典型增值，服务「应用价值 / 大模型应用能力」。

**非目标**：超过 3 位的对比（信息过载，限 2-3）；跨会话持久化对比报告（即用即看，可后续加收藏报告）。

---

## 2. 新增领域模型

```dart
// domain/entities/comparison_report.dart
class ComparisonRow {
  const ComparisonRow({required this.dimension, required this.cells});
  final String dimension;                 // 如"研究方向匹配""学校/地区""招生信息""适合人群"
  final Map<String, String> cells;        // professorId -> 该维度短评
}

class ComparisonReport {
  const ComparisonReport({
    required this.professorIds,
    required this.rows,
    required this.summary,
    required this.suggestion,
  });
  final List<String> professorIds;        // 维持列顺序
  final List<ComparisonRow> rows;
  final String summary;                   // 总体对比小结
  final String suggestion;                // "若你更看重 X 可优先 Y"式建议（不武断下唯一结论）
}
```

## 3. 新增仓储接口

```dart
// domain/repositories/comparison_repository.dart
abstract interface class ComparisonRepository {
  /// professors 限 2-3 位；少于 2 由调用方拦截。
  Future<Result<ComparisonReport>> compare({required List<Professor> professors});
}
```

- `AiComparisonRepository`：`LlmClient.complete(jsonMode:true)`；接地——只对传入导师评述，事实取自 `Professor`，`cells` 的 key 必须是传入的 `professorId`（解析时丢弃未知 key）。
- `MockComparisonRepository`：按字段拼装表格（离线/测试）。

## 4. 交互流程

收藏页新增「对比」入口 → 进入多选模式 → 勾选 2-3 位（<2 禁用、>3 提示上限）→「生成对比」→ loading → 对比报告页：
- 顶部各导师列头（姓名/学校）；
- 维度表（`rows` 渲染为表格，列对齐导师）；
- 「总体小结」`summary` + 「选择建议」`suggestion`（`GptMarkdown`）；
- 每列可点进对应导师详情。
- 新增 feature `features/compare/`（`pages/compare_page.dart` + `providers/compare_provider.dart`）。路由 `/compare?ids=p_001,p_003`。导师数据由 `ids` → `MockDb.getProfessor` 取（接地）。

## 5. Prompt 设计（要点）

system：你是帮学生横向对比导师的助手。仅对【导师列表】中的导师评述，输出 JSON（json）：`{rows:[{dimension, cells:{professorId:短评}}], summary, suggestion}`。规则：维度建议含"研究方向匹配/学校与地区/职称与梯队/招生与培养(以官网为准)/适合人群"；每格 1-2 句、客观中立；summary 概述差异；suggestion 给"若看重 X 则倾向 Y"的条件式建议，**不下唯一武断结论**；不得编造未提供的事实（招生名额等用"建议向学校/导师确认"）。
user：`【导师列表】[{professorId,name,title,university,college,researchFields,bio}...]`。

## 6. DI

```dart
final comparisonRepositoryProvider = Provider<ComparisonRepository>((ref) {
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.mock: return MockComparisonRepository();
    case DataSource.ai:   return AiComparisonRepository(ref.watch(llmClientProvider));
    case DataSource.http: throw UnimplementedError('V1.0');
  }
});
```

## 7. 测试策略（TDD）

| 测试 | 覆盖 |
|---|---|
| `ai_comparison_repository_test` | 假 LlmClient JSON → 解析 `ComparisonReport`；接地（未知 professorId 的 cell 丢弃）；坏 JSON→Failure |
| `mock_comparison_repository_test` | rows 覆盖每位导师、含关键维度 |
| `compare_provider_test` | 2-3 校验；loading/done/error |
| `compare_page_test`（widget） | 列头/维度表渲染；列点击跳详情；summary/suggestion 显示 |
| `compare_entry_point_test` | 收藏页多选 2-3 → 跳 `/compare?ids=` |
| `comparison_repository_provider_test` | 默认 mock 接线 |

## 8. 偏差/开放问题

1. **`/compare` 从 V1.0 提前到 M4**（主设计 §8）。
2. **限 2-3 位**：>3 信息过载且超 token，UI 拦截。
3. **报告暂不持久化**：即用即看；"收藏对比报告"作为后续增强。
4. **入口**：以收藏页多选为主；推荐结果页多选入口可作为 M4 增强（同一 `/compare` 路由复用）。
