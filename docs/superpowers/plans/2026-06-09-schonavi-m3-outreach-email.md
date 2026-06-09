# SchoNavi M3 · 套磁邮件生成 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从导师详情页一键生成**个性化套磁邮件草稿**（主题 + 正文），可编辑、可复制；模型据【导师方向 + 学生背景】生成，接地（只用提供的事实，不编造）。学生背景本地持久化复用（M5 共用）。

**Architecture:** 新增领域模型 `UserProfile`（本地持久化）与 `EmailDraft`；新增 `ProfileRepository`（本地，同收藏/历史模式）与 `OutreachEmailRepository`（远程类，走 `Result`）。`AiOutreachEmailRepository` 用 M1 的 `LlmClient.complete(jsonMode:true)` 产出 `{subject, body}`，导师事实取自传入的 `Professor`、学生信息只用 `UserProfile`；`MockOutreachEmailRepository` 模板拼装离线兜底。新增 feature 目录 `features/email/`（`email_page` + `email_provider` + `profile_sheet`），路由 `/email?pid=<professorId>`，详情页加入口按钮。DI 加两个 provider。presentation/domain 既有零改动。

**Tech Stack:** Flutter 3.44 / Dart 3.12；`flutter_riverpod ^3.3.1`（手写 provider）；`go_router ^17`；M1 的 `LlmClient`（`dio`）；`Clipboard`（`flutter/services`）。无新依赖。

**Spec 依据:** `docs/superpowers/specs/2026-06-09-schonavi-m3-outreach-email-design.md`。

**前置条件（已核实落地）:** M1 已实现（`LlmClient.complete`、`DataSource.ai|mock` DI 切换、`professorProvider` = `FutureProvider.family<Professor,String>`、`LocalStore.getJson/setJson` 可用）。`flutter test` 全绿。分支 `feat/v0.1-prototype`。

**⚠️ 与 M2 的耦合（实现顺序相关，务必先读）:** 本计划按**当前真实代码**（M1 已实现、**M2 流式未实现**，`LlmClient` 只有 `complete`）编写，故本计划新增的 `LlmClient` 假实现（Task 3 的 `_FakeLlm`）只实现 `complete`。**若实现 M3 时 M2 已落地**（`LlmClient` 多了 `stream`），则给该 `_FakeLlm` 补一行：
```dart
  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
```
（套磁邮件不流式，桩即可。其余仓储/接口与 M2 互不影响。）

**与 spec 的偏差:** 详见 spec §8——正文非流式（一次出全文便于编辑）；`UserProfile` 本地持久化、M5 复用；先中文、英文留 V1.0。本计划另定：详情页入口为正文内 `FilledButton`（FAB 已被「继续追问」占用）；「复制」复制「主题 + 正文」并提示 SnackBar；`emailProvider` 用 `start(professorId)` 在切换导师时重置（仿 `ChatNotifier`）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/domain/entities/user_profile.dart` | 新：学生背景实体 + `isEmpty` |
| `lib/domain/entities/email_draft.dart` | 新：邮件草稿（subject/body） |
| `lib/domain/repositories/profile_repository.dart` | 新：本地 profile 接口 |
| `lib/domain/repositories/outreach_email_repository.dart` | 新：套磁邮件生成接口（Result） |
| `lib/data/local/local_profile_repository.dart` | 新：`LocalStore` 存取 JSON |
| `lib/data/ai/ai_outreach_email_repository.dart` | 新：接地 JSON 生成 |
| `lib/data/mock/mock_outreach_email_repository.dart` | 新：模板拼装 |
| `lib/core/di/providers.dart` | **改**：加 `profileRepositoryProvider` / `outreachEmailRepositoryProvider` |
| `lib/features/email/providers/email_provider.dart` | 新：`EmailNotifier` + `EmailState` |
| `lib/features/email/widgets/profile_sheet.dart` | 新：背景填写底部 sheet |
| `lib/features/email/pages/email_page.dart` | 新：生成/编辑/复制/重生成/保存背景 |
| `lib/core/router/app_router.dart` | **改**：加 `/email` 路由 |
| `lib/features/professor/pages/professor_page.dart` | **改**：详情页加「生成套磁邮件」入口 |
| `test/domain/entities/user_profile_test.dart` | `isEmpty` 判定 |
| `test/data/local/local_profile_repository_test.dart` | 存取往返 / 空默认 |
| `test/data/ai/ai_outreach_email_repository_test.dart` | 解析 / 坏 JSON / 接地 / 失败透传 |
| `test/data/mock/mock_outreach_email_repository_test.dart` | 模板含导师名/方向 |
| `test/core/di/outreach_email_provider_test.dart` | 默认 mock + ai 接线 |
| `test/features/email/email_provider_test.dart` | generating/ready/error/重生成/start 重置 |
| `test/features/email/email_page_test.dart` | 可编辑主题/正文 / 复制 / 保存背景 |
| `test/features/email/email_entry_point_test.dart` | 详情页按钮跳 `/email?pid=` |

> 不改 domain 既有实体、其它 feature、mock 数据。既有测试默认 `mock`，须保持全绿。

---

## Task 1: 领域模型 + 仓储接口

**Files:**
- Create: `lib/domain/entities/user_profile.dart`
- Create: `lib/domain/entities/email_draft.dart`
- Create: `lib/domain/repositories/profile_repository.dart`
- Create: `lib/domain/repositories/outreach_email_repository.dart`
- Test: `test/domain/entities/user_profile_test.dart`

- [ ] **Step 1: 写失败测试 `test/domain/entities/user_profile_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

void main() {
  test('全空时 isEmpty 为真', () {
    expect(const UserProfile().isEmpty, isTrue);
  });

  test('任一字段有值时 isEmpty 为假', () {
    expect(const UserProfile(name: '李四').isEmpty, isFalse);
    expect(const UserProfile(researchInterests: ['AI']).isEmpty, isFalse);
    expect(const UserProfile(highlights: 'GPA 3.9').isEmpty, isFalse);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/domain/entities/user_profile_test.dart`
Expected: FAIL（`user_profile.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/domain/entities/user_profile.dart`**

```dart
/// 学生背景。本地持久化，M3 套磁邮件与 M5 背景匹配共用。缺失字段为 null/空。
class UserProfile {
  const UserProfile({
    this.name,
    this.degreeStage,
    this.school,
    this.major,
    this.researchInterests = const [],
    this.highlights,
  });

  final String? name; // 称呼用
  final String? degreeStage; // 本科在读 / 硕士在读 等
  final String? school; // 现就读学校
  final String? major; // 专业
  final List<String> researchInterests;
  final String? highlights; // 自述：成果/项目/绩点等（自由文本）

  bool get isEmpty =>
      (name == null || name!.isEmpty) &&
      (degreeStage == null || degreeStage!.isEmpty) &&
      (school == null || school!.isEmpty) &&
      (major == null || major!.isEmpty) &&
      researchInterests.isEmpty &&
      (highlights == null || highlights!.isEmpty);
}
```

- [ ] **Step 4: 实现 `lib/domain/entities/email_draft.dart`**

```dart
/// 套磁邮件草稿。
class EmailDraft {
  const EmailDraft({required this.subject, required this.body});

  final String subject;
  final String body;
}
```

- [ ] **Step 5: 实现 `lib/domain/repositories/profile_repository.dart`**

```dart
import '../entities/user_profile.dart';

/// 本地学生背景存取（同步读 + 异步写，参照 LocalStore 约定）。
abstract interface class ProfileRepository {
  UserProfile load();
  Future<void> save(UserProfile profile);
}
```

- [ ] **Step 6: 实现 `lib/domain/repositories/outreach_email_repository.dart`**

```dart
import '../../core/result/result.dart';
import '../entities/email_draft.dart';
import '../entities/professor.dart';
import '../entities/user_profile.dart';

/// 套磁邮件生成（远程类，走 Result）。
abstract interface class OutreachEmailRepository {
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  });
}
```

- [ ] **Step 7: 运行测试，确认通过**

Run: `flutter test test/domain/entities/user_profile_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 8: 提交**

```bash
git add lib/domain/entities/user_profile.dart lib/domain/entities/email_draft.dart lib/domain/repositories/profile_repository.dart lib/domain/repositories/outreach_email_repository.dart test/domain/entities/user_profile_test.dart
git commit -m "feat: add UserProfile/EmailDraft entities + profile/outreach repos (M3)"
```

---

## Task 2: LocalProfileRepository

**Files:**
- Create: `lib/data/local/local_profile_repository.dart`
- Test: `test/data/local/local_profile_repository_test.dart`

- [ ] **Step 1: 写失败测试 `test/data/local/local_profile_repository_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';
import 'package:scho_navi/data/local/local_profile_repository.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';

void main() {
  late LocalProfileRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    repo = LocalProfileRepository(SharedPreferencesLocalStore(prefs));
  });

  test('未保存时 load 返回空 profile', () {
    expect(repo.load().isEmpty, isTrue);
  });

  test('save 后 load 往返', () async {
    await repo.save(
      const UserProfile(
        name: '张三',
        degreeStage: '本科在读',
        school: '上海交通大学',
        major: '计算机科学与技术',
        researchInterests: ['人工智能', '计算机视觉'],
        highlights: 'GPA 3.9/4.0，一篇在投论文',
      ),
    );
    final p = repo.load();
    expect(p.name, '张三');
    expect(p.degreeStage, '本科在读');
    expect(p.school, '上海交通大学');
    expect(p.major, '计算机科学与技术');
    expect(p.researchInterests, ['人工智能', '计算机视觉']);
    expect(p.highlights, 'GPA 3.9/4.0，一篇在投论文');
  });

  test('空字段不写入，load 仍可解析', () async {
    await repo.save(const UserProfile(name: '李四'));
    final p = repo.load();
    expect(p.name, '李四');
    expect(p.school, isNull);
    expect(p.researchInterests, isEmpty);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/data/local/local_profile_repository_test.dart`
Expected: FAIL（`local_profile_repository.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/data/local/local_profile_repository.dart`**

```dart
import '../../core/storage/local_store.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// 经 [LocalStore] 以单个 JSON 对象存取学生背景（参照 LocalFavoriteRepository）。
class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._store);

  static const String storageKey = 'user_profile.v1';

  final LocalStore _store;

  @override
  UserProfile load() {
    final json = _store.getJson(storageKey);
    if (json == null) return const UserProfile();
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
  });

  String? _str(Object? v) => (v is String && v.isNotEmpty) ? v : null;
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/data/local/local_profile_repository_test.dart`
Expected: PASS（3 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/data/local/local_profile_repository.dart test/data/local/local_profile_repository_test.dart
git commit -m "feat: LocalProfileRepository (JSON via LocalStore) + tests (M3)"
```

---

## Task 3: AiOutreachEmailRepository

**Files:**
- Create: `lib/data/ai/ai_outreach_email_repository.dart`
- Test: `test/data/ai/ai_outreach_email_repository_test.dart`

- [ ] **Step 1: 写失败测试 `test/data/ai/ai_outreach_email_repository_test.dart`**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_outreach_email_repository.dart';
import 'package:scho_navi/domain/entities/email_draft.dart';
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

  // ⚠️ 若 M2 已实现，这里补：
  // @override
  // Stream<String> stream({required List<LlmMessage> messages,
  //     double temperature = 0.7}) => throw UnimplementedError();
}

const _prof = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
  bio: '长期研究医学影像分析。',
);

void main() {
  test('解析 {subject, body} 且使用 JSON 模式', () async {
    final llm = _FakeLlm(
      Success(jsonEncode({'subject': '套磁——医学影像', 'body': '尊敬的张三教授：……'})),
    );
    final repo = AiOutreachEmailRepository(llm);
    final res = await repo.generate(
      professor: _prof,
      profile: const UserProfile(name: '李四', degreeStage: '本科在读'),
    );
    final draft = (res as Success<EmailDraft>).data;
    expect(draft.subject, '套磁——医学影像');
    expect(draft.body, contains('张三'));
    expect(llm.lastJsonMode, isTrue);
  });

  test('接地：user prompt 含导师方向，且不含未提供的学生字段', () async {
    final llm = _FakeLlm(Success(jsonEncode({'subject': 's', 'body': 'b'})));
    final repo = AiOutreachEmailRepository(llm);
    await repo.generate(professor: _prof, profile: const UserProfile(name: '李四'));
    final userMsg = llm.lastMessages!.last.content;
    expect(userMsg, contains('医学影像')); // 导师事实接地
    expect(userMsg, contains('李四'));
    expect(userMsg.contains('highlights'), isFalse); // 未提供则不出现
  });

  test('坏 JSON → Failure(ServerException)', () async {
    final repo = AiOutreachEmailRepository(_FakeLlm(const Success('not json')));
    final res = await repo.generate(
      professor: _prof,
      profile: const UserProfile(),
    );
    expect((res as Failure).error, isA<ServerException>());
  });

  test('缺字段 JSON → Failure(ServerException)', () async {
    final repo = AiOutreachEmailRepository(
      _FakeLlm(const Success('{"subject":"只有主题"}')),
    );
    final res = await repo.generate(
      professor: _prof,
      profile: const UserProfile(),
    );
    expect((res as Failure).error, isA<ServerException>());
  });

  test('LlmClient 失败透传', () async {
    final repo = AiOutreachEmailRepository(
      _FakeLlm(const Failure(NetworkException())),
    );
    final res = await repo.generate(
      professor: _prof,
      profile: const UserProfile(),
    );
    expect((res as Failure).error, isA<NetworkException>());
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/data/ai/ai_outreach_email_repository_test.dart`
Expected: FAIL（`ai_outreach_email_repository.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/data/ai/ai_outreach_email_repository.dart`**

```dart
import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/email_draft.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/outreach_email_repository.dart';

/// 用大模型据【导师】+【学生背景】生成套磁邮件 JSON。导师/学生事实只用传入数据，不编造。
class AiOutreachEmailRepository implements OutreachEmailRepository {
  AiOutreachEmailRepository(this.llm);

  final LlmClient llm;

  @override
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  }) async {
    final res = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(professor, profile)),
      ],
      jsonMode: true,
    );
    switch (res) {
      case Failure(:final error):
        return Failure(error);
      case Success(:final data):
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final subject = (json['subject'] as String?)?.trim();
          final body = (json['body'] as String?)?.trim();
          if (subject == null ||
              subject.isEmpty ||
              body == null ||
              body.isEmpty) {
            return const Failure(ServerException());
          }
          return Success(EmailDraft(subject: subject, body: body));
        } catch (_) {
          return const Failure(ServerException());
        }
    }
  }

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
      if (u.researchInterests.isNotEmpty)
        'researchInterests': u.researchInterests,
      if (u.highlights != null) 'highlights': u.highlights,
    };
    return '【导师】${jsonEncode(professor)}\n【学生背景】${jsonEncode(student)}';
  }

  static const String _systemPrompt = '''
你是帮学生撰写**套磁邮件**的助手。根据【导师】与【学生背景】生成一封中文邮件，仅输出一个 JSON 对象 {"subject","body"}（json），不要 Markdown 或多余文字。
规则：
1. 礼貌、专业，正文 200-350 字。
2. 正文结构：自我介绍 → 为何对该导师方向感兴趣（结合其研究方向）→ 自身相关基础（只用【学生背景】提供的信息，不得编造成果、奖项、绩点或经历）→ 请求（了解招生 / 读研读博机会）→ 礼貌结尾。
3. 称呼用导师姓名 + 职称（如"张三教授"）。
4. 不要编造导师或学生的任何事实；学生信息缺失就不提，不要写虚构占位。
5. subject 为简洁的邮件主题（含意向与方向）。
输出示例：{"subject":"关于医学影像方向读研的咨询","body":"尊敬的张三教授：……"}
''';
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/data/ai/ai_outreach_email_repository_test.dart`
Expected: PASS（5 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/data/ai/ai_outreach_email_repository.dart test/data/ai/ai_outreach_email_repository_test.dart
git commit -m "feat: AiOutreachEmailRepository (grounded JSON email) + tests (M3)"
```

---

## Task 4: MockOutreachEmailRepository

**Files:**
- Create: `lib/data/mock/mock_outreach_email_repository.dart`
- Test: `test/data/mock/mock_outreach_email_repository_test.dart`

- [ ] **Step 1: 写失败测试 `test/data/mock/mock_outreach_email_repository_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_outreach_email_repository.dart';
import 'package:scho_navi/domain/entities/email_draft.dart';
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
  test('模板含导师名、方向与学生称呼', () async {
    final repo = MockOutreachEmailRepository();
    final res = await repo.generate(
      professor: _prof,
      profile: const UserProfile(name: '李四', degreeStage: '本科在读'),
    );
    final draft = (res as Success<EmailDraft>).data;
    expect(draft.body, contains('张三'));
    expect('${draft.subject}${draft.body}', contains('医学影像'));
    expect(draft.body, contains('李四'));
  });

  test('学生信息缺失也能生成（用兜底称呼）', () async {
    final repo = MockOutreachEmailRepository();
    final res = await repo.generate(
      professor: _prof,
      profile: const UserProfile(),
    );
    final draft = (res as Success<EmailDraft>).data;
    expect(draft.subject, isNotEmpty);
    expect(draft.body, contains('张三'));
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/data/mock/mock_outreach_email_repository_test.dart`
Expected: FAIL（`mock_outreach_email_repository.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/data/mock/mock_outreach_email_repository.dart`**

```dart
import '../../core/result/result.dart';
import '../../domain/entities/email_draft.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/outreach_email_repository.dart';

/// 离线兜底：模板拼装套磁邮件（不调用大模型）。
class MockOutreachEmailRepository implements OutreachEmailRepository {
  @override
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final fields = professor.researchFields.isEmpty
        ? '相关领域'
        : professor.researchFields.join('、');
    final who = '${professor.name}${professor.title}';
    final me = profile.name ?? '一名学生';
    final stage = profile.degreeStage ?? '';
    final selfIntro = [
      if (profile.school != null) profile.school!,
      if (profile.major != null) profile.major!,
      if (stage.isNotEmpty) stage,
    ].join(' ');
    final hasHighlights =
        profile.highlights != null && profile.highlights!.isNotEmpty;

    return Success(
      EmailDraft(
        subject: '关于$fields方向研究生申请的咨询 —— $me',
        body:
            '尊敬的$who：\n\n'
            '您好！我是$me${selfIntro.isEmpty ? '' : '（$selfIntro）'}，'
            '一直关注您在$fields方向的研究，对相关课题很感兴趣。\n\n'
            '${hasHighlights ? '我的相关基础：${profile.highlights}。' : '我希望进一步了解您课题组的研究方向与培养方式。'}\n\n'
            '冒昧来信，想请教您${stage.isEmpty ? '' : '$stage阶段'}是否有招生计划，'
            '以及如何更好地准备。期待您的回复，谢谢！\n\n'
            '（本邮件为 SchoNavi 离线模板示例，请按实际情况修改后再发送）',
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/data/mock/mock_outreach_email_repository_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/data/mock/mock_outreach_email_repository.dart test/data/mock/mock_outreach_email_repository_test.dart
git commit -m "feat: MockOutreachEmailRepository (template) + tests (M3)"
```

---

## Task 5: DI 接线

**Files:**
- Modify: `lib/core/di/providers.dart`
- Test: `test/core/di/outreach_email_provider_test.dart`

- [ ] **Step 1: 在 `lib/core/di/providers.dart` 顶部 import 区追加**

```dart
import '../../data/ai/ai_outreach_email_repository.dart';
import '../../data/local/local_profile_repository.dart';
import '../../data/mock/mock_outreach_email_repository.dart';
import '../../domain/repositories/outreach_email_repository.dart';
import '../../domain/repositories/profile_repository.dart';
```

- [ ] **Step 2: 在 `chatRepositoryProvider` 之后追加两个 provider**

```dart

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => LocalProfileRepository(ref.watch(localStoreProvider)),
);

final outreachEmailRepositoryProvider = Provider<OutreachEmailRepository>((ref) {
  switch (ref.watch(appConfigProvider).dataSource) {
    case DataSource.mock:
      return MockOutreachEmailRepository();
    case DataSource.ai:
      return AiOutreachEmailRepository(ref.watch(llmClientProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});
```

- [ ] **Step 3: 写接线测试 `test/core/di/outreach_email_provider_test.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_outreach_email_repository.dart';
import 'package:scho_navi/data/local/local_profile_repository.dart';
import 'package:scho_navi/data/mock/mock_outreach_email_repository.dart';

Future<ProviderContainer> _container({String apiKey = ''}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (apiKey.isNotEmpty)
        appConfigProvider.overrideWithValue(AppConfig.resolve(apiKey: apiKey)),
    ],
  );
}

void main() {
  test('默认（mock）接 MockOutreachEmailRepository + LocalProfileRepository', () async {
    final c = await _container();
    addTearDown(c.dispose);
    expect(
      c.read(outreachEmailRepositoryProvider),
      isA<MockOutreachEmailRepository>(),
    );
    expect(c.read(profileRepositoryProvider), isA<LocalProfileRepository>());
  });

  test('dataSource=ai 接 AiOutreachEmailRepository', () async {
    final c = await _container(apiKey: 'sk-test');
    addTearDown(c.dispose);
    expect(
      c.read(outreachEmailRepositoryProvider),
      isA<AiOutreachEmailRepository>(),
    );
  });
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/core/di/outreach_email_provider_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/core/di/providers.dart test/core/di/outreach_email_provider_test.dart
git commit -m "feat: wire profile + outreach email providers (mock/ai) + tests (M3)"
```

---

## Task 6: EmailNotifier / email_provider

**Files:**
- Create: `lib/features/email/providers/email_provider.dart`
- Test: `test/features/email/email_provider_test.dart`

- [ ] **Step 1: 写失败测试 `test/features/email/email_provider_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/email_draft.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/outreach_email_repository.dart';
import 'package:scho_navi/features/email/providers/email_provider.dart';

class _FakeEmailRepo implements OutreachEmailRepository {
  _FakeEmailRepo(this.response);

  Future<Result<EmailDraft>> response;
  int calls = 0;
  Professor? lastProfessor;
  UserProfile? lastProfile;

  @override
  Future<Result<EmailDraft>> generate({
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
const _profile = UserProfile(name: '李四', degreeStage: '本科在读');

ProviderContainer _containerWith(OutreachEmailRepository repo) =>
    ProviderContainer(
      overrides: [outreachEmailRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  test('generate 成功 → ready 且携带 draft + 透传入参', () async {
    final repo = _FakeEmailRepo(
      Future.value(const Success(EmailDraft(subject: 's', body: 'b'))),
    );
    final container = _containerWith(repo);
    addTearDown(container.dispose);

    await container
        .read(emailProvider.notifier)
        .generate(professor: _prof, profile: _profile);
    final state = container.read(emailProvider);

    expect(state.status, EmailStatus.ready);
    expect(state.draft?.subject, 's');
    expect(repo.lastProfessor?.id, 'p_001');
    expect(repo.lastProfile?.name, '李四');
  });

  test('generate 失败 → error 且携带文案', () async {
    final container = _containerWith(
      _FakeEmailRepo(Future.value(const Failure(ServerException()))),
    );
    addTearDown(container.dispose);

    await container
        .read(emailProvider.notifier)
        .generate(professor: _prof, profile: _profile);
    final state = container.read(emailProvider);

    expect(state.status, EmailStatus.error);
    expect(state.message, '服务异常，请稍后重试');
  });

  test('generate 期间为 generating', () async {
    final completer = Completer<Result<EmailDraft>>();
    final container = _containerWith(_FakeEmailRepo(completer.future));
    addTearDown(container.dispose);

    final future = container
        .read(emailProvider.notifier)
        .generate(professor: _prof, profile: _profile);
    expect(container.read(emailProvider).status, EmailStatus.generating);

    completer.complete(const Success(EmailDraft(subject: 's', body: 'b')));
    await future;
    expect(container.read(emailProvider).status, EmailStatus.ready);
  });

  test('重新生成：再次调用仓储', () async {
    final repo = _FakeEmailRepo(
      Future.value(const Success(EmailDraft(subject: 's', body: 'b'))),
    );
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(emailProvider.notifier);

    await notifier.generate(professor: _prof, profile: _profile);
    await notifier.generate(professor: _prof, profile: _profile);
    expect(repo.calls, 2);
  });

  test('start 切换 professor 时重置为 idle', () async {
    final repo = _FakeEmailRepo(
      Future.value(const Success(EmailDraft(subject: 's', body: 'b'))),
    );
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(emailProvider.notifier);

    notifier.start('p_001');
    await notifier.generate(professor: _prof, profile: _profile);
    expect(container.read(emailProvider).status, EmailStatus.ready);

    notifier.start('p_002');
    expect(container.read(emailProvider).status, EmailStatus.idle);
    expect(container.read(emailProvider).draft, isNull);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/email/email_provider_test.dart`
Expected: FAIL（`email_provider.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/features/email/providers/email_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/email_draft.dart';
import '../../../domain/entities/professor.dart';
import '../../../domain/entities/user_profile.dart';

enum EmailStatus { idle, generating, ready, error }

/// 套磁邮件页状态。单屏一次一封，故用全局 Notifier + start 注入/重置。
class EmailState {
  const EmailState({
    required this.professorId,
    required this.status,
    this.draft,
    this.message,
  });

  const EmailState.initial()
    : professorId = null,
      status = EmailStatus.idle,
      draft = null,
      message = null;

  final String? professorId;
  final EmailStatus status;
  final EmailDraft? draft;
  final String? message;
}

class EmailNotifier extends Notifier<EmailState> {
  @override
  EmailState build() => const EmailState.initial();

  /// 进入某导师邮件页：切换导师时重置，避免上一个导师的草稿残留。
  void start(String professorId) {
    if (state.professorId == professorId) return;
    state = EmailState(professorId: professorId, status: EmailStatus.idle);
  }

  Future<void> generate({
    required Professor professor,
    required UserProfile profile,
  }) async {
    final pid = state.professorId ?? professor.id;
    state = EmailState(professorId: pid, status: EmailStatus.generating);
    final res = await ref
        .read(outreachEmailRepositoryProvider)
        .generate(professor: professor, profile: profile);
    state = switch (res) {
      Success(:final data) => EmailState(
        professorId: pid,
        status: EmailStatus.ready,
        draft: data,
      ),
      Failure(:final error) => EmailState(
        professorId: pid,
        status: EmailStatus.error,
        message: error.message,
      ),
    };
  }
}

final emailProvider = NotifierProvider<EmailNotifier, EmailState>(
  EmailNotifier.new,
);
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/features/email/email_provider_test.dart`
Expected: PASS（5 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/features/email/providers/email_provider.dart test/features/email/email_provider_test.dart
git commit -m "feat: EmailNotifier (generate/start/states) + tests (M3)"
```

---

## Task 7: ProfileSheet + EmailPage + 路由 + 详情页入口

**Files:**
- Create: `lib/features/email/widgets/profile_sheet.dart`
- Create: `lib/features/email/pages/email_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/professor/pages/professor_page.dart`
- Test: `test/features/email/email_page_test.dart`
- Test: `test/features/email/email_entry_point_test.dart`

- [ ] **Step 1: 实现 `lib/features/email/widgets/profile_sheet.dart`**

```dart
import 'package:flutter/material.dart';

import '../../../domain/entities/user_profile.dart';

/// 弹出背景填写底部 sheet；保存返回 [UserProfile]，取消返回 null。
Future<UserProfile?> showProfileSheet(BuildContext context, UserProfile initial) {
  return showModalBottomSheet<UserProfile>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: ProfileSheet(initial: initial),
    ),
  );
}

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, required this.initial});

  final UserProfile initial;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final _name = TextEditingController(text: widget.initial.name ?? '');
  late final _degree = TextEditingController(
    text: widget.initial.degreeStage ?? '',
  );
  late final _school = TextEditingController(text: widget.initial.school ?? '');
  late final _major = TextEditingController(text: widget.initial.major ?? '');
  late final _interests = TextEditingController(
    text: widget.initial.researchInterests.join('、'),
  );
  late final _highlights = TextEditingController(
    text: widget.initial.highlights ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _degree.dispose();
    _school.dispose();
    _major.dispose();
    _interests.dispose();
    _highlights.dispose();
    super.dispose();
  }

  String? _trimOrNull(String s) => s.trim().isEmpty ? null : s.trim();

  void _save() {
    final interests = _interests.text
        .split(RegExp(r'[，,、\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    Navigator.of(context).pop(
      UserProfile(
        name: _trimOrNull(_name.text),
        degreeStage: _trimOrNull(_degree.text),
        school: _trimOrNull(_school.text),
        major: _trimOrNull(_major.text),
        researchInterests: interests,
        highlights: _trimOrNull(_highlights.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('完善个人背景', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('用于生成更贴合你的套磁邮件，仅保存在本机。'),
          const SizedBox(height: 12),
          _field(_name, '称呼 / 姓名', 'profile-name'),
          _field(_degree, '当前阶段（如 本科在读 / 硕士在读）', 'profile-degree'),
          _field(_school, '现就读学校', 'profile-school'),
          _field(_major, '专业', 'profile-major'),
          _field(_interests, '研究兴趣（顿号或逗号分隔）', 'profile-interests'),
          _field(_highlights, '自述：成果 / 项目 / 绩点等', 'profile-highlights', maxLines: 3),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      key: Key(key),
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}
```

- [ ] **Step 2: 写失败测试 `test/features/email/email_page_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/email_draft.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/outreach_email_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/email/pages/email_page.dart';

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
  int saves = 0;

  @override
  UserProfile load() => _profile;

  @override
  Future<void> save(UserProfile profile) async {
    saves++;
    _profile = profile;
  }
}

class _FakeEmailRepo implements OutreachEmailRepository {
  _FakeEmailRepo(this.draft);
  final EmailDraft draft;

  @override
  Future<Result<EmailDraft>> generate({
    required Professor professor,
    required UserProfile profile,
  }) async => Success(draft);
}

Widget _wrap(_FakeProfileRepo profileRepo, _FakeEmailRepo emailRepo) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const EmailPage(professorId: 'p_001')),
    ],
  );
  return ProviderScope(
    overrides: [
      professorRepositoryProvider.overrideWithValue(_FakeProfessorRepo()),
      profileRepositoryProvider.overrideWithValue(profileRepo),
      outreachEmailRepositoryProvider.overrideWithValue(emailRepo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('生成后显示可编辑主题与正文', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final emailRepo = _FakeEmailRepo(
      const EmailDraft(subject: '测试主题', body: '正文内容：尊敬的张三教授…'),
    );
    await tester.pumpWidget(_wrap(profileRepo, emailRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('生成套磁邮件'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '测试主题'), findsOneWidget);
    expect(find.widgetWithText(TextField, '正文内容：尊敬的张三教授…'), findsOneWidget);
  });

  testWidgets('复制：点击后提示已复制', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final emailRepo = _FakeEmailRepo(
      const EmailDraft(subject: '主题', body: '正文'),
    );
    await tester.pumpWidget(_wrap(profileRepo, emailRepo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成套磁邮件'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('复制'));
    await tester.pump();

    expect(find.text('已复制到剪贴板'), findsOneWidget);
  });

  testWidgets('保存背景：打开 sheet 录入并存到本地', (tester) async {
    final profileRepo = _FakeProfileRepo(const UserProfile(name: '李四'));
    final emailRepo = _FakeEmailRepo(
      const EmailDraft(subject: '主题', body: '正文'),
    );
    await tester.pumpWidget(_wrap(profileRepo, emailRepo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成套磁邮件'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存背景'));
    await tester.pumpAndSettle();
    expect(find.text('完善个人背景'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile-name')), '王五');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(profileRepo.saves, greaterThanOrEqualTo(1));
    expect(profileRepo.load().name, '王五');
  });
}
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `flutter test test/features/email/email_page_test.dart`
Expected: FAIL（`email_page.dart` 不存在）。

- [ ] **Step 4: 实现 `lib/features/email/pages/email_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/professor.dart';
import '../../../features/professor/providers/professor_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../providers/email_provider.dart';
import '../widgets/profile_sheet.dart';

class EmailPage extends ConsumerStatefulWidget {
  const EmailPage({super.key, required this.professorId});

  final String professorId;

  @override
  ConsumerState<EmailPage> createState() => _EmailPageState();
}

class _EmailPageState extends ConsumerState<EmailPage> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(emailProvider.notifier).start(widget.professorId);
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _generate(Professor professor) async {
    var profile = ref.read(profileRepositoryProvider).load();
    if (profile.isEmpty) {
      final edited = await showProfileSheet(context, profile);
      if (edited == null) return; // 用户取消
      await ref.read(profileRepositoryProvider).save(edited);
      profile = edited;
    }
    await ref
        .read(emailProvider.notifier)
        .generate(professor: professor, profile: profile);
  }

  Future<void> _saveBackground() async {
    final current = ref.read(profileRepositoryProvider).load();
    final edited = await showProfileSheet(context, current);
    if (edited == null) return;
    await ref.read(profileRepositoryProvider).save(edited);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存个人背景')));
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(
        text: '${_subjectController.text}\n\n${_bodyController.text}',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<EmailState>(emailProvider, (prev, next) {
      if (next.status == EmailStatus.ready && next.draft != null) {
        _subjectController.text = next.draft!.subject;
        _bodyController.text = next.draft!.body;
      }
    });

    final professorAsync = ref.watch(professorProvider(widget.professorId));
    final email = ref.watch(emailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('套磁邮件')),
      body: professorAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : '出错了，请稍后重试',
          onRetry: () => ref.invalidate(professorProvider(widget.professorId)),
        ),
        data: (professor) => _buildBody(professor, email),
      ),
    );
  }

  Widget _buildBody(Professor professor, EmailState email) {
    switch (email.status) {
      case EmailStatus.idle:
        return _IdlePrompt(
          professor: professor,
          onGenerate: () => _generate(professor),
        );
      case EmailStatus.generating:
        return const LoadingView();
      case EmailStatus.error:
        return ErrorView(
          message: email.message ?? '生成失败，请重试',
          onRetry: () => _generate(professor),
        );
      case EmailStatus.ready:
        return _DraftForm(
          subjectController: _subjectController,
          bodyController: _bodyController,
          onCopy: _copy,
          onRegenerate: () => _generate(professor),
          onSaveBackground: _saveBackground,
        );
    }
  }
}

class _IdlePrompt extends StatelessWidget {
  const _IdlePrompt({required this.professor, required this.onGenerate});

  final Professor professor;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              '为 ${professor.name}${professor.title} 生成一封个性化套磁邮件草稿',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '将结合导师研究方向与你的背景生成可编辑、可复制的中文邮件。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('生成套磁邮件'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftForm extends StatelessWidget {
  const _DraftForm({
    required this.subjectController,
    required this.bodyController,
    required this.onCopy,
    required this.onRegenerate,
    required this.onSaveBackground,
  });

  final TextEditingController subjectController;
  final TextEditingController bodyController;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final VoidCallback onSaveBackground;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('主题', style: textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: subjectController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),
        Text('正文', style: textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: bodyController,
          minLines: 8,
          maxLines: 20,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
              label: const Text('复制'),
            ),
            OutlinedButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('重新生成'),
            ),
            TextButton.icon(
              onPressed: onSaveBackground,
              icon: const Icon(Icons.person_outline),
              label: const Text('保存背景'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '提示：邮件为 AI 生成草稿，请核对事实后再发送。',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: 运行页面测试，确认通过**

Run: `flutter test test/features/email/email_page_test.dart`
Expected: PASS（3 个）。

- [ ] **Step 6: 在 `lib/core/router/app_router.dart` 加 `/email` 路由**

在 import 区加：
```dart
import '../../features/email/pages/email_page.dart';
```
在 `/chat` 的 `GoRoute(...)` 之后、`routes:` 列表收尾 `]` 之前追加：
```dart
      GoRoute(
        path: '/email',
        builder: (_, state) =>
            EmailPage(professorId: state.uri.queryParameters['pid'] ?? ''),
      ),
```

- [ ] **Step 7: 写失败测试 `test/features/email/email_entry_point_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/professor/pages/professor_page.dart';

void main() {
  testWidgets('详情页「生成套磁邮件」跳 /email?pid=', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ProfessorPage(professorId: 'p_001'),
        ),
        GoRoute(
          path: '/email',
          builder: (_, s) => Text('email:${s.uri.queryParameters['pid']}'),
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

    await tester.tap(find.text('生成套磁邮件'));
    await tester.pumpAndSettle();

    expect(find.text('email:p_001'), findsOneWidget);
  });
}
```

- [ ] **Step 8: 运行测试，确认失败**

Run: `flutter test test/features/email/email_entry_point_test.dart`
Expected: FAIL（详情页还没有「生成套磁邮件」按钮）。

- [ ] **Step 9: 在 `lib/features/professor/pages/professor_page.dart` 的 `_Detail` 加入口按钮**

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
          child: FilledButton.icon(
            onPressed: () =>
                context.push('/email?pid=${Uri.encodeComponent(p.id)}'),
            icon: const Icon(Icons.mail_outline),
            label: const Text('生成套磁邮件'),
          ),
        ),
        const Divider(height: 28),
```
（`context`、`go_router` 已在该文件可用，无需新增 import。）

- [ ] **Step 10: 运行入口测试，确认通过**

Run: `flutter test test/features/email/email_entry_point_test.dart`
Expected: PASS（1 个）。

- [ ] **Step 11: 全量验证并提交**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全绿（含既有）。
```bash
git add lib/features/email/ lib/core/router/app_router.dart lib/features/professor/pages/professor_page.dart test/features/email/email_page_test.dart test/features/email/email_entry_point_test.dart
git commit -m "feat: email page + profile sheet + /email route + detail entry (M3)"
```

---

## Task 8: 收尾全量验证 + 人工冒烟

**Files:** 无（仅验证）

- [ ] **Step 1: 全量分析与测试**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全部 PASS——既有 + 本里程碑新增（UserProfile 2、LocalProfile 3、AI 5、Mock 2、DI 2、provider 5、page 3、entry 1 = 23）。

- [ ] **Step 2: 确认工作区干净**

Run: `git status --short`
Expected: 干净（除可能的 `.agents/` 等非本任务文件）。

- [ ] **Step 3: 人工冒烟（需真实 key）**

Run（替换为真实 key）：
```bash
flutter run --dart-define=LLM_API_KEY=sk-你的key
```
手动核对：
- 进任一导师详情页 → 点「生成套磁邮件」→ 首次弹**背景填写 sheet**（填姓名/阶段/学校/专业/方向/自述）→ 保存。
- 生成 loading → **邮件草稿页**：主题 + 正文均可编辑；正文结合该导师研究方向、且只用我填的背景（无编造成果）。
- 「复制」→ 提示「已复制到剪贴板」，粘贴到记事本验证含主题 + 正文。
- 「重新生成」→ 产出新版本（措辞不同）。
- 「保存背景」→ 再次弹 sheet，改完保存；返回再进，背景已复用（不再弹首次 sheet）。
- 关 key 直接 `flutter run` → `mock`：模板邮件含导师名/方向（离线演示安全）。
- 断网或填错 key → 错误态 + 重试。

> 本里程碑解锁：M5 背景匹配复用同一 `UserProfile`；正文流式预览可在 M2 落地后作为增强。后续 M4 多导师对比、M5 背景匹配、M6 打磨与作品说明。

---

## 自查（Self-Review）记录

- **Spec 覆盖**（M3 spec §2–§7）：
  - §2 模型 `UserProfile`/`EmailDraft` → Task 1。
  - §3 接口 + 三实现：`ProfileRepository`/`LocalProfileRepository` → Task 1/2；`OutreachEmailRepository`/`AiOutreachEmailRepository`（接地 JSON）→ Task 1/3；`MockOutreachEmailRepository` → Task 4。
  - §4 交互流程（profile 空→sheet→生成→可编辑草稿页 + 复制/重生成/保存背景；`features/email/`；`/email?pid=`）→ Task 6/7。
  - §5 Prompt（system 规则 + user 拼 导师/学生）→ Task 3 `_systemPrompt`/`_userPrompt`。
  - §6 DI 两 provider → Task 5。
  - §7 测试 7 类全部落位：local_profile（T2）、ai_outreach（T3）、mock_outreach（T4）、email_provider（T6）、email_page（T7）、email_entry_point（T7）、email_repository_provider（T5，文件名 `outreach_email_provider_test`）。
  - §8 偏差（非流式、profile 复用、英文留后）→ 已在「与 spec 的偏差」记录。
- **占位扫描**：无 TBD/TODO；每个 code step 给出完整可编译代码 + 命令与期望。
- **类型一致性**：
  - `OutreachEmailRepository.generate({required Professor professor, required UserProfile profile}) → Future<Result<EmailDraft>>` 在接口(T1)、Ai(T3)、Mock(T4)、各 fake(T6/T7) 一致。
  - `ProfileRepository{load()→UserProfile, save(UserProfile)→Future<void>}` 在接口(T1)、Local(T2)、fake(T7) 一致。
  - `EmailNotifier`：`start(String)`、`generate({required Professor, required UserProfile})`、`EmailState{professorId,status,draft,message}`、`EmailStatus{idle,generating,ready,error}` 在 provider(T6)、page(T7)、测试一致；page `_buildBody` switch 覆盖 4 个枚举值（穷尽）。
  - `LlmClient.complete(...)` 签名沿用 M1，未改；新增 `_FakeLlm` 仅实现 `complete`（M2 耦合见顶部说明）。
  - `professorProvider`（`FutureProvider.family<Professor,String>`）、`professorRepositoryProvider`（`getProfessor(String)→Future<Result<Professor>>`）、`localStoreProvider`、`appConfigProvider` 均为既有，用法与现有代码一致。
- **接线/路由**：`/email?pid=` 路由(T7 Step6) + 详情页 `FilledButton`(T7 Step9) + 入口测试(T7 Step7)；DI `outreachEmailRepositoryProvider` 三分支覆盖 `DataSource`(T5)。
- **不回归**：仅新增文件 + 在 `providers.dart`/`app_router.dart`/`professor_page.dart` 追加（不改既有行为）；默认 `mock`；详情页 FAB「继续追问」保留，新按钮置正文内。Task 8 跑全量回归。
- **Widget 测试要点**：`Clipboard.setData` 在测试环境不抛错（平台通道默认返回），故「复制」用例断言 SnackBar 文案即可；`professorRepositoryProvider` override 提供 `Professor`，避免依赖 SharedPreferences；page 用例预置非空 profile 以跳过首次 sheet，专测草稿页与保存背景。
- **已知偏差留痕**：详情页入口为正文内按钮（FAB 已占用）；「复制」复制「主题 + 正文」；`emailProvider` 切换导师 `start()` 重置避免草稿残留。
