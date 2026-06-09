# SchoNavi M4 · 多导师对比报告 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用户在收藏页多选 **2-3 位导师** → 大模型生成**结构化横向对比报告**（维度表 + 总体小结 + 选择建议），接地（只评述传入导师，事实取自 `Professor`，丢弃未知 `professorId` 的单元格），离线 mock 兜底。

**Architecture:** 新增领域模型 `ComparisonRow`/`ComparisonReport` 与仓储接口 `ComparisonRepository`（远程类，走 `Result`）。`AiComparisonRepository` 用 M1 的 `LlmClient.complete(jsonMode:true)` 产出 `{rows, summary, suggestion}`，列顺序与单元格 key 以传入导师为准（接地）；`MockComparisonRepository` 按字段拼装离线表格。新增 feature 目录 `features/compare/`（`compare_page` + `compare_provider`），路由 `/compare?ids=p_001,p_003`；导师由 `ids` 经既有 `professorRepositoryProvider.getProfessor` 解析（接地）。收藏页新增多选模式入口跳转 `/compare`。DI 加 `comparisonRepositoryProvider`。presentation/domain 既有零改动（仅追加）。

**Tech Stack:** Flutter 3.44 / Dart 3.12；`flutter_riverpod ^3.3.1`（手写 provider）；`go_router ^17.3.0`；M1 的 `LlmClient`（`dio`）；`gpt_markdown ^1.1.7`（`GptMarkdown` 渲染小结/建议）。无新依赖。

**Spec 依据:** `docs/superpowers/specs/2026-06-09-schonavi-m4-compare-design.md`。

**前置条件（已核实落地）:** M1 已实现（`LlmClient.complete(jsonMode:…)` + `stream`、`DataSource.ai|mock` DI 切换、`professorRepositoryProvider.getProfessor(String)→Future<Result<Professor>>`、`mockDbProvider`/`MockDb.getProfessor` 可用）；M2 流式已实现（`LlmClient` 含 `stream`，故任何 `LlmClient` 假实现须**同时**实现 `complete` 与 `stream`）；收藏功能 V0.2 已落地（`favoritesProvider`/`favoriteRepositoryProvider`、`FavoriteItem`）。`flutter test` 全绿，分支 `iter1`。

**与 spec 的偏差/本计划另定:**
- 导师解析走既有 `professorRepositoryProvider.getProfessor`（mock/ai 下均为 `MockProfessorRepository`→`MockDb`，等价 spec §4 的 `MockDb.getProfessor`，但不让 feature 层直依赖 `MockDb`）。
- 对比报告**不持久化**（spec §8.3，即用即看）。
- 入口以**收藏页多选**为主（spec §8.4）；推荐结果页多选入口留作后续增强（复用同一 `/compare` 路由）。
- 列对齐表格用 `Row`+`Expanded`（N 列）实现，`GptMarkdown` 渲染 `summary`/`suggestion`；列头可点进 `/professor/:id`。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/domain/entities/comparison_report.dart` | 新：`ComparisonRow` + `ComparisonReport` |
| `lib/domain/repositories/comparison_repository.dart` | 新：`ComparisonRepository`（Result） |
| `lib/data/ai/ai_comparison_repository.dart` | 新：接地 JSON 对比，丢弃未知 `professorId` 单元格 |
| `lib/data/mock/mock_comparison_repository.dart` | 新：按字段拼装离线表格 |
| `lib/core/di/providers.dart` | **改**：加 `comparisonRepositoryProvider` |
| `lib/features/compare/providers/compare_provider.dart` | 新：`CompareNotifier` + `CompareState` |
| `lib/features/compare/pages/compare_page.dart` | 新：列头/维度表/小结/建议渲染 |
| `lib/core/router/app_router.dart` | **改**：加 `/compare` 路由 |
| `lib/features/favorite/pages/favorite_page.dart` | **改**：多选模式 + 「对比」入口 |
| `test/domain/entities/comparison_report_test.dart` | 实体构造 |
| `test/data/ai/ai_comparison_repository_test.dart` | 解析 / 接地丢弃未知 key / jsonMode / 坏 JSON / 失败透传 |
| `test/data/mock/mock_comparison_repository_test.dart` | rows 覆盖每位导师 + 含关键维度 |
| `test/core/di/comparison_repository_provider_test.dart` | 默认 mock + ai 接线 |
| `test/features/compare/compare_provider_test.dart` | 2-3 校验 / loading / ready / error |
| `test/features/compare/compare_page_test.dart` | 列头/维度表/小结/建议渲染 + 列点击跳详情 |
| `test/features/compare/compare_entry_point_test.dart` | 收藏页多选 2 位 → `/compare?ids=` |

> 不改 domain 既有实体、其它 feature、mock 数据。既有测试默认 `mock`，须保持全绿（含 5 个 `favorite_page_test`——本计划保持非多选模式行为不变）。

---

## Task 1: 领域模型 + 仓储接口

**Files:**
- Create: `lib/domain/entities/comparison_report.dart`
- Create: `lib/domain/repositories/comparison_repository.dart`
- Test: `test/domain/entities/comparison_report_test.dart`

- [ ] **Step 1: 写失败测试 `test/domain/entities/comparison_report_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';

void main() {
  test('ComparisonReport 保留列顺序与行数据', () {
    const report = ComparisonReport(
      professorIds: ['p_001', 'p_003'],
      rows: [
        ComparisonRow(
          dimension: '研究方向',
          cells: {'p_001': '医学影像', 'p_003': '自动驾驶'},
        ),
      ],
      summary: '两位方向差异明显。',
      suggestion: '若看重医学影像可优先 p_001。',
    );
    expect(report.professorIds, ['p_001', 'p_003']);
    expect(report.rows.single.dimension, '研究方向');
    expect(report.rows.single.cells['p_003'], '自动驾驶');
    expect(report.summary, isNotEmpty);
    expect(report.suggestion, isNotEmpty);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/domain/entities/comparison_report_test.dart`
Expected: FAIL（`comparison_report.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/domain/entities/comparison_report.dart`**

```dart
/// 对比表的一行：一个维度跨多位导师的短评。
class ComparisonRow {
  const ComparisonRow({required this.dimension, required this.cells});

  final String dimension; // 如"研究方向""学校与地区""职称""适合人群"
  final Map<String, String> cells; // professorId -> 该维度短评
}

/// 多导师横向对比报告。professorIds 维持列顺序。
class ComparisonReport {
  const ComparisonReport({
    required this.professorIds,
    required this.rows,
    required this.summary,
    required this.suggestion,
  });

  final List<String> professorIds;
  final List<ComparisonRow> rows;
  final String summary; // 总体对比小结
  final String suggestion; // "若你更看重 X 可优先 Y"式建议，不武断下唯一结论
}
```

- [ ] **Step 4: 实现 `lib/domain/repositories/comparison_repository.dart`**

```dart
import '../../core/result/result.dart';
import '../entities/comparison_report.dart';
import '../entities/professor.dart';

/// 多导师横向对比（远程类，走 Result）。professors 限 2-3 位；少于 2 由调用方拦截。
abstract interface class ComparisonRepository {
  Future<Result<ComparisonReport>> compare({required List<Professor> professors});
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/domain/entities/comparison_report_test.dart`
Expected: PASS（1 个）。

- [ ] **Step 6: 提交**

```bash
git add lib/domain/entities/comparison_report.dart lib/domain/repositories/comparison_repository.dart test/domain/entities/comparison_report_test.dart
git commit -m "feat: add ComparisonReport entities + ComparisonRepository (M4)"
```

---

## Task 2: AiComparisonRepository

**Files:**
- Create: `lib/data/ai/ai_comparison_repository.dart`
- Test: `test/data/ai/ai_comparison_repository_test.dart`

- [ ] **Step 1: 写失败测试 `test/data/ai/ai_comparison_repository_test.dart`**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_comparison_repository.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';

class _FakeLlm implements LlmClient {
  _FakeLlm(this._result);

  final Result<String> _result;
  List<LlmMessage>? lastMessages;
  bool? lastJsonMode;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    lastMessages = messages;
    lastJsonMode = jsonMode;
    return _result;
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError(); // 对比不流式，桩即可
}

const _p1 = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
  bio: '研究医学影像。',
);
const _p3 = Professor(
  id: 'p_003',
  name: '王强',
  university: '北京大学',
  college: '信息科学技术学院',
  title: '教授',
  researchFields: ['自动驾驶', '深度学习'],
);

String _validJson() => jsonEncode({
  'rows': [
    {
      'dimension': '研究方向',
      'cells': {'p_001': '偏医学影像', 'p_003': '偏自动驾驶'},
    },
  ],
  'summary': '两位导师方向差异明显。',
  'suggestion': '若你更看重医学影像，可优先关注张三。',
});

void main() {
  test('解析 rows/summary/suggestion，列顺序取传入导师，且用 JSON 模式', () async {
    final llm = _FakeLlm(Success(_validJson()));
    final repo = AiComparisonRepository(llm);
    final res = await repo.compare(professors: [_p1, _p3]);
    final report = (res as Success<ComparisonReport>).data;
    expect(report.professorIds, ['p_001', 'p_003']); // 列顺序接地
    expect(report.rows.single.dimension, '研究方向');
    expect(report.rows.single.cells['p_001'], '偏医学影像');
    expect(report.summary, contains('差异'));
    expect(report.suggestion, contains('张三'));
    expect(llm.lastJsonMode, isTrue);
  });

  test('接地：丢弃未知 professorId 的单元格', () async {
    final json = jsonEncode({
      'rows': [
        {
          'dimension': '研究方向',
          'cells': {'p_001': 'a', 'p_999': '伪造', 'p_003': 'b'},
        },
      ],
      'summary': 's',
      'suggestion': 'g',
    });
    final repo = AiComparisonRepository(_FakeLlm(Success(json)));
    final report =
        (await repo.compare(professors: [_p1, _p3]) as Success<ComparisonReport>)
            .data;
    expect(report.rows.single.cells.keys.toSet(), {'p_001', 'p_003'});
  });

  test('user prompt 含两位导师方向（接地输入）', () async {
    final llm = _FakeLlm(Success(_validJson()));
    await AiComparisonRepository(llm).compare(professors: [_p1, _p3]);
    final userMsg = llm.lastMessages!.last.content;
    expect(userMsg, contains('医学影像'));
    expect(userMsg, contains('自动驾驶'));
    expect(userMsg, contains('p_001'));
    expect(userMsg, contains('p_003'));
  });

  test('坏 JSON → Failure(ServerException)', () async {
    final repo = AiComparisonRepository(const _FakeLlm(Success('not json')));
    final res = await repo.compare(professors: [_p1, _p3]);
    expect((res as Failure).error, isA<ServerException>());
  });

  test('缺 summary/suggestion → Failure(ServerException)', () async {
    final repo = AiComparisonRepository(
      _FakeLlm(Success(jsonEncode({'rows': [], 'summary': 's'}))),
    );
    final res = await repo.compare(professors: [_p1, _p3]);
    expect((res as Failure).error, isA<ServerException>());
  });

  test('LlmClient 失败透传', () async {
    final repo = AiComparisonRepository(
      const _FakeLlm(Failure(NetworkException())),
    );
    final res = await repo.compare(professors: [_p1, _p3]);
    expect((res as Failure).error, isA<NetworkException>());
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/data/ai/ai_comparison_repository_test.dart`
Expected: FAIL（`ai_comparison_repository.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/data/ai/ai_comparison_repository.dart`**

```dart
import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/comparison_report.dart';
import '../../domain/entities/professor.dart';
import '../../domain/repositories/comparison_repository.dart';

/// 用大模型对传入的 2-3 位导师做横向对比。列顺序与单元格 key 以传入导师为准（接地），
/// 模型返回中未知 professorId 的单元格丢弃，事实不编造。
class AiComparisonRepository implements ComparisonRepository {
  const AiComparisonRepository(this.llm);

  final LlmClient llm;

  @override
  Future<Result<ComparisonReport>> compare({
    required List<Professor> professors,
  }) async {
    final ids = professors.map((p) => p.id).toList();
    final res = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(professors)),
      ],
      jsonMode: true,
      temperature: 0.3,
    );
    switch (res) {
      case Failure(:final error):
        return Failure(error);
      case Success(:final data):
        try {
          return Success(_parse(data, ids));
        } catch (_) {
          return const Failure(ServerException());
        }
    }
  }

  ComparisonReport _parse(String content, List<String> ids) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final idSet = ids.toSet();
    final summary = (json['summary'] as String?)?.trim();
    final suggestion = (json['suggestion'] as String?)?.trim();
    if (summary == null ||
        summary.isEmpty ||
        suggestion == null ||
        suggestion.isEmpty) {
      throw const FormatException('missing summary/suggestion');
    }

    final rows = <ComparisonRow>[];
    for (final item in (json['rows'] as List? ?? const [])) {
      if (item is! Map) continue;
      final dimension = (item['dimension'] as String?)?.trim();
      if (dimension == null || dimension.isEmpty) continue;
      final cellsRaw = item['cells'];
      final cells = <String, String>{};
      if (cellsRaw is Map) {
        cellsRaw.forEach((k, v) {
          if (k is String && idSet.contains(k) && v is String && v.isNotEmpty) {
            cells[k] = v;
          }
        });
      }
      if (cells.isEmpty) continue; // 接地：整行无有效导师则丢弃
      rows.add(ComparisonRow(dimension: dimension, cells: cells));
    }
    if (rows.isEmpty) throw const FormatException('no valid rows');

    return ComparisonReport(
      professorIds: ids, // 列顺序接地于传入导师
      rows: rows,
      summary: summary,
      suggestion: suggestion,
    );
  }

  String _userPrompt(List<Professor> professors) {
    final list = [
      for (final p in professors)
        {
          'professorId': p.id,
          'name': p.name,
          'title': p.title,
          'university': p.university,
          'college': p.college,
          'researchFields': p.researchFields,
          if (p.bio != null) 'bio': p.bio,
        },
    ];
    return '【导师列表】${jsonEncode(list)}';
  }

  static const String _systemPrompt = '''
你是帮学生横向对比导师的助手。仅对【导师列表】中的导师评述，输出一个 JSON 对象（json），不要 Markdown 或多余文字：
{"rows":[{"dimension":"...","cells":{"<professorId>":"短评"}}],"summary":"...","suggestion":"..."}
规则：
1. cells 的 key 必须是【导师列表】中给出的 professorId，不得新增或编造导师。
2. 维度建议涵盖：研究方向匹配、学校与地区、职称与梯队、招生与培养（以官网为准）、适合人群。
3. 每格 1-2 句、客观中立；不得编造招生名额、联系方式等未提供的事实（用"建议向学校/导师确认"）。
4. summary 概述各导师差异；suggestion 给"若你更看重 X 则倾向 Y"的条件式建议，不下唯一武断结论。
''';
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/data/ai/ai_comparison_repository_test.dart`
Expected: PASS（6 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/data/ai/ai_comparison_repository.dart test/data/ai/ai_comparison_repository_test.dart
git commit -m "feat: AiComparisonRepository (grounded JSON comparison) + tests (M4)"
```

---

## Task 3: MockComparisonRepository

**Files:**
- Create: `lib/data/mock/mock_comparison_repository.dart`
- Test: `test/data/mock/mock_comparison_repository_test.dart`

- [ ] **Step 1: 写失败测试 `test/data/mock/mock_comparison_repository_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_comparison_repository.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';

const _p1 = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
);
const _p3 = Professor(
  id: 'p_003',
  name: '王强',
  university: '北京大学',
  college: '信息科学技术学院',
  title: '教授',
  researchFields: ['自动驾驶'],
);

void main() {
  test('rows 含关键维度，每位导师均有单元格', () async {
    final repo = MockComparisonRepository();
    final res = await repo.compare(professors: [_p1, _p3]);
    final report = (res as Success<ComparisonReport>).data;

    expect(report.professorIds, ['p_001', 'p_003']);
    expect(report.rows.map((r) => r.dimension), contains('研究方向'));
    for (final row in report.rows) {
      expect(row.cells.containsKey('p_001'), isTrue);
      expect(row.cells.containsKey('p_003'), isTrue);
    }
    expect(report.summary, isNotEmpty);
    expect(report.suggestion, isNotEmpty);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/data/mock/mock_comparison_repository_test.dart`
Expected: FAIL（`mock_comparison_repository.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/data/mock/mock_comparison_repository.dart`**

```dart
import '../../core/result/result.dart';
import '../../domain/entities/comparison_report.dart';
import '../../domain/entities/professor.dart';
import '../../domain/repositories/comparison_repository.dart';

/// 离线兜底：按字段拼装对比表（不调用大模型）。
class MockComparisonRepository implements ComparisonRepository {
  @override
  Future<Result<ComparisonReport>> compare({
    required List<Professor> professors,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final ids = professors.map((p) => p.id).toList();
    Map<String, String> cell(String Function(Professor p) f) => {
      for (final p in professors) p.id: f(p),
    };

    final rows = <ComparisonRow>[
      ComparisonRow(
        dimension: '研究方向',
        cells: cell(
          (p) => p.researchFields.isEmpty
              ? '公开资料未明确'
              : p.researchFields.join('、'),
        ),
      ),
      ComparisonRow(
        dimension: '学校与地区',
        cells: cell((p) => '${p.university} / ${p.college}'),
      ),
      ComparisonRow(
        dimension: '职称与梯队',
        cells: cell((p) => p.title),
      ),
      ComparisonRow(
        dimension: '招生与培养',
        cells: cell((p) => '建议以学校官网与导师主页最新说明为准'),
      ),
      ComparisonRow(
        dimension: '适合人群',
        cells: cell(
          (p) => p.researchFields.isEmpty
              ? '对其方向感兴趣的同学'
              : '关注${p.researchFields.first}方向的同学',
        ),
      ),
    ];

    return Success(
      ComparisonReport(
        professorIds: ids,
        rows: rows,
        summary:
            '以上 ${professors.length} 位导师在研究方向与所在院校上各有侧重，'
            '可结合你的兴趣方向与地域偏好综合考虑。',
        suggestion:
            '若你更看重${professors.first.researchFields.isEmpty ? '其研究方向' : professors.first.researchFields.first}，'
            '可优先关注${professors.first.name}${professors.first.title}；'
            '具体仍建议进一步了解各导师的招生与培养情况（本结果为离线示例）。',
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/data/mock/mock_comparison_repository_test.dart`
Expected: PASS（1 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/data/mock/mock_comparison_repository.dart test/data/mock/mock_comparison_repository_test.dart
git commit -m "feat: MockComparisonRepository (template table) + tests (M4)"
```

---

## Task 4: DI 接线

**Files:**
- Modify: `lib/core/di/providers.dart`
- Test: `test/core/di/comparison_repository_provider_test.dart`

- [ ] **Step 1: 在 `lib/core/di/providers.dart` 顶部 import 区追加**

```dart
import '../../data/ai/ai_comparison_repository.dart';
import '../../data/mock/mock_comparison_repository.dart';
import '../../domain/repositories/comparison_repository.dart';
```

- [ ] **Step 2: 在 `chatRepositoryProvider` 之后追加 provider**

```dart

final comparisonRepositoryProvider = Provider<ComparisonRepository>((ref) {
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.mock:
      return MockComparisonRepository();
    case DataSource.ai:
      return AiComparisonRepository(ref.watch(llmClientProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});
```

- [ ] **Step 3: 写接线测试 `test/core/di/comparison_repository_provider_test.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_comparison_repository.dart';
import 'package:scho_navi/data/mock/mock_comparison_repository.dart';

void main() {
  test('默认（mock）接 MockComparisonRepository', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(
      c.read(comparisonRepositoryProvider),
      isA<MockComparisonRepository>(),
    );
  });

  test('dataSource=ai 接 AiComparisonRepository', () {
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(
      c.read(comparisonRepositoryProvider),
      isA<AiComparisonRepository>(),
    );
  });
}
```

> ⚠️ 若 M6 已落地（`appConfigProvider` 改为 `NotifierProvider`，`overrideWithValue` 不再适用），把上面 ai 用例的 override 改为 `initialAppConfigProvider.overrideWithValue(AppConfig.resolve(apiKey: 'sk-test'))`（详见 M6 计划 Task A）。本计划按当前 `Provider<AppConfig>` 编写。

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/core/di/comparison_repository_provider_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/core/di/providers.dart test/core/di/comparison_repository_provider_test.dart
git commit -m "feat: wire comparison repository provider (mock/ai) + tests (M4)"
```

---

## Task 5: CompareNotifier / compare_provider

**Files:**
- Create: `lib/features/compare/providers/compare_provider.dart`
- Test: `test/features/compare/compare_provider_test.dart`

- [ ] **Step 1: 写失败测试 `test/features/compare/compare_provider_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/repositories/comparison_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/features/compare/providers/compare_provider.dart';

class _FakeProfessorRepo implements ProfessorRepository {
  @override
  Future<Result<Professor>> getProfessor(String professorId) async {
    if (professorId == 'missing') return const Failure(NotFoundException());
    return Success(
      Professor(
        id: professorId,
        name: '导师$professorId',
        university: 'U',
        college: 'C',
        title: '教授',
        researchFields: const ['方向'],
      ),
    );
  }
}

class _FakeComparisonRepo implements ComparisonRepository {
  _FakeComparisonRepo(this.response);

  Future<Result<ComparisonReport>> response;
  List<Professor>? lastProfessors;

  @override
  Future<Result<ComparisonReport>> compare({
    required List<Professor> professors,
  }) {
    lastProfessors = professors;
    return response;
  }
}

ComparisonReport _report(List<String> ids) => ComparisonReport(
  professorIds: ids,
  rows: const [
    ComparisonRow(dimension: '研究方向', cells: {}),
  ],
  summary: 's',
  suggestion: 'g',
);

ProviderContainer _container(ComparisonRepository repo) => ProviderContainer(
  overrides: [
    professorRepositoryProvider.overrideWithValue(_FakeProfessorRepo()),
    comparisonRepositoryProvider.overrideWithValue(repo),
  ],
);

void main() {
  test('2 位有效导师 → ready 且携带 report 与 professors', () async {
    final repo = _FakeComparisonRepo(
      Future.value(Success(_report(['p_001', 'p_002']))),
    );
    final c = _container(repo);
    addTearDown(c.dispose);

    await c.read(compareProvider.notifier).load(['p_001', 'p_002']);
    final state = c.read(compareProvider);

    expect(state.status, CompareStatus.ready);
    expect(state.report, isNotNull);
    expect(state.professors.map((p) => p.id).toList(), ['p_001', 'p_002']);
    expect(repo.lastProfessors, hasLength(2));
  });

  test('少于 2 位 → error（不调用对比仓储）', () async {
    final repo = _FakeComparisonRepo(
      Future.value(Success(_report(['p_001']))),
    );
    final c = _container(repo);
    addTearDown(c.dispose);

    await c.read(compareProvider.notifier).load(['p_001']);
    final state = c.read(compareProvider);

    expect(state.status, CompareStatus.error);
    expect(state.message, contains('2-3'));
    expect(repo.lastProfessors, isNull);
  });

  test('多于 3 位 → error', () async {
    final repo = _FakeComparisonRepo(
      Future.value(Success(_report(const []))),
    );
    final c = _container(repo);
    addTearDown(c.dispose);

    await c
        .read(compareProvider.notifier)
        .load(['p_001', 'p_002', 'p_003', 'p_004']);
    expect(c.read(compareProvider).status, CompareStatus.error);
    expect(repo.lastProfessors, isNull);
  });

  test('有效导师不足 2（解析失败被丢弃）→ error', () async {
    final repo = _FakeComparisonRepo(
      Future.value(Success(_report(const []))),
    );
    final c = _container(repo);
    addTearDown(c.dispose);

    await c.read(compareProvider.notifier).load(['p_001', 'missing']);
    expect(c.read(compareProvider).status, CompareStatus.error);
    expect(repo.lastProfessors, isNull);
  });

  test('对比仓储失败 → error 携带文案', () async {
    final repo = _FakeComparisonRepo(
      Future.value(const Failure(ServerException())),
    );
    final c = _container(repo);
    addTearDown(c.dispose);

    await c.read(compareProvider.notifier).load(['p_001', 'p_002']);
    final state = c.read(compareProvider);
    expect(state.status, CompareStatus.error);
    expect(state.message, '服务异常，请稍后重试');
  });

  test('load 期间为 loading', () async {
    final completer = Completer<Result<ComparisonReport>>();
    final c = _container(_FakeComparisonRepo(completer.future));
    addTearDown(c.dispose);

    final future = c.read(compareProvider.notifier).load(['p_001', 'p_002']);
    await Future<void>.delayed(Duration.zero); // 让导师解析完成、进入 compare 等待
    expect(c.read(compareProvider).status, CompareStatus.loading);

    completer.complete(Success(_report(['p_001', 'p_002'])));
    await future;
    expect(c.read(compareProvider).status, CompareStatus.ready);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/compare/compare_provider_test.dart`
Expected: FAIL（`compare_provider.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/features/compare/providers/compare_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/comparison_report.dart';
import '../../../domain/entities/professor.dart';

enum CompareStatus { loading, ready, error }

class CompareState {
  const CompareState({
    required this.status,
    this.professors = const [],
    this.report,
    this.message,
  });

  const CompareState.loading()
    : status = CompareStatus.loading,
      professors = const [],
      report = null,
      message = null;

  final CompareStatus status;
  final List<Professor> professors;
  final ComparisonReport? report;
  final String? message;
}

/// 对比页状态。单屏一次一份对比，故用全局 Notifier + load(ids) 驱动。
class CompareNotifier extends Notifier<CompareState> {
  @override
  CompareState build() => const CompareState.loading();

  Future<void> load(List<String> ids) async {
    state = const CompareState.loading();

    final unique = <String>[];
    for (final id in ids) {
      if (id.isNotEmpty && !unique.contains(id)) unique.add(id);
    }
    if (unique.length < 2 || unique.length > 3) {
      state = const CompareState(
        status: CompareStatus.error,
        message: '请选择 2-3 位导师进行对比',
      );
      return;
    }

    final professorRepo = ref.read(professorRepositoryProvider);
    final professors = <Professor>[];
    for (final id in unique) {
      switch (await professorRepo.getProfessor(id)) {
        case Success(:final data):
          professors.add(data);
        case Failure():
          break; // 接地：解析失败的 id 丢弃
      }
    }
    if (professors.length < 2) {
      state = const CompareState(
        status: CompareStatus.error,
        message: '未能加载足够的导师信息，请返回重试',
      );
      return;
    }

    final res = await ref
        .read(comparisonRepositoryProvider)
        .compare(professors: professors);
    state = switch (res) {
      Success(:final data) => CompareState(
        status: CompareStatus.ready,
        professors: professors,
        report: data,
      ),
      Failure(:final error) => CompareState(
        status: CompareStatus.error,
        professors: professors,
        message: error.message,
      ),
    };
  }
}

final compareProvider = NotifierProvider<CompareNotifier, CompareState>(
  CompareNotifier.new,
);
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/features/compare/compare_provider_test.dart`
Expected: PASS（6 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/features/compare/providers/compare_provider.dart test/features/compare/compare_provider_test.dart
git commit -m "feat: CompareNotifier (resolve 2-3 professors + compare) + tests (M4)"
```

---

## Task 6: ComparePage + 路由

**Files:**
- Create: `lib/features/compare/pages/compare_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/features/compare/compare_page_test.dart`

- [ ] **Step 1: 写失败测试 `test/features/compare/compare_page_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/repositories/comparison_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/features/compare/pages/compare_page.dart';

class _FakeProfessorRepo implements ProfessorRepository {
  @override
  Future<Result<Professor>> getProfessor(String professorId) async => Success(
    Professor(
      id: professorId,
      name: professorId == 'p_001' ? '张三' : '王强',
      university: professorId == 'p_001' ? '上海交通大学' : '北京大学',
      college: 'C',
      title: '教授',
      researchFields: const ['方向'],
    ),
  );
}

class _FakeComparisonRepo implements ComparisonRepository {
  @override
  Future<Result<ComparisonReport>> compare({
    required List<Professor> professors,
  }) async => Success(
    ComparisonReport(
      professorIds: professors.map((p) => p.id).toList(),
      rows: const [
        ComparisonRow(
          dimension: '研究方向',
          cells: {'p_001': '偏医学影像', 'p_003': '偏自动驾驶'},
        ),
      ],
      summary: '两位方向差异明显。',
      suggestion: '若看重医学影像优先张三。',
    ),
  );
}

Widget _wrap() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ComparePage(ids: ['p_001', 'p_003']),
      ),
      GoRoute(
        path: '/professor/:id',
        builder: (_, s) => Text('professor:${s.pathParameters['id']}'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      professorRepositoryProvider.overrideWithValue(_FakeProfessorRepo()),
      comparisonRepositoryProvider.overrideWithValue(_FakeComparisonRepo()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('渲染列头、维度与单元格', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget); // 列头
    expect(find.text('王强'), findsOneWidget);
    expect(find.text('研究方向'), findsOneWidget); // 维度
    expect(find.text('偏医学影像'), findsOneWidget); // 单元格
    expect(find.text('总体小结'), findsOneWidget);
    expect(find.text('选择建议'), findsOneWidget);
  });

  testWidgets('点击列头跳导师详情', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('compare-header-p_001')));
    await tester.pumpAndSettle();

    expect(find.text('professor:p_001'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/compare/compare_page_test.dart`
Expected: FAIL（`compare_page.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/features/compare/pages/compare_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../domain/entities/comparison_report.dart';
import '../../../domain/entities/professor.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../providers/compare_provider.dart';

class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key, required this.ids});

  final List<String> ids;

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(compareProvider.notifier).load(widget.ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(compareProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('导师对比')),
      body: switch (state.status) {
        CompareStatus.loading => const LoadingView(label: '正在生成对比…'),
        CompareStatus.error => ErrorView(
          message: state.message ?? '生成对比失败，请重试',
          onRetry: () => ref.read(compareProvider.notifier).load(widget.ids),
        ),
        CompareStatus.ready => _ReportView(
          professors: state.professors,
          report: state.report!,
        ),
      },
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.professors, required this.report});

  final List<Professor> professors;
  final ComparisonReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final byId = {for (final p in professors) p.id: p};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 列头：各导师姓名/学校，可点进详情
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final id in report.professorIds)
              Expanded(
                child: InkWell(
                  key: Key('compare-header-$id'),
                  onTap: () => context.push('/professor/$id'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          byId[id]?.name ?? id,
                          style: textTheme.titleSmall,
                        ),
                        Text(
                          byId[id]?.university ?? '',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 24),
        // 维度表：每个维度一段，列与列头对齐
        for (final row in report.rows) ...[
          Text(row.dimension, style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final id in report.professorIds)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(row.cells[id] ?? '—'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const Divider(height: 24),
        Text('总体小结', style: textTheme.titleMedium),
        const SizedBox(height: 6),
        GptMarkdown(report.summary),
        const SizedBox(height: 16),
        Text('选择建议', style: textTheme.titleMedium),
        const SizedBox(height: 6),
        GptMarkdown(report.suggestion),
        const SizedBox(height: 16),
        const Text(
          '提示：对比为 AI 生成，招生等信息请以学校官网与导师主页为准。',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行页面测试，确认通过**

Run: `flutter test test/features/compare/compare_page_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 5: 在 `lib/core/router/app_router.dart` 加 `/compare` 路由**

在 import 区加：
```dart
import '../../features/compare/pages/compare_page.dart';
```
在 `/chat` 的 `GoRoute(...)` 之后、`routes:` 列表收尾 `]` 之前追加：
```dart
      GoRoute(
        path: '/compare',
        builder: (_, state) => ComparePage(
          ids: (state.uri.queryParameters['ids'] ?? '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        ),
      ),
```

- [ ] **Step 6: 验证并提交**

Run: `flutter analyze && flutter test test/features/compare/`
Expected: analyze 无 error；compare 目录测试全绿。
```bash
git add lib/features/compare/pages/compare_page.dart lib/core/router/app_router.dart test/features/compare/compare_page_test.dart
git commit -m "feat: ComparePage + /compare route (M4)"
```

---

## Task 7: 收藏页多选「对比」入口

**Files:**
- Modify: `lib/features/favorite/pages/favorite_page.dart`
- Test: `test/features/compare/compare_entry_point_test.dart`

- [ ] **Step 1: 写失败测试 `test/features/compare/compare_entry_point_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/favorite_item.dart';
import 'package:scho_navi/features/favorite/pages/favorite_page.dart';

FavoriteItem _fav(String id, String name) => FavoriteItem(
  professorId: id,
  name: name,
  university: 'U',
  college: 'C',
  title: '教授',
  researchFields: const ['方向'],
  favoritedAt: DateTime(2026, 6, 8, 10),
);

void main() {
  testWidgets('多选 2 位 → 生成对比跳 /compare?ids=', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const FavoritePage()),
        GoRoute(
          path: '/compare',
          builder: (_, s) => Text('compare:${s.uri.queryParameters['ids']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesProvider.overrideWith(
            (ref) => Stream.value([_fav('p_001', '张三'), _fav('p_002', '李娜')]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // 进入多选模式
    await tester.tap(find.byIcon(Icons.compare_arrows));
    await tester.pumpAndSettle();

    // 勾选两位
    await tester.tap(find.text('张三'));
    await tester.tap(find.text('李娜'));
    await tester.pumpAndSettle();

    // 生成对比
    await tester.tap(find.text('生成对比 (2)'));
    await tester.pumpAndSettle();

    expect(find.text('compare:p_001,p_002'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/compare/compare_entry_point_test.dart`
Expected: FAIL（收藏页还没有多选模式）。

- [ ] **Step 3: 用以下完整内容替换 `lib/features/favorite/pages/favorite_page.dart`**

> 改动要点：`FavoritePage` 由 `ConsumerWidget` 改 `ConsumerStatefulWidget`，新增多选状态；**非多选模式行为与原文件完全一致**（点卡片跳详情、取消收藏、访问主页），故既有 5 个 `favorite_page_test` 仍通过。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../domain/entities/favorite_item.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/field_chips.dart';
import '../../../shared/widgets/loading_view.dart';

class FavoritePage extends ConsumerStatefulWidget {
  const FavoritePage({super.key});

  @override
  ConsumerState<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends ConsumerState<FavoritePage> {
  bool _selecting = false;
  final Set<String> _selected = {};

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
  }

  void _toggleSelect(String professorId) {
    setState(() {
      if (_selected.contains(professorId)) {
        _selected.remove(professorId);
      } else if (_selected.length < 3) {
        _selected.add(professorId);
      }
    });
  }

  void _generateCompare() {
    if (_selected.length < 2 || _selected.length > 3) return;
    context.push('/compare?ids=${_selected.join(',')}');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoritesProvider);
    final canCompare = _selected.length >= 2 && _selected.length <= 3;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? '选择 2-3 位对比' : '收藏'),
        actions: [
          async.maybeWhen(
            data: (items) => items.length >= 2
                ? IconButton(
                    tooltip: _selecting ? '退出多选' : '对比导师',
                    icon: Icon(
                      _selecting ? Icons.close : Icons.compare_arrows,
                    ),
                    onPressed: _toggleSelecting,
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: _selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: canCompare ? _generateCompare : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text('生成对比 (${_selected.length})'),
                ),
              ),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const EmptyView(message: '收藏读取失败，可稍后重试'),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(message: '还没有收藏导师');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _FavoriteTile(
                item: item,
                selecting: _selecting,
                selected: _selected.contains(item.professorId),
                onToggleSelect: () => _toggleSelect(item.professorId),
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({
    required this.item,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
  });

  final FavoriteItem item;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: selecting
            ? onToggleSelect
            : () => context.push('/professor/${item.professorId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selecting)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${item.university} / ${item.college}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!selecting)
                    IconButton(
                      tooltip: '取消收藏',
                      icon: const Icon(Icons.bookmark_remove_outlined),
                      onPressed: () => ref
                          .read(favoriteRepositoryProvider)
                          .remove(item.professorId),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FieldChips(fields: item.researchFields),
              const SizedBox(height: 8),
              Text(
                '收藏时间：${_formatDateTime(item.favoritedAt)}',
                style: textTheme.bodySmall,
              ),
              if (!selecting) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _openHomepage(context, ref, item.homepageUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('访问主页'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHomepage(
    BuildContext context,
    WidgetRef ref,
    String? url,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(linkLauncherProvider).open(url);
    switch (result) {
      case LaunchResult.success:
        return;
      case LaunchResult.noUrl:
        messenger.showSnackBar(const SnackBar(content: Text('暂无主页信息')));
      case LaunchResult.failed:
        messenger.showSnackBar(
          const SnackBar(content: Text('主页可能已失效，可通过学校官网确认')),
        );
    }
  }
}

String _formatDateTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
```

- [ ] **Step 4: 运行入口测试，确认通过**

Run: `flutter test test/features/compare/compare_entry_point_test.dart`
Expected: PASS（1 个）。

- [ ] **Step 5: 运行既有收藏页测试，确认不回归**

Run: `flutter test test/features/favorite/favorite_page_test.dart`
Expected: PASS（5 个，非多选模式行为不变）。

- [ ] **Step 6: 提交**

```bash
git add lib/features/favorite/pages/favorite_page.dart test/features/compare/compare_entry_point_test.dart
git commit -m "feat: favorites multi-select compare entry → /compare (M4)"
```

---

## Task 8: 收尾全量验证 + 人工冒烟

**Files:** 无（仅验证）

- [ ] **Step 1: 全量分析与测试**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全部 PASS——既有 + 本里程碑新增（实体 1、AI 6、Mock 1、DI 2、provider 6、page 2、entry 1 = 19）。

- [ ] **Step 2: 确认工作区干净**

Run: `git status --short`
Expected: 干净（除可能的 `.agents/` 等非本任务文件）。

- [ ] **Step 3: 人工冒烟（需真实 key）**

Run（替换为真实 key）：
```bash
flutter run --dart-define=LLM_API_KEY=sk-你的key
```
手动核对：
- 收藏至少 2 位导师 → 收藏页右上「对比」图标 → 进入多选 → 勾选 2-3 位（第 4 位无法再选）→「生成对比 (n)」可点。
- 对比页：loading → 列头为各导师姓名/学校；维度表按列对齐；「总体小结」「选择建议」为模型生成（条件式建议、不武断）；事实只涉及所选导师。
- 点列头 → 跳对应导师详情。
- 关 key 直接 `flutter run` → `mock`：模板对比表含各导师方向/学校（离线演示安全）。
- 断网或填错 key → 错误态 + 重试。

> 本里程碑解锁：推荐结果页多选入口可作为后续增强（复用 `/compare`）；M5 背景匹配、M6 打磨与作品说明。

---

## 自查（Self-Review）记录

- **Spec 覆盖**（M4 spec §2–§7）：
  - §2 模型 `ComparisonRow`/`ComparisonReport` → Task 1。
  - §3 接口 + 两实现：`ComparisonRepository` → Task 1；`AiComparisonRepository`（接地、丢弃未知 key）→ Task 2；`MockComparisonRepository` → Task 3。
  - §4 交互流程（收藏页多选 2-3 → `/compare?ids=` → 列头/维度表/小结/建议、列点详情；`features/compare/`）→ Task 5/6/7。
  - §5 Prompt（system 规则含维度/接地/条件式建议 + user 拼导师列表）→ Task 2 `_systemPrompt`/`_userPrompt`。
  - §6 DI `comparisonRepositoryProvider`（mock/ai/http 三分支）→ Task 4。
  - §7 测试 6 类全部落位：ai_comparison（T2）、mock_comparison（T3）、compare_provider（T5）、compare_page（T6）、compare_entry_point（T7）、comparison_repository_provider（T4）。
  - §8 偏差（提前到 M4、限 2-3、不持久化、入口以收藏页为主）→ 已在「与 spec 的偏差」记录。
- **占位扫描**：无 TBD/TODO；每个 code step 给出完整可编译代码 + 命令与期望。
- **类型一致性**：
  - `ComparisonRepository.compare({required List<Professor> professors}) → Future<Result<ComparisonReport>>` 在接口(T1)、Ai(T2)、Mock(T3)、各 fake(T5/T6) 一致。
  - `ComparisonReport{professorIds:List<String>, rows:List<ComparisonRow>, summary:String, suggestion:String}`、`ComparisonRow{dimension:String, cells:Map<String,String>}` 全文件一致。
  - `CompareNotifier.load(List<String>)`、`CompareState{status, professors, report, message}`、`CompareStatus{loading, ready, error}` 在 provider(T5)、page(T6)、测试一致；page `switch` 覆盖 3 个枚举值（穷尽）。
  - `LlmClient` 假实现同时实现 `complete` 与 `stream`（M2 已落地，见前置条件）。
  - `professorRepositoryProvider`（`getProfessor(String)→Future<Result<Professor>>`）、`comparisonRepositoryProvider`、`favoritesProvider`（`StreamProvider<List<FavoriteItem>>`）、`favoriteRepositoryProvider` 均为既有，用法与现有代码一致。
- **接线/路由**：`/compare?ids=` 路由(T6 Step5) 解析逗号分隔 ids；收藏页多选入口(T7) + 入口测试(T7 Step1)；DI 三分支覆盖 `DataSource`(T4)。
- **不回归**：仅新增文件 + 在 `providers.dart`/`app_router.dart` 追加；收藏页改造保持非多选模式行为不变（既有 5 个 `favorite_page_test` 仍绿，T7 Step5 验证）；默认 `mock`。Task 8 跑全量回归。
- **Widget 测试要点**：`compare_page_test` 以 `find.text` 断言列头/维度/单元格（纯 `Text`），不断言 `GptMarkdown` 内部富文本；列头点击用 `Key('compare-header-<id>')`；`compare_entry_point_test` 用 `favoritesProvider.overrideWith(Stream.value([...]))` 注入收藏，避免依赖 `SharedPreferences`。
- **M6 耦合留痕**：`comparison_repository_provider_test` 的 ai 用例 override 在 M6 落地后需改用 `initialAppConfigProvider`（已在 Task 4 Step3 注明）。
