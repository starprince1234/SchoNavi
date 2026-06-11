# SchoNavi 个人档案引擎（数据模型 + AI 抽取 + 推荐注入）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把结构化个人档案 + AI 成果抽取接入领域/数据层，并让推荐主链路读取档案（背景感知推荐）——纯逻辑层，全部单测可验，零 UI。

**Architecture:** 沿用既有分层（domain 接口 + data 实现 + Riverpod 手写 provider）。**数据 vs 分析**：导师事实仍来自本地 `MockDb`；成果抽取为**分析类、仅 AI 实现**（用 `_FakeLlm` 测）。推荐接口加性加 `UserProfile? profile`，空档案行为不变。新增响应式 `profileProvider`，`recommendationProvider` watch 之。

**Tech Stack:** Dart / Flutter，flutter_riverpod 3.2.1（手写 provider），sealed `Result`，`LlmClient.complete(jsonMode:true)`，flutter_test。

**对应 spec：** `docs/superpowers/specs/2026-06-11-schonavi-profile-personalization-design.md` 的 Phase A/B/C。本计划完成后另有「计划② 界面（D/E/F）」覆盖向导/中心/组件。

**全程约定：** 每个 Task 先写失败测试 → 跑红 → 最小实现 → 跑绿 → commit。命令 `flutter test <路径>`、`flutter analyze` 全程应绿。

---

## 文件结构（本计划新增/改动）

**新增**
- `lib/domain/entities/academic_score.dart` — GPA 值对象（gpa/scale/rank + toJson/fromJson）。
- `lib/domain/entities/competition.dart` — 竞赛条目值对象。
- `lib/domain/entities/research_item.dart` — 科研条目值对象（含 `ResearchType`）。
- `lib/domain/repositories/profile_extraction_repository.dart` — 抽取接口 + `AchievementDraft`。
- `lib/data/ai/ai_profile_extraction_repository.dart` — AI 抽取实现（仅此一个实现）。
- `lib/features/profile/providers/profile_provider.dart` — 全局 `profileProvider`（NotifierProvider）。
- 测试：`test/data/ai/ai_profile_extraction_repository_test.dart`、`test/features/profile/profile_provider_test.dart`、`test/core/di/profile_extraction_provider_test.dart`。

**改动**
- `lib/domain/entities/user_profile.dart` — 加 `gender`/`targetDegree`/`score`/`competitions`/`research`，加 `copyWith`/`completion`，扩展 `isEmpty`（含 `Gender` 枚举）。
- `lib/data/local/local_profile_repository.dart` — 新字段序列化/反序列化（向后兼容旧 JSON）。
- `lib/domain/repositories/recommendation_repository.dart` — `getRecommendations` 加 `UserProfile? profile`。
- `lib/data/ai/ai_recommendation_repository.dart` — 注入档案到 prompt + 系统提示词规则。
- `lib/data/mock/mock_recommendation_repository.dart` — 加 `profile` 形参（忽略）。
- `lib/core/di/providers.dart` — 加 `profileExtractionRepositoryProvider`。
- `lib/features/recommendation/providers/recommendation_provider.dart` — watch `profileProvider` 并传 `profile`。
- 测试迁移：`test/data/local/local_profile_repository_test.dart`、`test/data/ai/ai_recommendation_repository_test.dart`、`test/features/recommendation/recommendation_provider_test.dart`、`test/features/recommendation/recommendation_page_test.dart`（若其假仓储实现了接口）。

---

## Phase A · 数据模型

### Task A1：成果值对象（AcademicScore / Competition / ResearchItem）

**Files:**
- Create: `lib/domain/entities/academic_score.dart`
- Create: `lib/domain/entities/competition.dart`
- Create: `lib/domain/entities/research_item.dart`

- [ ] **Step 1：创建 `academic_score.dart`**

```dart
/// 学业成绩：GPA + 量纲 + 排名（均可空）。
class AcademicScore {
  const AcademicScore({this.gpa, this.scale, this.rank});

  final double? gpa; // 例 3.8
  final double? scale; // 量纲：4.0 / 4.3 / 4.5 / 5.0 / 100
  final String? rank; // 自由文本，例 "前 5%"、"3/120"

  bool get isEmpty =>
      gpa == null && scale == null && (rank == null || rank!.isEmpty);

  Map<String, dynamic> toJson() => {
    if (gpa != null) 'gpa': gpa,
    if (scale != null) 'scale': scale,
    if (rank != null && rank!.isNotEmpty) 'rank': rank,
  };

  factory AcademicScore.fromJson(Map<String, dynamic> json) {
    final rank = (json['rank'] as String?)?.trim();
    return AcademicScore(
      gpa: (json['gpa'] as num?)?.toDouble(),
      scale: (json['scale'] as num?)?.toDouble(),
      rank: rank == null || rank.isEmpty ? null : rank,
    );
  }
}
```

- [ ] **Step 2：创建 `competition.dart`**

```dart
/// 竞赛成果条目。仅 name 必填，其余可空（缺失 UI 显示「暂无信息」）。
class Competition {
  const Competition({required this.name, this.level, this.award, this.year});

  final String name; // 例 "ACM-ICPC 区域赛"
  final String? level; // 国际 / 国家级 / 省级 / 校级
  final String? award; // 例 "银牌"、"一等奖"
  final String? year; // 自由文本，例 "2024"

  Map<String, dynamic> toJson() => {
    'name': name,
    if (level != null) 'level': level,
    if (award != null) 'award': award,
    if (year != null) 'year': year,
  };

  factory Competition.fromJson(Map<String, dynamic> json) => Competition(
    name: (json['name'] as String?)?.trim() ?? '',
    level: _str(json['level']),
    award: _str(json['award']),
    year: _str(json['year']),
  );

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
}
```

- [ ] **Step 3：创建 `research_item.dart`**

```dart
enum ResearchType { paper, project, patent, other }

ResearchType researchTypeFromString(String? raw) => switch (raw?.trim()) {
  'paper' || '论文' => ResearchType.paper,
  'project' || '项目' => ResearchType.project,
  'patent' || '专利' => ResearchType.patent,
  _ => ResearchType.other,
};

/// 科研成果条目（论文/项目/专利）。仅 title 必填。
class ResearchItem {
  const ResearchItem({
    required this.type,
    required this.title,
    this.role,
    this.venueOrStatus,
    this.year,
  });

  final ResearchType type;
  final String title;
  final String? role; // 例 "第一作者"、"项目负责人"
  final String? venueOrStatus; // 例 "EI 会议 / 已发表 / 在投"
  final String? year;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    if (role != null) 'role': role,
    if (venueOrStatus != null) 'venueOrStatus': venueOrStatus,
    if (year != null) 'year': year,
  };

  factory ResearchItem.fromJson(Map<String, dynamic> json) => ResearchItem(
    type: researchTypeFromString(json['type'] as String?),
    title: (json['title'] as String?)?.trim() ?? '',
    role: _str(json['role']),
    venueOrStatus: _str(json['venueOrStatus']),
    year: _str(json['year']),
  );

  static String? _str(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
}
```

- [ ] **Step 4：跑 analyze 确认无语法错误**

Run: `flutter analyze lib/domain/entities/academic_score.dart lib/domain/entities/competition.dart lib/domain/entities/research_item.dart`
Expected: No issues found.

- [ ] **Step 5：Commit**

```bash
git add lib/domain/entities/academic_score.dart lib/domain/entities/competition.dart lib/domain/entities/research_item.dart
git commit -m "feat(profile): add AcademicScore/Competition/ResearchItem value objects"
```

---

### Task A2：扩展 UserProfile（字段 + copyWith + completion + isEmpty）

**Files:**
- Modify: `lib/domain/entities/user_profile.dart`
- Test: `test/domain/entities/user_profile_test.dart`（新建）

- [ ] **Step 1：写失败测试 `test/domain/entities/user_profile_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';
import 'package:scho_navi/domain/entities/competition.dart';
import 'package:scho_navi/domain/entities/research_item.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

void main() {
  test('空 profile isEmpty 为 true', () {
    expect(const UserProfile().isEmpty, isTrue);
  });

  test('任一新字段非空则 isEmpty 为 false', () {
    expect(const UserProfile(gender: Gender.female).isEmpty, isFalse);
    expect(
      const UserProfile(competitions: [Competition(name: 'ACM')]).isEmpty,
      isFalse,
    );
  });

  test('completion 按 7 项命中率计算', () {
    expect(const UserProfile().completion, 0.0);

    const full = UserProfile(
      name: '张三',
      gender: Gender.male,
      school: '上海交通大学',
      major: '计算机',
      targetDegree: '申请硕士',
      score: AcademicScore(gpa: 3.8, scale: 4.0),
      researchInterests: ['人工智能'],
      competitions: [Competition(name: 'ACM 区域赛')],
    );
    expect(full.completion, 1.0);

    // 仅命中 name + gender = 2/7
    const partial = UserProfile(name: '张三', gender: Gender.male);
    expect(partial.completion, closeTo(2 / 7, 1e-9));
  });

  test('copyWith 覆盖指定字段、保留其余', () {
    const base = UserProfile(name: '张三', gender: Gender.male);
    final next = base.copyWith(
      targetDegree: '申请博士',
      research: const [ResearchItem(type: ResearchType.paper, title: 'X')],
    );
    expect(next.name, '张三');
    expect(next.gender, Gender.male);
    expect(next.targetDegree, '申请博士');
    expect(next.research, hasLength(1));
  });
}
```

- [ ] **Step 2：跑测试确认失败**

Run: `flutter test test/domain/entities/user_profile_test.dart`
Expected: 编译错误（`Gender`/新字段/`completion`/`copyWith` 未定义）。

- [ ] **Step 3：重写 `lib/domain/entities/user_profile.dart`**

```dart
import 'academic_score.dart';
import 'competition.dart';
import 'research_item.dart';

enum Gender { male, female, other, undisclosed }

/// 学生背景。本地持久化；推荐/套磁/匹配共用。
class UserProfile {
  const UserProfile({
    this.name,
    this.degreeStage,
    this.school,
    this.major,
    this.researchInterests = const [],
    this.highlights,
    this.gender,
    this.targetDegree,
    this.score,
    this.competitions = const [],
    this.research = const [],
  });

  final String? name;
  final String? degreeStage; // 当前阶段
  final String? school;
  final String? major;
  final List<String> researchInterests;
  final String? highlights;

  final Gender? gender;
  final String? targetDegree; // 目标阶段：申请硕士 / 申请博士
  final AcademicScore? score;
  final List<Competition> competitions;
  final List<ResearchItem> research;

  bool get isEmpty =>
      _blank(name) &&
      _blank(degreeStage) &&
      _blank(school) &&
      _blank(major) &&
      researchInterests.isEmpty &&
      _blank(highlights) &&
      gender == null &&
      _blank(targetDegree) &&
      (score == null || score!.isEmpty) &&
      competitions.isEmpty &&
      research.isEmpty;

  /// 完成度 0.0–1.0：7 项命中率（中心页进度环）。
  double get completion {
    var hit = 0;
    if (!_blank(name)) hit++;
    if (gender != null) hit++;
    if (!_blank(school) && !_blank(major)) hit++;
    if (!_blank(targetDegree)) hit++;
    if (score?.gpa != null) hit++;
    if (researchInterests.isNotEmpty) hit++;
    if (competitions.isNotEmpty || research.isNotEmpty) hit++;
    return hit / 7;
  }

  UserProfile copyWith({
    String? name,
    String? degreeStage,
    String? school,
    String? major,
    List<String>? researchInterests,
    String? highlights,
    Gender? gender,
    String? targetDegree,
    AcademicScore? score,
    List<Competition>? competitions,
    List<ResearchItem>? research,
  }) => UserProfile(
    name: name ?? this.name,
    degreeStage: degreeStage ?? this.degreeStage,
    school: school ?? this.school,
    major: major ?? this.major,
    researchInterests: researchInterests ?? this.researchInterests,
    highlights: highlights ?? this.highlights,
    gender: gender ?? this.gender,
    targetDegree: targetDegree ?? this.targetDegree,
    score: score ?? this.score,
    competitions: competitions ?? this.competitions,
    research: research ?? this.research,
  );

  static bool _blank(String? value) => value == null || value.isEmpty;
}
```

- [ ] **Step 4：跑测试确认通过**

Run: `flutter test test/domain/entities/user_profile_test.dart`
Expected: All tests passed.

- [ ] **Step 5：Commit**

```bash
git add lib/domain/entities/user_profile.dart test/domain/entities/user_profile_test.dart
git commit -m "feat(profile): extend UserProfile with gender/targetDegree/score/achievements + completion + copyWith"
```

---

### Task A3：LocalProfileRepository 序列化新字段（向后兼容）

**Files:**
- Modify: `lib/data/local/local_profile_repository.dart`
- Test: `test/data/local/local_profile_repository_test.dart`（追加用例）

- [ ] **Step 1：在测试文件追加用例**

在 `test/data/local/local_profile_repository_test.dart` 的 `main()` 末尾、最后一个 `test(...)` 之后插入：

```dart
  test('新字段（性别/成绩/竞赛/科研）往返', () async {
    await repo.save(
      const UserProfile(
        name: '王五',
        gender: Gender.female,
        targetDegree: '申请博士',
        score: AcademicScore(gpa: 3.8, scale: 4.0, rank: '前 5%'),
        competitions: [
          Competition(name: 'ACM 区域赛', level: '国家级', award: '银牌', year: '2024'),
        ],
        research: [
          ResearchItem(
            type: ResearchType.paper,
            title: '深度学习用于医学影像',
            role: '第一作者',
            venueOrStatus: 'EI 会议 / 已发表',
            year: '2024',
          ),
        ],
      ),
    );

    final p = repo.load();
    expect(p.gender, Gender.female);
    expect(p.targetDegree, '申请博士');
    expect(p.score?.gpa, 3.8);
    expect(p.score?.scale, 4.0);
    expect(p.score?.rank, '前 5%');
    expect(p.competitions.single.award, '银牌');
    expect(p.research.single.type, ResearchType.paper);
    expect(p.research.single.role, '第一作者');
  });

  test('旧版仅含基础字段的 JSON 仍可加载（向后兼容）', () async {
    // 直接写入旧结构（无新字段）
    await prefs.setString(
      LocalProfileRepository.storageKey,
      '{"name":"老用户","school":"清华大学","research_interests":["人工智能"]}',
    );
    repo = LocalProfileRepository(SharedPreferencesLocalStore(prefs));

    final p = repo.load();
    expect(p.name, '老用户');
    expect(p.school, '清华大学');
    expect(p.researchInterests, ['人工智能']);
    expect(p.gender, isNull);
    expect(p.score, isNull);
    expect(p.competitions, isEmpty);
  });
```

并把测试顶部 `setUp` 的 `prefs` 提升为可见变量：将 `setUp` 改为

```dart
  late LocalProfileRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    repo = LocalProfileRepository(SharedPreferencesLocalStore(prefs));
  });
```

并补充 import：

```dart
import 'package:scho_navi/domain/entities/academic_score.dart';
import 'package:scho_navi/domain/entities/competition.dart';
import 'package:scho_navi/domain/entities/research_item.dart';
```

- [ ] **Step 2：跑测试确认失败**

Run: `flutter test test/data/local/local_profile_repository_test.dart`
Expected: 新用例失败（新字段未持久化）。

- [ ] **Step 3：重写 `lib/data/local/local_profile_repository.dart`**

```dart
import '../../core/storage/local_store.dart';
import '../../domain/entities/academic_score.dart';
import '../../domain/entities/competition.dart';
import '../../domain/entities/research_item.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// 经 [LocalStore] 以单个 JSON 对象存取学生背景（加性扩展，旧 JSON 兼容）。
class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._store);

  static const String storageKey = 'user_profile.v1';

  final LocalStore _store;

  @override
  UserProfile load() {
    final json = _store.getJson(storageKey);
    if (json == null) return const UserProfile();
    final scoreJson = json['score'];
    return UserProfile(
      name: _str(json['name']),
      degreeStage: _str(json['degree_stage']),
      school: _str(json['school']),
      major: _str(json['major']),
      researchInterests:
          (json['research_interests'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(),
      highlights: _str(json['highlights']),
      gender: _genderFrom(json['gender'] as String?),
      targetDegree: _str(json['target_degree']),
      score: scoreJson is Map<String, dynamic>
          ? AcademicScore.fromJson(scoreJson)
          : null,
      competitions: _list(json['competitions'], Competition.fromJson),
      research: _list(json['research'], ResearchItem.fromJson),
    );
  }

  @override
  Future<void> save(UserProfile profile) => _store.setJson(storageKey, {
    if (profile.name != null) 'name': profile.name,
    if (profile.degreeStage != null) 'degree_stage': profile.degreeStage,
    if (profile.school != null) 'school': profile.school,
    if (profile.major != null) 'major': profile.major,
    'research_interests': profile.researchInterests,
    if (profile.highlights != null) 'highlights': profile.highlights,
    if (profile.gender != null) 'gender': profile.gender!.name,
    if (profile.targetDegree != null) 'target_degree': profile.targetDegree,
    if (profile.score != null && !profile.score!.isEmpty)
      'score': profile.score!.toJson(),
    if (profile.competitions.isNotEmpty)
      'competitions': [for (final c in profile.competitions) c.toJson()],
    if (profile.research.isNotEmpty)
      'research': [for (final r in profile.research) r.toJson()],
  });

  String? _str(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  Gender? _genderFrom(String? raw) {
    for (final g in Gender.values) {
      if (g.name == raw) return g;
    }
    return null;
  }

  List<T> _list<T>(
    Object? value,
    T Function(Map<String, dynamic>) from,
  ) =>
      (value as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(from)
          .toList();
}
```

- [ ] **Step 4：跑测试确认通过**

Run: `flutter test test/data/local/local_profile_repository_test.dart`
Expected: All tests passed.

- [ ] **Step 5：Commit**

```bash
git add lib/data/local/local_profile_repository.dart test/data/local/local_profile_repository_test.dart
git commit -m "feat(profile): persist new profile fields with backward-compatible load"
```

---

## Phase B · AI 成果抽取

### Task B1：抽取接口 ProfileExtractionRepository + AchievementDraft

**Files:**
- Create: `lib/domain/repositories/profile_extraction_repository.dart`

- [ ] **Step 1：创建接口文件**

```dart
import '../../core/result/result.dart';
import '../entities/competition.dart';
import '../entities/research_item.dart';

/// 自由文本 → 结构化成果条目（分析类，仅 AI 实现）。
class AchievementDraft {
  const AchievementDraft({this.competitions = const [], this.research = const []});

  final List<Competition> competitions;
  final List<ResearchItem> research;
}

abstract interface class ProfileExtractionRepository {
  Future<Result<AchievementDraft>> extract({required String rawText});
}
```

- [ ] **Step 2：analyze 确认无误**

Run: `flutter analyze lib/domain/repositories/profile_extraction_repository.dart`
Expected: No issues found.

- [ ] **Step 3：Commit**

```bash
git add lib/domain/repositories/profile_extraction_repository.dart
git commit -m "feat(profile): add ProfileExtractionRepository interface + AchievementDraft"
```

---

### Task B2：AiProfileExtractionRepository（解析 + 接地提示词）

**Files:**
- Create: `lib/data/ai/ai_profile_extraction_repository.dart`
- Test: `test/data/ai/ai_profile_extraction_repository_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_profile_extraction_repository.dart';
import 'package:scho_navi/domain/entities/research_item.dart';

class _FakeLlm implements LlmClient {
  _FakeLlm(this._result);

  final Result<String> _result;
  bool? lastJsonMode;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    lastJsonMode = jsonMode;
    return _result;
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
}

void main() {
  test('解析竞赛与科研条目', () async {
    final content = jsonEncode({
      'competitions': [
        {'name': 'ACM-ICPC 区域赛', 'level': '国家级', 'award': '银牌', 'year': '2024'},
      ],
      'research': [
        {
          'type': 'paper',
          'title': '深度学习用于医学影像',
          'role': '第一作者',
          'venueOrStatus': 'EI 会议 / 已发表',
          'year': '2024',
        },
      ],
    });
    final repo = AiProfileExtractionRepository(_FakeLlm(Success(content)));

    final draft = (await repo.extract(rawText: '随便一段自述') as Success).data;

    expect(draft.competitions.single.name, 'ACM-ICPC 区域赛');
    expect(draft.competitions.single.award, '银牌');
    expect(draft.research.single.type, ResearchType.paper);
    expect(draft.research.single.role, '第一作者');
  });

  test('使用 JSON 模式', () async {
    final fake = _FakeLlm(const Success('{"competitions":[],"research":[]}'));
    await AiProfileExtractionRepository(fake).extract(rawText: 'x');
    expect(fake.lastJsonMode, isTrue);
  });

  test('丢弃缺名竞赛/缺标题科研', () async {
    final content = jsonEncode({
      'competitions': [
        {'level': '省级'},
        {'name': '挑战杯', 'award': '一等奖'},
      ],
      'research': [
        {'type': 'project', 'role': '负责人'},
      ],
    });
    final repo = AiProfileExtractionRepository(_FakeLlm(Success(content)));

    final draft = (await repo.extract(rawText: 'x') as Success).data;

    expect(draft.competitions.map((c) => c.name), ['挑战杯']);
    expect(draft.research, isEmpty);
  });

  test('坏 JSON 返回 ServerException', () async {
    final repo = AiProfileExtractionRepository(_FakeLlm(const Success('not json')));
    final res = await repo.extract(rawText: 'x');
    expect((res as Failure).error, isA<ServerException>());
  });

  test('LLM 失败透传', () async {
    final repo =
        AiProfileExtractionRepository(_FakeLlm(const Failure(NetworkException())));
    final res = await repo.extract(rawText: 'x');
    expect((res as Failure).error, isA<NetworkException>());
  });
}
```

- [ ] **Step 2：跑测试确认失败**

Run: `flutter test test/data/ai/ai_profile_extraction_repository_test.dart`
Expected: 编译错误（`AiProfileExtractionRepository` 未定义）。

- [ ] **Step 3：实现 `lib/data/ai/ai_profile_extraction_repository.dart`**

```dart
import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/competition.dart';
import '../../domain/entities/research_item.dart';
import '../../domain/repositories/profile_extraction_repository.dart';

/// 用大模型把学生自述抽取为结构化成果条目（接地、不编造）。
class AiProfileExtractionRepository implements ProfileExtractionRepository {
  const AiProfileExtractionRepository(this.llm);

  final LlmClient llm;

  @override
  Future<Result<AchievementDraft>> extract({required String rawText}) async {
    final result = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', '【学生自述】$rawText'),
      ],
      jsonMode: true,
      temperature: 0.2,
    );

    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final data) => _parse(data),
    };
  }

  Result<AchievementDraft> _parse(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(ServerException());
      }
      return Success(
        AchievementDraft(
          competitions: _competitions(decoded['competitions']),
          research: _research(decoded['research']),
        ),
      );
    } catch (_) {
      return const Failure(ServerException());
    }
  }

  List<Competition> _competitions(Object? value) {
    final list = value as List? ?? const [];
    final out = <Competition>[];
    for (final item in list) {
      if (item is! Map) continue;
      final c = Competition.fromJson(Map<String, dynamic>.from(item));
      if (c.name.isEmpty) continue; // 缺名丢弃
      out.add(c);
    }
    return out;
  }

  List<ResearchItem> _research(Object? value) {
    final list = value as List? ?? const [];
    final out = <ResearchItem>[];
    for (final item in list) {
      if (item is! Map) continue;
      final r = ResearchItem.fromJson(Map<String, dynamic>.from(item));
      if (r.title.isEmpty) continue; // 缺标题丢弃
      out.add(r);
    }
    return out;
  }

  static const String _systemPrompt = '''
你是把学生自述整理为结构化成果的助手。仅依据【学生自述】抽取，**不得编造**未提及的奖项、论文、项目。只输出一个 JSON 对象，不要 Markdown 或多余文字：
{"competitions":[{"name":"","level":"","award":"","year":""}],"research":[{"type":"paper","title":"","role":"","venueOrStatus":"","year":""}]}
规则：
1. competitions.name、research.title 为必填；无法确定名称/标题的条目直接省略。
2. level 归一为：国际 / 国家级 / 省级 / 校级 之一，拿不准留空字符串。
3. research.type 取 paper / project / patent / other 之一（论文=paper，项目=project，专利=patent）。
4. 其余字段（award/year/role/venueOrStatus）拿不准留空字符串，不要臆测。
5. 自述中没有成果时，两个数组都为空。
''';
}
```

- [ ] **Step 4：跑测试确认通过**

Run: `flutter test test/data/ai/ai_profile_extraction_repository_test.dart`
Expected: All tests passed.

- [ ] **Step 5：Commit**

```bash
git add lib/data/ai/ai_profile_extraction_repository.dart test/data/ai/ai_profile_extraction_repository_test.dart
git commit -m "feat(profile): AI achievement extraction repository (grounded, jsonMode)"
```

---

### Task B3：di 接线 profileExtractionRepositoryProvider

**Files:**
- Modify: `lib/core/di/providers.dart`
- Test: `test/core/di/profile_extraction_provider_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_profile_extraction_repository.dart';

void main() {
  test('默认（mock，无 key）也接 AiProfileExtractionRepository（分析类恒 AI）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(profileExtractionRepositoryProvider),
      isA<AiProfileExtractionRepository>(),
    );
  });

  test('dataSource=ai 接 AiProfileExtractionRepository', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(profileExtractionRepositoryProvider),
      isA<AiProfileExtractionRepository>(),
    );
  });
}
```

- [ ] **Step 2：跑测试确认失败**

Run: `flutter test test/core/di/profile_extraction_provider_test.dart`
Expected: 编译错误（`profileExtractionRepositoryProvider` 未定义）。

- [ ] **Step 3：在 `lib/core/di/providers.dart` 添加 provider**

文件顶部 import 区加入：

```dart
import '../../data/ai/ai_profile_extraction_repository.dart';
import '../../domain/repositories/profile_extraction_repository.dart';
```

在 `outreachEmailRepositoryProvider` 定义之后插入：

```dart
/// 成果抽取属"分析类"——恒为 AI（mock 模式也用 AI，无假分析实现）；
/// 真实后端（V1.0）到位后 http 分支切 HttpProfileExtractionRepository。
final profileExtractionRepositoryProvider = Provider<ProfileExtractionRepository>(
  (ref) {
    final cfg = ref.watch(appConfigProvider);
    return switch (cfg.dataSource) {
      DataSource.mock || DataSource.ai => AiProfileExtractionRepository(
        ref.watch(llmClientProvider),
      ),
      DataSource.http => throw UnimplementedError(
        'HTTP data source not wired until V1.0',
      ),
    };
  },
);
```

- [ ] **Step 4：跑测试确认通过**

Run: `flutter test test/core/di/profile_extraction_provider_test.dart`
Expected: All tests passed.

- [ ] **Step 5：Commit**

```bash
git add lib/core/di/providers.dart test/core/di/profile_extraction_provider_test.dart
git commit -m "feat(profile): wire profileExtractionRepositoryProvider (AI-only analysis)"
```

---

## Phase C · 推荐注入

### Task C1：getRecommendations 接口加 profile（+ Mock 同步签名）

**Files:**
- Modify: `lib/domain/repositories/recommendation_repository.dart`
- Modify: `lib/data/mock/mock_recommendation_repository.dart`

- [ ] **Step 1：改接口 `recommendation_repository.dart`**

```dart
import '../../core/result/result.dart';
import '../entities/recommendation_result.dart';
import '../entities/user_profile.dart';

abstract interface class RecommendationRepository {
  /// 根据自然语言 prompt 获取推荐。[profile] 为可选学生档案（背景感知，
  /// 空档案/为 null 时行为与不传一致）。[sessionId] 用于多轮（V0.2+）。
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  });
}
```

- [ ] **Step 2：改 `mock_recommendation_repository.dart` 同步签名（忽略 profile）**

```dart
import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/recommendation_repository.dart';
import 'mock_db.dart';

class MockRecommendationRepository implements RecommendationRepository {
  MockRecommendationRepository(this._db);

  final MockDb _db;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile, // 忽略：mock 为确定性演示数据
    String? sessionId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return Success(_db.recommend(prompt, sessionId: sessionId));
  }
}
```

- [ ] **Step 3：跑既有推荐相关测试确认编译仍通过（AI 单测不传 profile 仍合法）**

Run: `flutter test test/data/ai/ai_recommendation_repository_test.dart test/data/mock`
Expected: All tests passed（接口加的是可选参数，既有调用不受影响）。

- [ ] **Step 4：Commit**

```bash
git add lib/domain/repositories/recommendation_repository.dart lib/data/mock/mock_recommendation_repository.dart
git commit -m "feat(reco): add optional profile param to getRecommendations"
```

---

### Task C2：AiRecommendationRepository 注入档案到 prompt

**Files:**
- Modify: `lib/data/ai/ai_recommendation_repository.dart`
- Test: `test/data/ai/ai_recommendation_repository_test.dart`（追加用例）

- [ ] **Step 1：在测试文件追加用例**

先在 `_FakeLlm` 中捕获消息：把 `_FakeLlm` 改为记录最后一次 user 消息——在 `lastJsonMode` 字段下加：

```dart
  String? lastUserContent;
```

并在 `complete(...)` 体内、`lastJsonMode = jsonMode;` 之后加：

```dart
    lastUserContent = messages.last.content;
```

在 `main()` 末尾追加：

```dart
  test('传入档案时 user 消息包含【学生档案】段', () async {
    final fake = _FakeLlm(const Success('{"recommendations":[]}'));
    final repo = AiRecommendationRepository(llm: fake, candidates: candidates);

    await repo.getRecommendations(
      prompt: '医学影像',
      profile: const UserProfile(
        targetDegree: '申请硕士',
        researchInterests: ['医学影像'],
        competitions: [Competition(name: 'ACM 区域赛', award: '银牌')],
      ),
    );

    expect(fake.lastUserContent, contains('【学生档案】'));
    expect(fake.lastUserContent, contains('ACM 区域赛'));
  });

  test('空档案不追加【学生档案】段（行为不变）', () async {
    final fake = _FakeLlm(const Success('{"recommendations":[]}'));
    final repo = AiRecommendationRepository(llm: fake, candidates: candidates);

    await repo.getRecommendations(prompt: '医学影像', profile: const UserProfile());

    expect(fake.lastUserContent, isNot(contains('【学生档案】')));
  });
```

补充 import：

```dart
import 'package:scho_navi/domain/entities/competition.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
```

- [ ] **Step 2：跑测试确认失败**

Run: `flutter test test/data/ai/ai_recommendation_repository_test.dart`
Expected: 新用例失败（未注入档案段）。

- [ ] **Step 3：修改 `ai_recommendation_repository.dart`**

a) `import` 区加入：

```dart
import '../../domain/entities/user_profile.dart';
```

b) 把 `getRecommendations` 签名与 user 消息改为：

```dart
  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async {
    final pool = candidates.candidatesFor(prompt);
    final profileSection = _encodeProfile(profile);
    final res = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage(
          'user',
          '【用户需求】$prompt\n'
              '${profileSection == null ? '' : '【学生档案】$profileSection\n'}'
              '【候选导师】${_encode(pool)}',
        ),
      ],
      jsonMode: true,
      temperature: 0.3,
    );
```

（其余函数体不变：`if (res is Failure<String>) ...` 起照旧。）

c) 在 `_encode(...)` 方法之后加入：

```dart
  /// 把档案压成紧凑 JSON；空档案返回 null（不注入）。
  String? _encodeProfile(UserProfile? p) {
    if (p == null || p.isEmpty) return null;
    return jsonEncode({
      if (p.gender != null) 'gender': p.gender!.name,
      if (p.degreeStage != null) 'degreeStage': p.degreeStage,
      if (p.targetDegree != null) 'targetDegree': p.targetDegree,
      if (p.school != null) 'school': p.school,
      if (p.major != null) 'major': p.major,
      if (p.score != null && !p.score!.isEmpty)
        'score': {
          if (p.score!.gpa != null) 'gpa': p.score!.gpa,
          if (p.score!.scale != null) 'scale': p.score!.scale,
          if (p.score!.rank != null) 'rank': p.score!.rank,
        },
      if (p.researchInterests.isNotEmpty)
        'researchInterests': p.researchInterests,
      if (p.competitions.isNotEmpty)
        'competitions': [for (final c in p.competitions) c.toJson()],
      if (p.research.isNotEmpty)
        'research': [for (final r in p.research) r.toJson()],
      if (p.highlights != null) 'highlights': p.highlights,
    });
  }
```

d) 在 `_systemPrompt` 的规则中（第 7 条之后）加入一条，并相应改写常量（把第 8 条编号后移）：

```
8. 若提供【学生档案】，请结合其研究兴趣/成绩/竞赛/科研背景调整排序，并在 reason 中适当引用学生背景与导师的契合点；但仍只引用候选导师事实、不得编造。
9. 候选中无相关导师时 recommendations 用空数组。
```

- [ ] **Step 4：跑测试确认通过**

Run: `flutter test test/data/ai/ai_recommendation_repository_test.dart`
Expected: All tests passed。

- [ ] **Step 5：Commit**

```bash
git add lib/data/ai/ai_recommendation_repository.dart test/data/ai/ai_recommendation_repository_test.dart
git commit -m "feat(reco): inject student profile into AI recommendation prompt (additive)"
```

---

### Task C3：profileProvider（全局当前档案）

**Files:**
- Create: `lib/features/profile/providers/profile_provider.dart`
- Test: `test/features/profile/profile_provider_test.dart`

- [ ] **Step 1：写失败测试**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/profile/providers/profile_provider.dart';

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo([this._stored = const UserProfile()]);

  UserProfile _stored;

  @override
  UserProfile load() => _stored;

  @override
  Future<void> save(UserProfile profile) async => _stored = profile;
}

void main() {
  test('build 从仓储读初值', () {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepo(const UserProfile(name: '张三')),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(profileProvider).name, '张三');
  });

  test('save 更新 state 并落盘', () async {
    final fake = _FakeProfileRepo();
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container
        .read(profileProvider.notifier)
        .save(const UserProfile(name: '李四'));

    expect(container.read(profileProvider).name, '李四');
    expect(fake.load().name, '李四');
  });
}
```

- [ ] **Step 2：跑测试确认失败**

Run: `flutter test test/features/profile/profile_provider_test.dart`
Expected: 编译错误（`profileProvider` 未定义）。

- [ ] **Step 3：实现 `lib/features/profile/providers/profile_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../domain/entities/user_profile.dart';

/// 全局当前学生档案。向导/中心通过它编辑，推荐/套磁/匹配读它。
class ProfileController extends Notifier<UserProfile> {
  @override
  UserProfile build() => ref.read(profileRepositoryProvider).load();

  Future<void> save(UserProfile profile) async {
    state = profile;
    await ref.read(profileRepositoryProvider).save(profile);
  }
}

final profileProvider = NotifierProvider<ProfileController, UserProfile>(
  ProfileController.new,
);
```

- [ ] **Step 4：跑测试确认通过**

Run: `flutter test test/features/profile/profile_provider_test.dart`
Expected: All tests passed。

- [ ] **Step 5：Commit**

```bash
git add lib/features/profile/providers/profile_provider.dart test/features/profile/profile_provider_test.dart
git commit -m "feat(profile): app-wide profileProvider (NotifierProvider)"
```

---

### Task C4：recommendationProvider 注入 profile（+ 迁移既有测试）

**Files:**
- Modify: `lib/features/recommendation/providers/recommendation_provider.dart`
- Test: `test/features/recommendation/recommendation_provider_test.dart`（迁移）
- Test: `test/features/recommendation/recommendation_page_test.dart`（若其假仓储实现 RecommendationRepository，需补 profile 形参）

- [ ] **Step 1：改 `recommendation_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/recommendation_result.dart';
import '../../profile/providers/profile_provider.dart';

/// 按 prompt 取推荐，并注入当前档案（背景感知）。档案变更自动失效重算。
final recommendationProvider =
    FutureProvider.family<RecommendationResult, String>((ref, prompt) async {
      final profile = ref.watch(profileProvider);
      final repo = ref.watch(recommendationRepositoryProvider);
      final result = await repo.getRecommendations(
        prompt: prompt,
        profile: profile,
      );
      return switch (result) {
        Success(:final data) => data,
        Failure(:final error) => throw error,
      };
    });
```

- [ ] **Step 2：迁移 `recommendation_provider_test.dart`**

a) 给 `_FakeRepo` 加 `profile` 形参——把其 `getRecommendations` 签名改为：

```dart
  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async => _result;
```

并在文件顶部 import：

```dart
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
```

b) 加一个假档案仓储（放在 `_FakeRepo` 之后）：

```dart
class _FakeProfileRepo implements ProfileRepository {
  @override
  UserProfile load() => const UserProfile();
  @override
  Future<void> save(UserProfile profile) async {}
}
```

c) 三个 `ProviderContainer(overrides: [...])` 各加一项 `profileRepositoryProvider.overrideWithValue(_FakeProfileRepo())`，例如第一个：

```dart
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        recommendationRepositoryProvider.overrideWithValue(
          _FakeRepo(Success(_result(empty: false))),
        ),
      ],
    );
```

（第二、三个 container 同样在 overrides 列表首部加入该行。）

- [ ] **Step 3：跑推荐 provider 测试确认通过**

Run: `flutter test test/features/recommendation/recommendation_provider_test.dart`
Expected: All tests passed。

- [ ] **Step 4：修复 page 测试（如失败）**

Run: `flutter test test/features/recommendation/recommendation_page_test.dart`
若因假仓储签名不符报错：给该文件里实现 `RecommendationRepository` 的假类补 `UserProfile? profile,` 形参（同 Step 2a），并 import `user_profile.dart`；若它通过 override `recommendationRepositoryProvider` 且 `recommendationProvider` 被读取，则同样加 `profileRepositoryProvider.overrideWithValue(_FakeProfileRepo())`。
Expected: All tests passed。

- [ ] **Step 5：全量回归 + analyze**

Run: `flutter test && flutter analyze`
Expected: All tests passed；analyze No issues found。

- [ ] **Step 6：Commit**

```bash
git add lib/features/recommendation/providers/recommendation_provider.dart test/features/recommendation/
git commit -m "feat(reco): recommendationProvider injects profile; migrate tests"
```

---

## 自检清单（执行者完成全部 Task 后）

- [ ] `flutter test` 全绿（含新增 + 迁移）。
- [ ] `flutter analyze` 无 issue。
- [ ] AI 模式冒烟：`flutter run --dart-define=LLM_API_KEY=…`，确认推荐仍正常（无档案时行为不变）。
- [ ] 确认 spec Phase A/B/C 全覆盖：UserProfile 扩展✓、序列化兼容✓、抽取仓储✓、di✓、推荐注入✓、profileProvider✓。

> 引擎层到此完成。用户尚不能从 UI 录入新字段——由「计划② 界面（D/E/F）」交付向导/中心/组件后端到端打通。
