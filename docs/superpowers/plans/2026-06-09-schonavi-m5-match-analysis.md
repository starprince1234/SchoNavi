# SchoNavi M5 · 背景匹配分析 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在导师详情页输入【学生背景】+ 选定【某导师】，大模型生成**匹配分析报告**：总体概述 + 匹配点 + 差距/短板 + 可执行准备建议；**明确不预测录取概率**，UI 顶部带免责提示。接地（导师事实取自 `Professor`、学生信息只用 `UserProfile`，不编造），离线 mock 兜底。

**Architecture:** 新增领域模型 `MatchAnalysis`，复用 M3 的 `UserProfile`/`ProfileRepository`（无新本地模型）。新增仓储接口 `MatchAnalysisRepository`（远程类，走 `Result`）；`AiMatchAnalysisRepository` 用 M1 的 `LlmClient.complete(jsonMode:true)` 产出 `{summary, strengths[], gaps[], suggestions[]}`；`MockMatchAnalysisRepository` 模板拼装。新增 feature 目录 `features/match/`（`match_page` + `match_provider`），路由 `/match?pid=<professorId>`，详情页加「匹配分析」入口。DI 加 `matchAnalysisRepositoryProvider`。

**Tech Stack:** Flutter 3.44 / Dart 3.12；`flutter_riverpod ^3.3.1`（手写 provider）；`go_router ^17.3.0`；M1 的 `LlmClient`（`dio`）。无新依赖。

**Spec 依据:** `docs/superpowers/specs/2026-06-09-schonavi-m5-match-analysis-design.md`。

---

## ⚠️ 前置依赖（M3，务必先读）

**M5 复用 M3 引入的本地学生档案，但 M3 当前尚未实现**（仓库无 `lib/features/email/`、无 `UserProfile`/`ProfileRepository`）。M5 依赖以下 M3 产物：

| M3 产物 | 来源（M3 计划） | M5 用途 |
|---|---|---|
| `lib/domain/entities/user_profile.dart`（`UserProfile` + `isEmpty`） | M3 Task 1 | 学生背景入参 |
| `lib/domain/repositories/profile_repository.dart`（`ProfileRepository{load()→UserProfile, save(UserProfile)→Future<void>}`） | M3 Task 1 | 读/存背景 |
| `lib/data/local/local_profile_repository.dart`（`LocalProfileRepository`） | M3 Task 2 | DI 已接 `profileRepositoryProvider` |
| `lib/core/di/providers.dart` 的 `profileRepositoryProvider` | M3 Task 5 | M5 直接 `ref.read` |
| `lib/features/email/widgets/profile_sheet.dart`（`showProfileSheet(BuildContext, UserProfile)→Future<UserProfile?>`） | M3 Task 7 | 背景为空时复用填写 sheet |

**实施前置检查（本计划 Task 0）**：若上述文件不存在，**先实现 M3 的 Task 1、Task 2、Task 5（profile 部分）、Task 7 的 `profile_sheet.dart`**（见 `docs/superpowers/plans/2026-06-09-schonavi-m3-outreach-email.md`），再开始 M5。建议按 roadmap **M3 先于 M5** 落地。

**`UserProfile` 字段（M3 定义，本计划引用）**：`name?`、`degreeStage?`、`school?`、`major?`、`researchInterests:List<String>`、`highlights?`；`isEmpty` 在全空时为真。

**前置条件（已核实落地）:** M1 已实现（`LlmClient.complete(jsonMode:…)` + `stream`、`DataSource.ai|mock` DI 切换、`professorProvider`=`FutureProvider.family<Professor,String>`）；M2 流式已实现（`LlmClient` 含 `stream`，故任何 `LlmClient` 假实现须**同时**实现 `complete` 与 `stream`）。`flutter test` 全绿，分支 `iter1`。

**与 spec 的偏差/本计划另定:**
- **不预测录取概率**（spec §8.1）：仅信息性分析，UI 顶部固定免责提示。
- 复用 M3 `UserProfile`（spec §8.2）；不做简历解析自动填背景（spec §8.3）。
- 详情页入口为正文内按钮（与 M3「生成套磁邮件」并列；若 M3 未落地则单独作为详情页首个按钮）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/domain/entities/match_analysis.dart` | 新：`MatchAnalysis`（四部分） |
| `lib/domain/repositories/match_analysis_repository.dart` | 新：`MatchAnalysisRepository`（Result） |
| `lib/data/ai/ai_match_analysis_repository.dart` | 新：接地 JSON 匹配分析 |
| `lib/data/mock/mock_match_analysis_repository.dart` | 新：模板拼装 |
| `lib/core/di/providers.dart` | **改**：加 `matchAnalysisRepositoryProvider` |
| `lib/features/match/providers/match_provider.dart` | 新：`MatchNotifier` + `MatchState` |
| `lib/features/match/pages/match_page.dart` | 新：免责提示 + 三段列表 + 重新生成 |
| `lib/core/router/app_router.dart` | **改**：加 `/match` 路由 |
| `lib/features/professor/pages/professor_page.dart` | **改**：详情页加「匹配分析」入口 |
| `test/domain/entities/match_analysis_test.dart` | 实体构造 |
| `test/data/ai/ai_match_analysis_repository_test.dart` | 解析四部分 / jsonMode / prompt 含导师方向与 profile / 坏 JSON / 失败透传 |
| `test/data/mock/mock_match_analysis_repository_test.dart` | strengths/gaps/suggestions 非空 |
| `test/core/di/match_analysis_repository_provider_test.dart` | 默认 mock + ai 接线 |
| `test/features/match/match_provider_test.dart` | loading / ready / error / 重新生成 / start 重置 |
| `test/features/match/match_page_test.dart` | 三段渲染 + 免责提示 + 重新生成 |
| `test/features/match/match_entry_point_test.dart` | 详情页按钮跳 `/match?pid=` |

> 不改 domain 既有实体、其它 feature、mock 数据。既有测试默认 `mock`，须保持全绿。

---

## Task 0: 前置检查（M3 profile 依赖）

**Files:** 无（仅核查）

- [ ] **Step 1: 确认 M3 profile 产物已存在**

Run: `ls lib/domain/entities/user_profile.dart lib/domain/repositories/profile_repository.dart lib/data/local/local_profile_repository.dart lib/features/email/widgets/profile_sheet.dart`
Expected: 四个文件均存在。

- [ ] **Step 2: 确认 `profileRepositoryProvider` 已接线**

Run: `flutter test test/core/di/outreach_email_provider_test.dart`
Expected: PASS（M3 Task 5 的接线测试，含 `profileRepositoryProvider` → `LocalProfileRepository`）。

> 若上述缺失：先按 `docs/superpowers/plans/2026-06-09-schonavi-m3-outreach-email.md` 实现 M3 的 Task 1、Task 2、Task 5、Task 7 的 `profile_sheet.dart`，再继续 M5。**不要在 M5 内重复定义 `UserProfile`/`ProfileRepository`/`showProfileSheet`。**

---

## Task 1: 领域模型 + 仓储接口

**Files:**
- Create: `lib/domain/entities/match_analysis.dart`
- Create: `lib/domain/repositories/match_analysis_repository.dart`
- Test: `test/domain/entities/match_analysis_test.dart`

- [ ] **Step 1: 写失败测试 `test/domain/entities/match_analysis_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';

void main() {
  test('MatchAnalysis 保存四部分', () {
    const a = MatchAnalysis(
      professorId: 'p_001',
      summary: '方向较契合。',
      strengths: ['研究方向一致'],
      gaps: ['缺少相关论文'],
      suggestions: ['补读该方向综述'],
    );
    expect(a.professorId, 'p_001');
    expect(a.summary, isNotEmpty);
    expect(a.strengths, ['研究方向一致']);
    expect(a.gaps, ['缺少相关论文']);
    expect(a.suggestions, ['补读该方向综述']);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/domain/entities/match_analysis_test.dart`
Expected: FAIL（`match_analysis.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/domain/entities/match_analysis.dart`**

```dart
/// 导师-学生背景匹配分析（信息性，非录取概率预测）。
class MatchAnalysis {
  const MatchAnalysis({
    required this.professorId,
    required this.summary,
    required this.strengths,
    required this.gaps,
    required this.suggestions,
  });

  final String professorId;
  final String summary; // 总体匹配概述（非概率）
  final List<String> strengths; // 你的匹配点
  final List<String> gaps; // 差距/短板
  final List<String> suggestions; // 可执行准备建议
}
```

- [ ] **Step 4: 实现 `lib/domain/repositories/match_analysis_repository.dart`**

```dart
import '../../core/result/result.dart';
import '../entities/match_analysis.dart';
import '../entities/professor.dart';
import '../entities/user_profile.dart';

/// 导师-背景匹配分析（远程类，走 Result）。
abstract interface class MatchAnalysisRepository {
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  });
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/domain/entities/match_analysis_test.dart`
Expected: PASS（1 个）。

- [ ] **Step 6: 提交**

```bash
git add lib/domain/entities/match_analysis.dart lib/domain/repositories/match_analysis_repository.dart test/domain/entities/match_analysis_test.dart
git commit -m "feat: add MatchAnalysis entity + MatchAnalysisRepository (M5)"
```

---

## Task 2: AiMatchAnalysisRepository

**Files:**
- Create: `lib/data/ai/ai_match_analysis_repository.dart`
- Test: `test/data/ai/ai_match_analysis_repository_test.dart`

- [ ] **Step 1: 写失败测试 `test/data/ai/ai_match_analysis_repository_test.dart`**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_match_analysis_repository.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

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
  }) => throw UnimplementedError(); // 匹配分析不流式，桩即可
}

const _prof = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
  bio: '研究医学影像。',
);

String _validJson() => jsonEncode({
  'summary': '你的方向与该导师较契合。',
  'strengths': ['研究兴趣与医学影像一致'],
  'gaps': ['暂无相关论文'],
  'suggestions': ['补读医学影像综述'],
});

void main() {
  test('解析 summary/strengths/gaps/suggestions，且用 JSON 模式', () async {
    final llm = _FakeLlm(Success(_validJson()));
    final repo = AiMatchAnalysisRepository(llm);
    final res = await repo.analyze(
      professor: _prof,
      profile: const UserProfile(name: '李四', researchInterests: ['医学影像']),
    );
    final a = (res as Success<MatchAnalysis>).data;
    expect(a.professorId, 'p_001');
    expect(a.summary, contains('契合'));
    expect(a.strengths, isNotEmpty);
    expect(a.gaps, isNotEmpty);
    expect(a.suggestions, isNotEmpty);
    expect(llm.lastJsonMode, isTrue);
  });

  test('接地：prompt 含导师方向与学生已填字段，未填字段不出现', () async {
    final llm = _FakeLlm(Success(_validJson()));
    await AiMatchAnalysisRepository(llm).analyze(
      professor: _prof,
      profile: const UserProfile(name: '李四', researchInterests: ['医学影像']),
    );
    final userMsg = llm.lastMessages!.last.content;
    expect(userMsg, contains('医学影像')); // 导师方向 + 学生兴趣
    expect(userMsg, contains('李四'));
    expect(userMsg.contains('highlights'), isFalse); // 未填则不出现
  });

  test('坏 JSON → Failure(ServerException)', () async {
    final repo = AiMatchAnalysisRepository(const _FakeLlm(Success('not json')));
    final res = await repo.analyze(
      professor: _prof,
      profile: const UserProfile(),
    );
    expect((res as Failure).error, isA<ServerException>());
  });

  test('缺 summary → Failure(ServerException)', () async {
    final repo = AiMatchAnalysisRepository(
      _FakeLlm(Success(jsonEncode({'strengths': [], 'gaps': [], 'suggestions': []}))),
    );
    final res = await repo.analyze(
      professor: _prof,
      profile: const UserProfile(),
    );
    expect((res as Failure).error, isA<ServerException>());
  });

  test('LlmClient 失败透传', () async {
    final repo = AiMatchAnalysisRepository(
      const _FakeLlm(Failure(NetworkException())),
    );
    final res = await repo.analyze(
      professor: _prof,
      profile: const UserProfile(),
    );
    expect((res as Failure).error, isA<NetworkException>());
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/data/ai/ai_match_analysis_repository_test.dart`
Expected: FAIL（`ai_match_analysis_repository.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/data/ai/ai_match_analysis_repository.dart`**

```dart
import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/match_analysis.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/match_analysis_repository.dart';

/// 用大模型据【导师】+【学生背景】生成匹配分析 JSON。导师/学生事实只用传入数据，不编造；
/// 严禁给录取概率或"一定能/不能"的结论。
class AiMatchAnalysisRepository implements MatchAnalysisRepository {
  const AiMatchAnalysisRepository(this.llm);

  final LlmClient llm;

  @override
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  }) async {
    final res = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(professor, profile)),
      ],
      jsonMode: true,
      temperature: 0.4,
    );
    switch (res) {
      case Failure(:final error):
        return Failure(error);
      case Success(:final data):
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final summary = (json['summary'] as String?)?.trim();
          if (summary == null || summary.isEmpty) {
            return const Failure(ServerException());
          }
          return Success(
            MatchAnalysis(
              professorId: professor.id,
              summary: summary,
              strengths: _strs(json['strengths']),
              gaps: _strs(json['gaps']),
              suggestions: _strs(json['suggestions']),
            ),
          );
        } catch (_) {
          return const Failure(ServerException());
        }
    }
  }

  List<String> _strs(dynamic v) => (v as List? ?? const [])
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String _userPrompt(Professor p, UserProfile u) {
    final professor = {
      'name': p.name,
      'title': p.title,
      'university': p.university,
      'college': p.college,
      'researchFields': p.researchFields,
      if (p.bio != null) 'bio': p.bio,
    };
    final student = {
      if (u.name != null) 'name': u.name,
      if (u.degreeStage != null) 'degreeStage': u.degreeStage,
      if (u.school != null) 'school': u.school,
      if (u.major != null) 'major': u.major,
      if (u.researchInterests.isNotEmpty) 'researchInterests': u.researchInterests,
      if (u.highlights != null) 'highlights': u.highlights,
    };
    return '【导师】${jsonEncode(professor)}\n【学生背景】${jsonEncode(student)}';
  }

  static const String _systemPrompt = '''
你是帮学生做"导师-背景匹配分析"的助手。根据【导师】与【学生背景】输出一个 JSON 对象（json），不要 Markdown 或多余文字：
{"summary":"...","strengths":["..."],"gaps":["..."],"suggestions":["..."]}
规则：
1. strengths：学生与该导师方向/要求的契合点（只基于已提供信息）。
2. gaps：可能的短板；信息缺失则写"建议补充X"，不臆测学生未提供的经历。
3. suggestions：具体可执行的准备（如补哪类基础、读哪方向论文、准备什么材料）。
4. summary：客观概述匹配情况，**严禁给出录取概率或"一定能/不能"的结论**。
5. 不得编造导师或学生未提供的任何事实。
''';
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/data/ai/ai_match_analysis_repository_test.dart`
Expected: PASS（5 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/data/ai/ai_match_analysis_repository.dart test/data/ai/ai_match_analysis_repository_test.dart
git commit -m "feat: AiMatchAnalysisRepository (grounded JSON, non-probability) + tests (M5)"
```

---

## Task 3: MockMatchAnalysisRepository

**Files:**
- Create: `lib/data/mock/mock_match_analysis_repository.dart`
- Test: `test/data/mock/mock_match_analysis_repository_test.dart`

- [ ] **Step 1: 写失败测试 `test/data/mock/mock_match_analysis_repository_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_match_analysis_repository.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

const _prof = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
);

void main() {
  test('三段非空，summary 含导师方向，professorId 回填', () async {
    final repo = MockMatchAnalysisRepository();
    final res = await repo.analyze(
      professor: _prof,
      profile: const UserProfile(name: '李四', researchInterests: ['医学影像']),
    );
    final a = (res as Success<MatchAnalysis>).data;
    expect(a.professorId, 'p_001');
    expect(a.strengths, isNotEmpty);
    expect(a.gaps, isNotEmpty);
    expect(a.suggestions, isNotEmpty);
    expect(a.summary, contains('医学影像'));
  });

  test('学生信息为空也能生成（gaps 提示补充背景）', () async {
    final repo = MockMatchAnalysisRepository();
    final res = await repo.analyze(
      professor: _prof,
      profile: const UserProfile(),
    );
    final a = (res as Success<MatchAnalysis>).data;
    expect(a.gaps, isNotEmpty);
    expect(a.summary, isNotEmpty);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/data/mock/mock_match_analysis_repository_test.dart`
Expected: FAIL（`mock_match_analysis_repository.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/data/mock/mock_match_analysis_repository.dart`**

```dart
import '../../core/result/result.dart';
import '../../domain/entities/match_analysis.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/match_analysis_repository.dart';

/// 离线兜底：模板拼装匹配分析（不调用大模型）。
class MockMatchAnalysisRepository implements MatchAnalysisRepository {
  @override
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final fields = professor.researchFields.isEmpty
        ? '其研究方向'
        : professor.researchFields.join('、');
    final overlap = profile.researchInterests
        .where(professor.researchFields.contains)
        .toList();

    final strengths = <String>[
      if (overlap.isNotEmpty)
        '你的研究兴趣（${overlap.join('、')}）与导师方向重合'
      else
        '你对$fields方向有兴趣，可作为切入点',
      if (profile.major != null) '专业背景（${profile.major}）与方向相关',
    ];

    final gaps = <String>[
      if (profile.researchInterests.isEmpty) '建议补充你的研究兴趣，便于更精准匹配',
      if (profile.highlights == null) '建议补充科研/项目经历，以评估与导师课题的契合度',
      if (strengths.length < 2) '可进一步了解$fields方向的细分课题',
    ];

    return Success(
      MatchAnalysis(
        professorId: professor.id,
        summary:
            '${professor.name}${professor.title}主要研究$fields。'
            '结合你已提供的背景，整体方向有一定契合度，以下为信息性分析（非录取预测）。',
        strengths: strengths.isEmpty ? ['对导师方向有兴趣'] : strengths,
        gaps: gaps.isEmpty ? ['建议进一步明确目标课题方向'] : gaps,
        suggestions: <String>[
          '阅读导师近年代表论文，了解$fields的具体问题',
          '梳理与该方向相关的课程/项目，准备一页研究兴趣说明',
          '通过套磁邮件或学校官网了解招生与培养要求',
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/data/mock/mock_match_analysis_repository_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/data/mock/mock_match_analysis_repository.dart test/data/mock/mock_match_analysis_repository_test.dart
git commit -m "feat: MockMatchAnalysisRepository (template) + tests (M5)"
```

---

## Task 4: DI 接线

**Files:**
- Modify: `lib/core/di/providers.dart`
- Test: `test/core/di/match_analysis_repository_provider_test.dart`

- [ ] **Step 1: 在 `lib/core/di/providers.dart` 顶部 import 区追加**

```dart
import '../../data/ai/ai_match_analysis_repository.dart';
import '../../data/mock/mock_match_analysis_repository.dart';
import '../../domain/repositories/match_analysis_repository.dart';
```

- [ ] **Step 2: 在 `chatRepositoryProvider` 之后追加 provider**

```dart

final matchAnalysisRepositoryProvider = Provider<MatchAnalysisRepository>((ref) {
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.mock:
      return MockMatchAnalysisRepository();
    case DataSource.ai:
      return AiMatchAnalysisRepository(ref.watch(llmClientProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});
```

- [ ] **Step 3: 写接线测试 `test/core/di/match_analysis_repository_provider_test.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_match_analysis_repository.dart';
import 'package:scho_navi/data/mock/mock_match_analysis_repository.dart';

void main() {
  test('默认（mock）接 MockMatchAnalysisRepository', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(
      c.read(matchAnalysisRepositoryProvider),
      isA<MockMatchAnalysisRepository>(),
    );
  });

  test('dataSource=ai 接 AiMatchAnalysisRepository', () {
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(
      c.read(matchAnalysisRepositoryProvider),
      isA<AiMatchAnalysisRepository>(),
    );
  });
}
```

> ⚠️ 若 M6 已落地（`appConfigProvider` 改 `NotifierProvider`），把 ai 用例 override 改为 `initialAppConfigProvider.overrideWithValue(AppConfig.resolve(apiKey: 'sk-test'))`（见 M6 计划 Task A）。

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/core/di/match_analysis_repository_provider_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/core/di/providers.dart test/core/di/match_analysis_repository_provider_test.dart
git commit -m "feat: wire match analysis repository provider (mock/ai) + tests (M5)"
```

---

## Task 5: MatchNotifier / match_provider

**Files:**
- Create: `lib/features/match/providers/match_provider.dart`
- Test: `test/features/match/match_provider_test.dart`

- [ ] **Step 1: 写失败测试 `test/features/match/match_provider_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/match_analysis_repository.dart';
import 'package:scho_navi/features/match/providers/match_provider.dart';

class _FakeRepo implements MatchAnalysisRepository {
  _FakeRepo(this.response);

  Future<Result<MatchAnalysis>> response;
  int calls = 0;
  Professor? lastProfessor;
  UserProfile? lastProfile;

  @override
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  }) {
    calls++;
    lastProfessor = professor;
    lastProfile = profile;
    return response;
  }
}

const _prof = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像'],
);
const _profile = UserProfile(name: '李四');
const _analysis = MatchAnalysis(
  professorId: 'p_001',
  summary: 's',
  strengths: ['a'],
  gaps: ['b'],
  suggestions: ['c'],
);

ProviderContainer _container(MatchAnalysisRepository repo) => ProviderContainer(
  overrides: [matchAnalysisRepositoryProvider.overrideWithValue(repo)],
);

void main() {
  test('analyze 成功 → ready 携带 analysis + 透传入参', () async {
    final repo = _FakeRepo(Future.value(const Success(_analysis)));
    final c = _container(repo);
    addTearDown(c.dispose);

    await c
        .read(matchProvider.notifier)
        .analyze(professor: _prof, profile: _profile);
    final state = c.read(matchProvider);

    expect(state.status, MatchStatus.ready);
    expect(state.analysis?.summary, 's');
    expect(repo.lastProfessor?.id, 'p_001');
    expect(repo.lastProfile?.name, '李四');
  });

  test('analyze 失败 → error 携带文案', () async {
    final c = _container(_FakeRepo(Future.value(const Failure(ServerException()))));
    addTearDown(c.dispose);

    await c
        .read(matchProvider.notifier)
        .analyze(professor: _prof, profile: _profile);
    final state = c.read(matchProvider);

    expect(state.status, MatchStatus.error);
    expect(state.message, '服务异常，请稍后重试');
  });

  test('analyze 期间为 analyzing', () async {
    final completer = Completer<Result<MatchAnalysis>>();
    final c = _container(_FakeRepo(completer.future));
    addTearDown(c.dispose);

    final future = c
        .read(matchProvider.notifier)
        .analyze(professor: _prof, profile: _profile);
    expect(c.read(matchProvider).status, MatchStatus.analyzing);

    completer.complete(const Success(_analysis));
    await future;
    expect(c.read(matchProvider).status, MatchStatus.ready);
  });

  test('重新生成：再次调用仓储', () async {
    final repo = _FakeRepo(Future.value(const Success(_analysis)));
    final c = _container(repo);
    addTearDown(c.dispose);
    final notifier = c.read(matchProvider.notifier);

    await notifier.analyze(professor: _prof, profile: _profile);
    await notifier.analyze(professor: _prof, profile: _profile);
    expect(repo.calls, 2);
  });

  test('start 切换 professor 时重置为 idle', () async {
    final repo = _FakeRepo(Future.value(const Success(_analysis)));
    final c = _container(repo);
    addTearDown(c.dispose);
    final notifier = c.read(matchProvider.notifier);

    notifier.start('p_001');
    await notifier.analyze(professor: _prof, profile: _profile);
    expect(c.read(matchProvider).status, MatchStatus.ready);

    notifier.start('p_002');
    expect(c.read(matchProvider).status, MatchStatus.idle);
    expect(c.read(matchProvider).analysis, isNull);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/match/match_provider_test.dart`
Expected: FAIL（`match_provider.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/features/match/providers/match_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/match_analysis.dart';
import '../../../domain/entities/professor.dart';
import '../../../domain/entities/user_profile.dart';

enum MatchStatus { idle, analyzing, ready, error }

/// 匹配分析页状态。单屏一次一份分析，故用全局 Notifier + start 注入/重置。
class MatchState {
  const MatchState({
    required this.professorId,
    required this.status,
    this.analysis,
    this.message,
  });

  const MatchState.initial()
    : professorId = null,
      status = MatchStatus.idle,
      analysis = null,
      message = null;

  final String? professorId;
  final MatchStatus status;
  final MatchAnalysis? analysis;
  final String? message;
}

class MatchNotifier extends Notifier<MatchState> {
  @override
  MatchState build() => const MatchState.initial();

  /// 进入某导师匹配页：切换导师时重置，避免上一个导师的分析残留。
  void start(String professorId) {
    if (state.professorId == professorId) return;
    state = MatchState(professorId: professorId, status: MatchStatus.idle);
  }

  Future<void> analyze({
    required Professor professor,
    required UserProfile profile,
  }) async {
    final pid = state.professorId ?? professor.id;
    state = MatchState(professorId: pid, status: MatchStatus.analyzing);
    final res = await ref
        .read(matchAnalysisRepositoryProvider)
        .analyze(professor: professor, profile: profile);
    state = switch (res) {
      Success(:final data) => MatchState(
        professorId: pid,
        status: MatchStatus.ready,
        analysis: data,
      ),
      Failure(:final error) => MatchState(
        professorId: pid,
        status: MatchStatus.error,
        message: error.message,
      ),
    };
  }
}

final matchProvider = NotifierProvider<MatchNotifier, MatchState>(
  MatchNotifier.new,
);
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/features/match/match_provider_test.dart`
Expected: PASS（5 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/features/match/providers/match_provider.dart test/features/match/match_provider_test.dart
git commit -m "feat: MatchNotifier (analyze/start/states) + tests (M5)"
```

---

## Task 6: MatchPage + 路由 + 详情页入口

**Files:**
- Create: `lib/features/match/pages/match_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/professor/pages/professor_page.dart`
- Test: `test/features/match/match_page_test.dart`
- Test: `test/features/match/match_entry_point_test.dart`

- [ ] **Step 1: 写失败测试 `test/features/match/match_page_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/match_analysis.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/match_analysis_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/match/pages/match_page.dart';

const _professor = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像'],
);

class _FakeProfessorRepo implements ProfessorRepository {
  @override
  Future<Result<Professor>> getProfessor(String professorId) async =>
      const Success(_professor);
}

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo(this._profile);
  UserProfile _profile;

  @override
  UserProfile load() => _profile;

  @override
  Future<void> save(UserProfile profile) async => _profile = profile;
}

class _FakeMatchRepo implements MatchAnalysisRepository {
  _FakeMatchRepo(this.analysis);
  final MatchAnalysis analysis;
  int calls = 0;

  @override
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  }) async {
    calls++;
    return Success(analysis);
  }
}

Widget _wrap(_FakeProfileRepo profileRepo, _FakeMatchRepo matchRepo) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const MatchPage(professorId: 'p_001'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      professorRepositoryProvider.overrideWithValue(_FakeProfessorRepo()),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      matchAnalysisRepositoryProvider.overrideWithValue(matchRepo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('生成后显示三段 + 免责提示', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final matchRepo = _FakeMatchRepo(
      const MatchAnalysis(
        professorId: 'p_001',
        summary: '方向较契合。',
        strengths: ['研究方向一致'],
        gaps: ['缺少论文'],
        suggestions: ['补读综述'],
      ),
    );
    await tester.pumpWidget(_wrap(profileRepo, matchRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始匹配分析'));
    await tester.pumpAndSettle();

    expect(find.textContaining('仅供参考'), findsOneWidget); // 免责
    expect(find.text('匹配点'), findsOneWidget);
    expect(find.text('差距与短板'), findsOneWidget);
    expect(find.text('准备建议'), findsOneWidget);
    expect(find.text('研究方向一致'), findsOneWidget);
    expect(find.text('缺少论文'), findsOneWidget);
    expect(find.text('补读综述'), findsOneWidget);
  });

  testWidgets('重新生成再次调用仓储', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final matchRepo = _FakeMatchRepo(
      const MatchAnalysis(
        professorId: 'p_001',
        summary: 's',
        strengths: ['a'],
        gaps: ['b'],
        suggestions: ['c'],
      ),
    );
    await tester.pumpWidget(_wrap(profileRepo, matchRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始匹配分析'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新生成'));
    await tester.pumpAndSettle();

    expect(matchRepo.calls, 2);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/match/match_page_test.dart`
Expected: FAIL（`match_page.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/features/match/pages/match_page.dart`**

> 复用 M3 的 `showProfileSheet`（背景为空时弹出填写并存本地）。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/match_analysis.dart';
import '../../../domain/entities/professor.dart';
import '../../../features/email/widgets/profile_sheet.dart';
import '../../../features/professor/providers/professor_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../providers/match_provider.dart';

class MatchPage extends ConsumerStatefulWidget {
  const MatchPage({super.key, required this.professorId});

  final String professorId;

  @override
  ConsumerState<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends ConsumerState<MatchPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(matchProvider.notifier).start(widget.professorId);
    });
  }

  Future<void> _analyze(Professor professor) async {
    var profile = ref.read(profileRepositoryProvider).load();
    if (profile.isEmpty) {
      final edited = await showProfileSheet(context, profile);
      if (edited == null) return; // 用户取消
      await ref.read(profileRepositoryProvider).save(edited);
      profile = edited;
    }
    await ref
        .read(matchProvider.notifier)
        .analyze(professor: professor, profile: profile);
  }

  @override
  Widget build(BuildContext context) {
    final professorAsync = ref.watch(professorProvider(widget.professorId));
    final match = ref.watch(matchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('匹配分析')),
      body: professorAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : '出错了，请稍后重试',
          onRetry: () => ref.invalidate(professorProvider(widget.professorId)),
        ),
        data: (professor) => _buildBody(professor, match),
      ),
    );
  }

  Widget _buildBody(Professor professor, MatchState match) {
    switch (match.status) {
      case MatchStatus.idle:
        return _IdlePrompt(
          professor: professor,
          onAnalyze: () => _analyze(professor),
        );
      case MatchStatus.analyzing:
        return const LoadingView(label: '正在分析匹配度…');
      case MatchStatus.error:
        return ErrorView(
          message: match.message ?? '分析失败，请重试',
          onRetry: () => _analyze(professor),
        );
      case MatchStatus.ready:
        return _AnalysisView(
          analysis: match.analysis!,
          onRegenerate: () => _analyze(professor),
        );
    }
  }
}

class _IdlePrompt extends StatelessWidget {
  const _IdlePrompt({required this.professor, required this.onAnalyze});

  final Professor professor;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              '分析你与 ${professor.name}${professor.title} 的匹配度',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '将结合导师研究方向与你的背景，给出匹配点、差距与准备建议（信息性，非录取预测）。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('开始匹配分析'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisView extends StatelessWidget {
  const _AnalysisView({required this.analysis, required this.onRegenerate});

  final MatchAnalysis analysis;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('本分析仅供参考，不预测录取概率，请结合实际情况判断。'),
          ),
        ),
        const SizedBox(height: 12),
        Text('总体匹配', style: textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(analysis.summary),
        const SizedBox(height: 16),
        _Section(
          icon: Icons.check_circle_outline,
          title: '匹配点',
          items: analysis.strengths,
        ),
        _Section(
          icon: Icons.report_problem_outlined,
          title: '差距与短板',
          items: analysis.gaps,
        ),
        _Section(
          icon: Icons.lightbulb_outline,
          title: '准备建议',
          items: analysis.suggestions,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRegenerate,
          icon: const Icon(Icons.refresh),
          label: const Text('重新生成'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.items});

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 6),
              Text(title, style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text('暂无')
          else
            ...items.map(
              (x) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $x'),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行页面测试，确认通过**

Run: `flutter test test/features/match/match_page_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 5: 在 `lib/core/router/app_router.dart` 加 `/match` 路由**

在 import 区加：
```dart
import '../../features/match/pages/match_page.dart';
```
在 `/chat` 的 `GoRoute(...)` 之后、`routes:` 列表收尾 `]` 之前追加（若 M4 已加 `/compare`，置其后亦可）：
```dart
      GoRoute(
        path: '/match',
        builder: (_, state) =>
            MatchPage(professorId: state.uri.queryParameters['pid'] ?? ''),
      ),
```

- [ ] **Step 6: 写失败测试 `test/features/match/match_entry_point_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/professor/pages/professor_page.dart';

void main() {
  testWidgets('详情页「匹配分析」跳 /match?pid=', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ProfessorPage(professorId: 'p_001'),
        ),
        GoRoute(
          path: '/match',
          builder: (_, s) => Text('match:${s.uri.queryParameters['pid']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('匹配分析'));
    await tester.pumpAndSettle();

    expect(find.text('match:p_001'), findsOneWidget);
  });
}
```

- [ ] **Step 7: 运行测试，确认失败**

Run: `flutter test test/features/match/match_entry_point_test.dart`
Expected: FAIL（详情页还没有「匹配分析」按钮）。

- [ ] **Step 8: 在 `lib/features/professor/pages/professor_page.dart` 的 `_Detail` 加入口按钮**

把 `_Detail.build` 里：
```dart
        Text('${p.university} / ${p.college}', style: textTheme.bodyMedium),
        const Divider(height: 28),
```
替换为：
```dart
        Text('${p.university} / ${p.college}', style: textTheme.bodyMedium),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                context.push('/match?pid=${Uri.encodeComponent(p.id)}'),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('匹配分析'),
          ),
        ),
        const Divider(height: 28),
```
（`context`、`go_router` 已在该文件可用，无需新增 import。若 M3「生成套磁邮件」按钮已在此处，则把本按钮并列其后，保留两者。）

- [ ] **Step 9: 运行入口测试，确认通过**

Run: `flutter test test/features/match/match_entry_point_test.dart`
Expected: PASS（1 个）。

- [ ] **Step 10: 验证并提交**

Run: `flutter analyze && flutter test test/features/match/`
Expected: analyze 无 error；match 目录测试全绿。
```bash
git add lib/features/match/pages/match_page.dart lib/core/router/app_router.dart lib/features/professor/pages/professor_page.dart test/features/match/match_page_test.dart test/features/match/match_entry_point_test.dart
git commit -m "feat: match page + /match route + detail entry (M5)"
```

---

## Task 7: 收尾全量验证 + 人工冒烟

**Files:** 无（仅验证）

- [ ] **Step 1: 全量分析与测试**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全部 PASS——既有 + 本里程碑新增（实体 1、AI 5、Mock 2、DI 2、provider 5、page 2、entry 1 = 18）。

- [ ] **Step 2: 确认工作区干净**

Run: `git status --short`
Expected: 干净（除可能的 `.agents/` 等非本任务文件）。

- [ ] **Step 3: 人工冒烟（需真实 key）**

Run（替换为真实 key）：
```bash
flutter run --dart-define=LLM_API_KEY=sk-你的key
```
手动核对：
- 进任一导师详情页 → 点「匹配分析」→ 若背景为空，弹 M3 背景填写 sheet（填后保存复用）。
- loading → 分析报告页：顶部**免责提示**「仅供参考，不预测录取概率」；总体匹配 + 三段（匹配点 / 差距 / 准备建议）；内容结合该导师方向、只用我填的背景（无编造经历、无录取概率结论）。
- 「重新生成」→ 产出新版本。
- 与 M3 套磁邮件复用同一 `UserProfile`（在套磁页保存过背景，匹配页不再弹首次 sheet）。
- 关 key 直接 `flutter run` → `mock`：模板分析含导师方向 + gaps 提示补充背景（离线演示安全）。
- 断网或填错 key → 错误态 + 重试。

> 本里程碑解锁：M6 打磨与作品说明（把"匹配分析"列入大模型应用能力清单与演示动线）。

---

## 自查（Self-Review）记录

- **Spec 覆盖**（M5 spec §2–§7）：
  - §2 模型 `MatchAnalysis`（四部分）→ Task 1；复用 M3 `UserProfile`/`ProfileRepository`（Task 0 前置核查）。
  - §3 接口 + 两实现：`MatchAnalysisRepository` → Task 1；`AiMatchAnalysisRepository`（接地、非概率）→ Task 2；`MockMatchAnalysisRepository` → Task 3。
  - §4 交互流程（详情页「匹配分析」→ 背景空则复用 M3 sheet → loading → summary + 三段 + 免责；`features/match/`；`/match?pid=`）→ Task 5/6。
  - §5 Prompt（system 规则含 strengths/gaps/suggestions/禁录取概率 + user 拼导师/学生）→ Task 2 `_systemPrompt`/`_userPrompt`。
  - §6 DI `matchAnalysisRepositoryProvider`（mock/ai/http 三分支）→ Task 4。
  - §7 测试 6 类全部落位：ai_match_analysis（T2）、mock_match_analysis（T3）、match_provider（T5）、match_page（T6）、match_entry_point（T6）、match_analysis_repository_provider（T4）。
  - §8 偏差（不预测概率、复用 M3、不做简历解析）→ 已在「与 spec 的偏差」与前置依赖记录。
- **占位扫描**：无 TBD/TODO；每个 code step 给出完整可编译代码 + 命令与期望。
- **类型一致性**：
  - `MatchAnalysisRepository.analyze({required Professor professor, required UserProfile profile}) → Future<Result<MatchAnalysis>>` 在接口(T1)、Ai(T2)、Mock(T3)、各 fake(T5/T6) 一致。
  - `MatchAnalysis{professorId, summary, strengths, gaps, suggestions}` 全文件一致。
  - `MatchNotifier.start(String)`、`analyze({required Professor, required UserProfile})`、`MatchState{professorId, status, analysis, message}`、`MatchStatus{idle, analyzing, ready, error}` 在 provider(T5)、page(T6)、测试一致；page `switch` 覆盖 4 个枚举值（穷尽）。
  - `LlmClient` 假实现同时实现 `complete` 与 `stream`（M2 已落地）。
  - 复用 M3 的 `UserProfile{name?,degreeStage?,school?,major?,researchInterests,highlights?,isEmpty}`、`ProfileRepository{load()→UserProfile, save(UserProfile)→Future<void>}`、`profileRepositoryProvider`、`showProfileSheet(BuildContext, UserProfile)→Future<UserProfile?>`（Task 0 前置核查其存在）。
  - `professorProvider`（`FutureProvider.family<Professor,String>`）、`professorRepositoryProvider`、`appConfigProvider` 均为既有。
- **接线/路由**：`/match?pid=` 路由(T6 Step5) + 详情页 `OutlinedButton`(T6 Step8) + 入口测试(T6 Step6)；DI 三分支覆盖 `DataSource`(T4)。
- **不回归**：仅新增文件 + 在 `providers.dart`/`app_router.dart`/`professor_page.dart` 追加；详情页 FAB「继续追问」保留；默认 `mock`。Task 7 跑全量回归。
- **Widget 测试要点**：`match_page_test` 预置非空 `UserProfile` 跳过首次 sheet，直接测三段 + 免责 + 重新生成；用 `find.textContaining('仅供参考')` 匹配免责文案。
- **M6 耦合留痕**：`match_analysis_repository_provider_test` 的 ai 用例 override 在 M6 落地后需改用 `initialAppConfigProvider`（已在 Task 4 Step3 注明）。
- **M3 依赖留痕**：M5 不重复定义 profile 相关类型；Task 0 强制前置核查，缺失则先做 M3 profile 部分。
