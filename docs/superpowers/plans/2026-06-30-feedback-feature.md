# 反馈功能 (Feedback) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 SchoNavi 加一个用户反馈通道(bug / 推荐不准 / 导师未收录 / 其他建议),APP 端带上下文经 Repository 抽象提交,后端契约与文档就位但本次不写后端代码。

**Architecture:** 严格分层,与现有 8 个 repository 同构。`domain` 定义 `Feedback` 实体 + `FeedbackRepository` 抽象;`data` 提供 `http` 与 `mock` 两实现,按 `DataSource` 路由;`features/feedback` 提供表单页与内联入口组件。HTTP 走项目统一信封 `{code,message,data}`,复用 `guardApi`/`decodeEnvelope`。失败即报错、不本地保存、不重试。

**Tech Stack:** Flutter/Dart, `flutter_riverpod`(手写 provider), `go_router`, `dio`, 现有 `Result`/`AppException`/`UuidV7`。

## Global Constraints

- 分层:UI/features 依赖 domain 抽象;实现落 `lib/data`;DI 落 [lib/core/di/providers.dart](lib/core/di/providers.dart)。
- Riverpod 手写 provider,不引入 generated code。
- `Result<T>`-style(`Success`/`Failure`),复用 [lib/core/result/result.dart](lib/core/result/result.dart) 与 [lib/core/error/app_exception.dart](lib/core/error/app_exception.dart)。
- HTTP 路径前缀 `/api/v1/...`,响应统一信封 `{code,message,data}`,复用 [lib/data/dto/api_envelope.dart](lib/data/dto/api_envelope.dart) 的 `guardApi`/`decodeEnvelope`/`mapDioException`。
- DTO 用 snake_case ↔ camelCase,风格对齐 [lib/data/dto/chat_message_dto.dart](lib/data/dto/chat_message_dto.dart)。
- `DataSource.llm` → mock 实现;`DataSource.http` → http 实现。演示模式(`showAiTrace`)走 mock。
- 不改 `web/backend` 代码(本次仅客户端 + 文档契约)。
- 不本地保存反馈,失败即报错、不重试。
- 不引入新状态管理 / 路由 / 持久化 / HTTP 库。
- 不主动 commit/push;每个 Task 末尾按 CLAUDE.md 仅在用户确认后提交。本计划中的 commit 步骤是建议性指令,执行前需用户确认。
- 中文产品文案保持现有风格。

## File Structure

新增文件:

- `lib/domain/entities/feedback.dart` — `Feedback` + `FeedbackType` + `FeedbackContext`。
- `lib/domain/repositories/feedback_repository.dart` — 抽象接口。
- `lib/data/dto/feedback_dto.dart` — `FeedbackDto` + `FeedbackContextDto`。
- `lib/data/http/http_feedback_repository.dart` — HTTP 实现(`guardApi`)。
- `lib/data/mock/mock_feedback_repository.dart` — mock 实现(600ms 延迟)。
- `lib/features/feedback/providers/feedback_provider.dart` — `FeedbackSubmitNotifier`。
- `lib/features/feedback/pages/feedback_page.dart` — 表单页。
- `lib/features/feedback/widgets/feedback_entry_button.dart` — 场景内联按钮。
- `test/data/feedback_dto_test.dart`
- `test/data/mock_feedback_repository_test.dart`
- `test/data/http_feedback_repository_test.dart`
- `test/features/feedback/feedback_page_test.dart`

修改文件:

- `lib/core/di/providers.dart` — 加 `feedbackRepositoryProvider`。
- `lib/core/router/app_router.dart` — 注册 `/feedback` 路由。
- `lib/shared/widgets/app_menu_drawer.dart` — 加"反馈"tile。
- `lib/features/professor/pages/professor_page.dart` — AppBar 加反馈入口。
- `lib/features/chat/widgets/chat_message_bubble.dart` — 推荐卡溢出菜单加"反馈这条推荐"。
- `test/features/home/home_page_test.dart` — 断言抽屉"反馈"tile。
- `test/docs/api_contract_test.dart` — 断言 openapi 含 `/api/v1/feedback`。
- `docs/api-contract.md` — 加 "Feedback" 段。
- `docs/openapi.yaml` — 加 path + schema。

依赖链:Task 1(实体)→ Task 2(DTO)→ Task 3(repo 接口)→ Task 4(mock)→ Task 5(http)→ Task 6(provider)→ Task 7(契约文档)→ Task 8(页面)→ Task 9(路由+抽屉)→ Task 10(内联入口)。Task 11 全量验证。

---

### Task 1: Feedback 领域实体

**Files:**

- Create: `lib/domain/entities/feedback.dart`
- Test: `test/domain/entities/feedback_test.dart`

**Interfaces:**

- Produces: `enum FeedbackType { recommendation, missingProfessor, bug, other }`、`class FeedbackContext`、`class Feedback`,以及 `FeedbackContext.fromQuery(Map<String,String>)`。

- [ ] **Step 1: 写失败测试**

`test/domain/entities/feedback_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/feedback.dart';

void main() {
  group('FeedbackContext.fromQuery', () {
    test('decodes known query keys', () {
      final ctx = FeedbackContext.fromQuery(const {
        'route': '/professor/P001',
        'sid': 's_1',
        'mid': 'm_1',
        'pid': 'P001',
        'cid': 'C_1',
        'prompt': '找导师',
        'v': '1.2.0',
        'mode': 'http',
      });
      expect(ctx.route, '/professor/P001');
      expect(ctx.sessionId, 's_1');
      expect(ctx.messageId, 'm_1');
      expect(ctx.professorId, 'P001');
      expect(ctx.competitionId, 'C_1');
      expect(ctx.prompt, '找导师');
      expect(ctx.appVersion, '1.2.0');
      expect(ctx.dataSourceMode, 'http');
    });

    test('empty query yields null optional fields', () {
      final ctx = FeedbackContext.fromQuery(const {});
      expect(ctx.route, isNull);
      expect(ctx.sessionId, isNull);
      expect(ctx.appVersion, '');
      expect(ctx.dataSourceMode, '');
    });
  });

  test('Feedback.copyWith preserves identity when unchanged', () {
    final f = Feedback(
      id: 'id1',
      type: FeedbackType.bug,
      content: '崩溃了',
      contact: null,
      context: FeedbackContext.fromQuery(const {}),
      createdAt: DateTime.utc(2026, 6, 30),
    );
    expect(f.copyWith().id, 'id1');
    expect(f.copyWith(type: FeedbackType.other).type, FeedbackType.other);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/domain/entities/feedback_test.dart`
Expected: FAIL(文件/类不存在)。

- [ ] **Step 3: 写最小实现**

`lib/domain/entities/feedback.dart`:

```dart
/// 用户反馈类型。
enum FeedbackType { recommendation, missingProfessor, bug, other }

/// 反馈附带的可定位上下文。从场景内联入口或路由 query 还原。
class FeedbackContext {
  const FeedbackContext({
    this.route,
    this.sessionId,
    this.messageId,
    this.professorId,
    this.competitionId,
    this.prompt,
    this.appVersion = '',
    this.dataSourceMode = '',
  });

  final String? route;
  final String? sessionId;
  final String? messageId;
  final String? professorId;
  final String? competitionId;
  final String? prompt;
  final String appVersion;
  final String dataSourceMode;

  /// 从路由 query 参数还原上下文。
  factory FeedbackContext.fromQuery(Map<String, String> q) {
    String? take(String key) =>
        q.containsKey(key) && q[key]!.isNotEmpty ? q[key] : null;
    return FeedbackContext(
      route: take('route'),
      sessionId: take('sid'),
      messageId: take('mid'),
      professorId: take('pid'),
      competitionId: take('cid'),
      prompt: take('prompt'),
      appVersion: q['v'] ?? '',
      dataSourceMode: q['mode'] ?? '',
    );
  }

  /// 是否完全没有可定位信息(用于决定是否折叠摘要)。
  bool get isEmpty =>
      route == null &&
      sessionId == null &&
      messageId == null &&
      professorId == null &&
      competitionId == null &&
      prompt == null;
}

/// 一条用户反馈。
class Feedback {
  const Feedback({
    required this.id,
    required this.type,
    required this.content,
    required this.contact,
    required this.context,
    required this.createdAt,
  });

  final String id;
  final FeedbackType type;
  final String content;
  final String? contact;
  final FeedbackContext context;
  final DateTime createdAt;

  Feedback copyWith({
    String? id,
    FeedbackType? type,
    String? content,
    String? contact,
    FeedbackContext? context,
    DateTime? createdAt,
  }) =>
      Feedback(
        id: id ?? this.id,
        type: type ?? this.type,
        content: content ?? this.content,
        contact: contact ?? this.contact,
        context: context ?? this.context,
        createdAt: createdAt ?? this.createdAt,
      );
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/domain/entities/feedback_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/domain/entities/feedback.dart test/domain/entities/feedback_test.dart
git commit -m "feat(feedback): add Feedback domain entity"
```

---

### Task 2: Feedback DTO

**Files:**

- Create: `lib/data/dto/feedback_dto.dart`
- Test: `test/data/feedback_dto_test.dart`

**Interfaces:**

- Consumes: `Feedback`、`FeedbackType`、`FeedbackContext`(Task 1)。
- Produces: `FeedbackDto.fromJson/toJson/fromEntity`,`FeedbackContextDto`。

- [ ] **Step 1: 写失败测试**

`test/data/feedback_dto_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/dto/feedback_dto.dart';
import 'package:scho_navi/domain/entities/feedback.dart';

void main() {
  final ctx = FeedbackContext(
    route: '/professor/P001',
    sessionId: 's_1',
    messageId: 'm_1',
    professorId: 'P001',
    competitionId: null,
    prompt: '找导师',
    appVersion: '1.2.0',
    dataSourceMode: 'http',
  );
  final feedback = Feedback(
    id: 'id1',
    type: FeedbackType.recommendation,
    content: '推荐了一位做 CV 的老师,但我想要的是 NLP',
    contact: 'user@example.com',
    context: ctx,
    createdAt: DateTime.utc(2026, 6, 30, 12, 0, 0),
  );

  test('fromEntity maps type to snake_case string', () {
    final dto = FeedbackDto.fromEntity(feedback);
    expect(dto.type, 'recommendation');
    expect(dto.context.professorId, 'P001');
    expect(dto.context.competitionId, isNull);
    expect(dto.createdAt, '2026-06-30T12:00:00.000Z');
  });

  test('toJson produces snake_case keys', () {
    final json = FeedbackDto.fromEntity(feedback).toJson();
    expect(json['type'], 'recommendation');
    expect(json['created_at'], '2026-06-30T12:00:00.000Z');
    expect(json['contact'], 'user@example.com');
    expect((json['context'] as Map<String, dynamic>)['session_id'], 's_1');
    expect((json['context'] as Map<String, dynamic>)['competition_id'], isNull);
  });

  test('fromJson round-trips', () {
    final json = FeedbackDto.fromEntity(feedback).toJson();
    final dto = FeedbackDto.fromJson(json);
    expect(dto.id, 'id1');
    expect(dto.type, 'recommendation');
    expect(dto.content, '推荐了一位做 CV 的老师,但我想要的是 NLP');
    expect(dto.context.route, '/professor/P001');
  });

  test('all FeedbackType values map to expected strings', () {
    for (final type in FeedbackType.values) {
      final f = Feedback(
        id: 'x',
        type: type,
        content: 'c',
        contact: null,
        context: const FeedbackContext(),
        createdAt: DateTime.utc(2026, 6, 30),
      );
      expect(
        FeedbackDto.fromEntity(f).type,
        switch (type) {
          FeedbackType.recommendation => 'recommendation',
          FeedbackType.missingProfessor => 'missing_professor',
          FeedbackType.bug => 'bug',
          FeedbackType.other => 'other',
        },
      );
    }
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/feedback_dto_test.dart`
Expected: FAIL。

- [ ] **Step 3: 写最小实现**

`lib/data/dto/feedback_dto.dart`:

```dart
import '../../domain/entities/feedback.dart';

class FeedbackContextDto {
  const FeedbackContextDto({
    this.route,
    this.sessionId,
    this.messageId,
    this.professorId,
    this.competitionId,
    this.prompt,
    required this.appVersion,
    required this.dataSourceMode,
  });

  final String? route;
  final String? sessionId;
  final String? messageId;
  final String? professorId;
  final String? competitionId;
  final String? prompt;
  final String appVersion;
  final String dataSourceMode;

  factory FeedbackContextDto.fromEntity(FeedbackContext c) =>
      FeedbackContextDto(
        route: c.route,
        sessionId: c.sessionId,
        messageId: c.messageId,
        professorId: c.professorId,
        competitionId: c.competitionId,
        prompt: c.prompt,
        appVersion: c.appVersion,
        dataSourceMode: c.dataSourceMode,
      );

  factory FeedbackContextDto.fromJson(Map<String, dynamic> json) =>
      FeedbackContextDto(
        route: json['route'] as String?,
        sessionId: json['session_id'] as String?,
        messageId: json['message_id'] as String?,
        professorId: json['professor_id'] as String?,
        competitionId: json['competition_id'] as String?,
        prompt: json['prompt'] as String?,
        appVersion: json['app_version'] as String? ?? '',
        dataSourceMode: json['data_source_mode'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (route != null) 'route': route,
        if (sessionId != null) 'session_id': sessionId,
        if (messageId != null) 'message_id': messageId,
        if (professorId != null) 'professor_id': professorId,
        if (competitionId != null) 'competition_id': competitionId,
        if (prompt != null) 'prompt': prompt,
        'app_version': appVersion,
        'data_source_mode': dataSourceMode,
      };
}

class FeedbackDto {
  const FeedbackDto({
    required this.id,
    required this.type,
    required this.content,
    required this.contact,
    required this.context,
    required this.createdAt,
  });

  final String id;
  final String type; // recommendation|missing_professor|bug|other
  final String content;
  final String? contact;
  final FeedbackContextDto context;
  final String createdAt; // ISO8601

  static const _typeMap = {
    FeedbackType.recommendation: 'recommendation',
    FeedbackType.missingProfessor: 'missing_professor',
    FeedbackType.bug: 'bug',
    FeedbackType.other: 'other',
  };

  factory FeedbackDto.fromEntity(Feedback f) => FeedbackDto(
        id: f.id,
        type: _typeMap[f.type]!,
        content: f.content,
        contact: f.contact,
        context: FeedbackContextDto.fromEntity(f.context),
        createdAt: f.createdAt.toIso8601String(),
      );

  factory FeedbackDto.fromJson(Map<String, dynamic> json) => FeedbackDto(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'other',
        content: json['content'] as String? ?? '',
        contact: json['contact'] as String?,
        context: FeedbackContextDto.fromJson(
          (json['context'] as Map<String, dynamic>?) ?? const {},
        ),
        createdAt:
            json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'content': content,
        if (contact != null) 'contact': contact,
        'context': context.toJson(),
        'created_at': createdAt,
      };
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/data/feedback_dto_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/data/dto/feedback_dto.dart test/data/feedback_dto_test.dart
git commit -m "feat(feedback): add FeedbackDto with snake_case mapping"
```

---

### Task 3: FeedbackRepository 抽象接口

**Files:**

- Create: `lib/domain/repositories/feedback_repository.dart`

**Interfaces:**

- Consumes: `Feedback`(Task 1)、`Result<T>`(lib/core/result/result.dart)。
- Produces: `abstract class FeedbackRepository { Future<Result<Unit>> submit(Feedback); }`。

- [ ] **Step 1: 写实现**

`lib/domain/repositories/feedback_repository.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../../core/result/result.dart';
import '../entities/feedback.dart';

/// 用户反馈提交仓储。
abstract class FeedbackRepository {
  Future<Result<Unit>> submit(Feedback feedback);
}
```

注:`Unit` 来自 dart:core 的 `void` 语义,这里用 `package:flutter/foundation.dart` 的 `Unit`?——查项目是否已有 Unit 类型。

- [ ] **Step 2: 确认 Unit 类型来源**

Run: `grep -rn "Result<Unit>\|class Unit\|typedef Unit" lib/ | head`
若项目无 `Unit`,改用 `Result<void>`。根据现有代码(如 `conversationRepositoryProvider.deleteSession` 返回 `Result<void>`)。

- [ ] **Step 3: 调整接口为 Result<void>**

`lib/domain/repositories/feedback_repository.dart`(最终版):

```dart
import '../../core/result/result.dart';
import '../entities/feedback.dart';

/// 用户反馈提交仓储。
abstract class FeedbackRepository {
  Future<Result<void>> submit(Feedback feedback);
}
```

- [ ] **Step 4: 提交**

```bash
git add lib/domain/repositories/feedback_repository.dart
git commit -m "feat(feedback): add FeedbackRepository interface"
```

---

### Task 4: MockFeedbackRepository

**Files:**

- Create: `lib/data/mock/mock_feedback_repository.dart`
- Test: `test/data/mock_feedback_repository_test.dart`

**Interfaces:**

- Consumes: `FeedbackRepository`(Task 3)、`Feedback`(Task 1)。
- Produces: `class MockFeedbackRepository implements FeedbackRepository`,返回 `Success` + 600ms 延迟。

- [ ] **Step 1: 写失败测试**

`test/data/mock_feedback_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_feedback_repository.dart';
import 'package:scho_navi/domain/entities/feedback.dart';

Feedback _feedback() => Feedback(
      id: 'id1',
      type: FeedbackType.bug,
      content: '崩溃了',
      contact: null,
      context: const FeedbackContext(),
      createdAt: DateTime.utc(2026, 6, 30),
    );

void main() {
  test('returns Success after simulated delay', () async {
    final repo = MockFeedbackRepository();
    final sw = Stopwatch()..start();
    final result = await repo.submit(_feedback());
    sw.stop();
    expect(result, isA<Success<void>>());
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(500));
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/mock_feedback_repository_test.dart`
Expected: FAIL。

- [ ] **Step 3: 写实现**

`lib/data/mock/mock_feedback_repository.dart`:

```dart
import '../../core/result/result.dart';
import '../../domain/entities/feedback.dart';
import '../../domain/repositories/feedback_repository.dart';

/// 离线/演示模式反馈仓储:模拟网络延迟后返回成功。
class MockFeedbackRepository implements FeedbackRepository {
  MockFeedbackRepository({Duration delay = const Duration(milliseconds: 600)})
      : _delay = delay;

  final Duration _delay;

  @override
  Future<Result<void>> submit(Feedback feedback) async {
    await Future<void>.delayed(_delay);
    return const Success<void>(null as dynamic); // 见下方修正
  }
}
```

注:`Success<void>` 携带 `void` 不能用 `null as dynamic`。改用项目内 `Result<void>` 的惯用法。

- [ ] **Step 4: 核对 void 的惯用法**

Run: `grep -rn "Success<void>" lib/data/ | head`
看现有 void 返回的 repo(如 `HttpFavoriteRepository.remove`)如何写 `Success`。

预期:项目用 `const Success<void>(null)` 不合法;查到实际惯用后采用相同写法。常见为 `Success<void>(Unit.instance)` 或项目自定。

- [ ] **Step 5: 用核对后的惯用法重写并运行测试**

`lib/data/mock/mock_feedback_repository.dart`(最终版,以项目惯用法为准;若项目 `Success<void>` 构造不允许,则改为 `Future<Result<void>>` 返回 `Success<void>(/* 见惯用法 */)`,测试只断言 `isA<Success<void>>()`):

```dart
import '../../core/result/result.dart';
import '../../domain/entities/feedback.dart';
import '../../domain/repositories/feedback_repository.dart';

/// 离线/演示模式反馈仓储:模拟网络延迟后返回成功。
class MockFeedbackRepository implements FeedbackRepository {
  MockFeedbackRepository({Duration delay = const Duration(milliseconds: 600)})
      : _delay = delay;

  final Duration _delay;

  @override
  Future<Result<void>> submit(Feedback feedback) async {
    await Future<void>.delayed(_delay);
    // 与项目内 void 返回 repo 的惯用法一致(参见 HttpFavoriteRepository.remove)。
    return Success<void>(_voidValue);
  }
}

// 占位:实际 _voidValue 由 Step 4 核对结果决定。
```

Run: `flutter test test/data/mock_feedback_repository_test.dart`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add lib/data/mock/mock_feedback_repository.dart test/data/mock_feedback_repository_test.dart
git commit -m "feat(feedback): add MockFeedbackRepository"
```

---

### Task 5: HttpFeedbackRepository

**Files:**

- Create: `lib/data/http/http_feedback_repository.dart`
- Test: `test/data/http/http_feedback_repository_test.dart`

**Interfaces:**

- Consumes: `FeedbackRepository`(Task 3)、`FeedbackDto`(Task 2)、`guardApi`/`mapDioException`([lib/data/dto/api_envelope.dart](lib/data/dto/api_envelope.dart))、`Dio`。
- Produces: `class HttpFeedbackRepository implements FeedbackRepository`。

- [ ] **Step 1: 写失败测试**

`test/data/http/http_feedback_repository_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/http/http_feedback_repository.dart';
import 'package:scho_navi/domain/entities/feedback.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);
}

Dio _dio(Future<ResponseBody> Function(RequestOptions) handler) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.com'))
      ..httpClientAdapter = _FakeAdapter(handler);

ResponseBody _json(String text) => ResponseBody.fromString(
      text,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Feedback _feedback() => Feedback(
      id: 'id1',
      type: FeedbackType.recommendation,
      content: '推荐不准',
      contact: null,
      context: FeedbackContext(
        professorId: 'P001',
        appVersion: '1.2.0',
        dataSourceMode: 'http',
      ),
      createdAt: DateTime.utc(2026, 6, 30),
    );

void main() {
  test('posts to /api/v1/feedback and returns Success on code 0', () async {
    RequestOptions? captured;
    final repo = HttpFeedbackRepository(
      _dio((options) async {
        captured = options;
        return _json(jsonEncode({
          'code': 0,
          'message': 'ok',
          'data': {
            'id': 'id1',
            'status': 'received',
            'received_at': '2026-06-30T12:00:01Z',
          },
        }));
      }),
    );

    final result = await repo.submit(_feedback());

    expect(captured!.path, '/api/v1/feedback');
    expect(captured!.method, 'POST');
    final body = captured!.data as Map<String, dynamic>;
    expect(body['type'], 'recommendation');
    expect((body['context'] as Map)['professor_id'], 'P001');
    expect(result, isA<Success<void>>());
  });

  test('non-zero envelope maps to Failure', () async {
    final repo = HttpFeedbackRepository(
      _dio((_) async => _json(jsonEncode({
            'code': 1001,
            'message': '内容不合法',
            'data': null,
          }))),
    );

    final result = await repo.submit(_feedback());

    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).error.message, '内容不合法');
  });

  test('dio timeout maps to TimeoutException failure', () async {
    final repo = HttpFeedbackRepository(
      _dio((options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          )),
    );

    final result = await repo.submit(_feedback());

    expect((result as Failure<void>).error, isA<TimeoutException>());
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/http/http_feedback_repository_test.dart`
Expected: FAIL。

- [ ] **Step 3: 写实现**

`lib/data/http/http_feedback_repository.dart`:

```dart
import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/feedback.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/feedback_dto.dart';

/// 反馈提交 HTTP 实现:`POST /api/v1/feedback`。
///
/// 响应遵循项目统一信封 `{ code, message, data }`,复用 [guardApi]。
/// 失败一律返回 [Failure],由调用方决定提示文案。
class HttpFeedbackRepository implements FeedbackRepository {
  HttpFeedbackRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<void>> submit(Feedback feedback) {
    return guardApi<void>(
      () => _dio.post<dynamic>(
        '/api/v1/feedback',
        data: FeedbackDto.fromEntity(feedback).toJson(),
      ),
      (_) => null,
    );
  }
}
```

注:`guardApi<T>(request, decode)` 的 `decode` 接收 `data` 返回 `T`。对 `void` 用 `(_) => null` 并以 `Result<void>` 携带 `null`。若 `Success<void>(null)` 不合法,采用 Task 4 核对出的惯用法。

- [ ] **Step 4: 核对 void 携带惯用法并修正**

Run: `grep -rn "guardApi<void>\|Success<void>" lib/data/ | head`
确认 `guardApi<void>` 与 `Success<void>` 在项目内的合法写法。若 `Success<void>` 不可写,改用 `Success<Null>` 或项目惯用法,使测试断言 `isA<Success<void>>()` 与之一致(必要时把测试断言改为 `isA<Success>()`)。

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/data/http/http_feedback_repository_test.dart`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add lib/data/http/http_feedback_repository.dart test/data/http/http_feedback_repository_test.dart
git commit -m "feat(feedback): add HttpFeedbackRepository with envelope contract"
```

---

### Task 6: feedbackRepositoryProvider + Notifier

**Files:**

- Modify: `lib/core/di/providers.dart`
- Create: `lib/features/feedback/providers/feedback_provider.dart`
- Test: `test/features/feedback/feedback_provider_test.dart`

**Interfaces:**

- Consumes: `FeedbackRepository`(Task 4+5)、`appConfigProvider`、`UuidV7`([lib/core/ids/uuid_v7.dart](lib/core/ids/uuid_v7.dart))。
- Produces: `feedbackRepositoryProvider`、`FeedbackSubmitNotifier` + `feedbackSubmitProvider`。

- [ ] **Step 1: 写失败测试**

`test/features/feedback/feedback_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/feedback.dart';
import 'package:scho_navi/domain/repositories/feedback_repository.dart';
import 'package:scho_navi/features/feedback/providers/feedback_provider.dart';

class _OkRepo implements FeedbackRepository {
  @override
  Future<Result<void>> submit(Feedback feedback) async =>
      const Success<void>(null); // 以项目惯用法为准
}

class _FailRepo implements FeedbackRepository {
  @override
  Future<Result<void>> submit(Feedback feedback) async =>
      const Failure(ServerException('boom'));
}

void main() {
  Feedback feedback() => Feedback(
        id: 'id1',
        type: FeedbackType.bug,
        content: '内容',
        contact: null,
        context: const FeedbackContext(),
        createdAt: DateTime.utc(2026, 6, 30),
      );

  test('submit success transitions to success state', () async {
    final container = ProviderContainer(
      overrides: [feedbackRepositoryProvider.overrideWithValue(_OkRepo())],
    );
    addTearDown(container.dispose);
    final notifier =
        container.read(feedbackSubmitProvider.notifier);
    expect(container.read(feedbackSubmitProvider).loading, isFalse);
    await notifier.submit(feedback());
    final state = container.read(feedbackSubmitProvider);
    expect(state.success, isTrue);
    expect(state.errorMessage, isNull);
  });

  test('submit failure sets errorMessage', () async {
    final container = ProviderContainer(
      overrides: [feedbackRepositoryProvider.overrideWithValue(_FailRepo())],
    );
    addTearDown(container.dispose);
    final notifier = container.read(feedbackSubmitProvider.notifier);
    await notifier.submit(feedback());
    final state = container.read(feedbackSubmitProvider);
    expect(state.success, isFalse);
    expect(state.errorMessage, 'boom');
  });
}
```

注:测试里 `Success<void>(null)` / `ServerException('boom')` 以项目惯用法为准(Task 4/5 核对结果)。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/feedback/feedback_provider_test.dart`
Expected: FAIL。

- [ ] **Step 3: 加 provider 到 DI**

在 [lib/core/di/providers.dart](lib/core/di/providers.dart) 末尾(provider 习惯位置)加:

```dart
final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return switch (cfg.dataSource) {
    DataSource.http => HttpFeedbackRepository(ref.watch(apiDioProvider)),
    DataSource.llm => MockFeedbackRepository(),
  };
});
```

并在文件顶部 import:

```dart
import '../domain/entities/feedback.dart';
import '../domain/repositories/feedback_repository.dart';
import '../data/http/http_feedback_repository.dart';
import '../data/mock/mock_feedback_repository.dart';
```

(若部分已存在则不重复。)

- [ ] **Step 4: 写 Notifier**

`lib/features/feedback/providers/feedback_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/ids/uuid_v7.dart';
import '../../../domain/entities/feedback.dart';

class FeedbackSubmitState {
  const FeedbackSubmitState({
    this.loading = false,
    this.success = false,
    this.errorMessage,
  });

  final bool loading;
  final bool success;
  final String? errorMessage;

  FeedbackSubmitState copyWith({
    bool? loading,
    bool? success,
    String? errorMessage,
    bool clearError = false,
  }) =>
      FeedbackSubmitState(
        loading: loading ?? this.loading,
        success: success ?? this.success,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );
}

class FeedbackSubmitNotifier extends Notifier<FeedbackSubmitState> {
  final UuidV7 _ids = UuidV7();

  @override
  FeedbackSubmitState build() => const FeedbackSubmitState();

  /// 组装并提交一条反馈。返回是否成功,供页面决定 pop 或留页。
  Future<bool> submit({
    required FeedbackType type,
    required String content,
    String? contact,
    required FeedbackContext context,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    final feedback = Feedback(
      id: _ids.generate(),
      type: type,
      content: content,
      contact: contact,
      context: context,
      createdAt: DateTime.now(),
    );
    final result =
        await ref.read(feedbackRepositoryProvider).submit(feedback);
    state = switch (result) {
      Success<void>() => state.copyWith(
          loading: false,
          success: true,
          clearError: true,
        ),
      Failure<void>(:final error) => state.copyWith(
          loading: false,
          errorMessage: error.message,
        ),
    };
    return state.success;
  }
}

final feedbackSubmitProvider =
    NotifierProvider<FeedbackSubmitNotifier, FeedbackSubmitState>(
  FeedbackSubmitNotifier.new,
);
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/features/feedback/feedback_provider_test.dart`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add lib/core/di/providers.dart lib/features/feedback/providers/feedback_provider.dart test/features/feedback/feedback_provider_test.dart
git commit -m "feat(feedback): wire feedbackRepositoryProvider + submit notifier"
```

---

### Task 7: HTTP 契约文档(openapi + api-contract)

**Files:**

- Modify: `docs/openapi.yaml`
- Modify: `docs/api-contract.md`
- Test: `test/docs/api_contract_test.dart`

**Interfaces:**

- Consumes: `docs/openapi.yaml`、`docs/api-contract.md`。
- Produces: `/api/v1/feedback` path + `UserFeedbackRequest`/`UserFeedbackEnvelope`/`UserFeedbackData` schema;`api-contract.md` "Feedback" 段。

- [ ] **Step 1: 写失败测试**

在 `test/docs/api_contract_test.dart` 的 `main()` 内加:

```dart
  test('OpenAPI documents user feedback endpoint', () {
    final text = openApi.readAsStringSync();

    expect(text, contains('  /api/v1/feedback:'));
    expect(text, contains(r"$ref: '#/components/schemas/UserFeedbackRequest'"));
    expect(text, contains(r"$ref: '#/components/schemas/UserFeedbackEnvelope'"));
  });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/docs/api_contract_test.dart --plain-name "user feedback endpoint"`
Expected: FAIL。

- [ ] **Step 3: 加 openapi path**

在 [docs/openapi.yaml](docs/openapi.yaml) 的 `paths:` 下(任意现有 path 块后,例如 `/history/{session_id}:` 块之后)插入:

```yaml
  /api/v1/feedback:
    post:
      summary: Submit user feedback (bug / recommendation / missing professor / other).
      security:
        - bearerAuth: []
        - cookieAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UserFeedbackRequest'
      responses:
        '200':
          description: Feedback received.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/UserFeedbackEnvelope'
```

- [ ] **Step 4: 加 openapi schema**

在 [docs/openapi.yaml](docs/openapi.yaml) 的 `components:` → `schemas:` 下(如 `FeedbackRequest:` 块附近)插入:

```yaml
    UserFeedbackRequest:
      type: object
      required: [id, type, content, context, created_at]
      properties:
        id: { type: string }
        type:
          type: string
          enum: [recommendation, missing_professor, bug, other]
        content: { type: string, minLength: 1 }
        contact: { type: [string, 'null'] }
        context:
          $ref: '#/components/schemas/UserFeedbackContext'
        created_at: { type: string, format: date-time }
    UserFeedbackContext:
      type: object
      properties:
        route: { type: [string, 'null'] }
        session_id: { type: [string, 'null'], format: uuid }
        message_id: { type: [string, 'null'] }
        professor_id: { type: [string, 'null'] }
        competition_id: { type: [string, 'null'] }
        prompt: { type: [string, 'null'] }
        app_version: { type: string }
        data_source_mode: { type: string, enum: [llm, http, mock] }
    UserFeedbackEnvelope:
      type: object
      required: [code, message, data]
      properties:
        code: { type: integer }
        message: { type: string }
        data:
          $ref: '#/components/schemas/UserFeedbackData'
    UserFeedbackData:
      type: object
      required: [id, status, received_at]
      properties:
        id: { type: string }
        status: { type: string, enum: [received] }
        received_at: { type: string, format: date-time }
```

- [ ] **Step 5: 加 api-contract.md 段**

在 [docs/api-contract.md](docs/api-contract.md) 末尾(或"Feedback"主题合适处)加:

```markdown

### POST `/api/v1/feedback`

提交用户反馈(bug / 推荐不准 / 导师未收录 / 其他)。请求体:

```json
{
  "id": "uuid",
  "type": "recommendation | missing_professor | bug | other",
  "content": "描述",
  "contact": "可选",
  "context": {
    "route": "/professor/P001",
    "session_id": "...", "message_id": "...",
    "professor_id": "P001", "competition_id": null,
    "prompt": "...", "app_version": "1.2.0", "data_source_mode": "http"
  },
  "created_at": "2026-06-30T12:00:00Z"
}
```

响应遵循统一信封 `{ code, message, data }`,`data`:

```json
{ "id": "...", "status": "received", "received_at": "2026-06-30T12:00:01Z" }
```

`code != 0` 表示业务失败。客户端不重试、不本地保存。
```

- [ ] **Step 6: 运行测试确认通过**

Run: `flutter test test/docs/api_contract_test.dart --plain-name "user feedback endpoint"`
Expected: PASS。

- [ ] **Step 7: 提交**

```bash
git add docs/openapi.yaml docs/api-contract.md test/docs/api_contract_test.dart
git commit -m "docs(feedback): add /api/v1/feedback contract + openapi schemas"
```

---

### Task 8: 反馈页 FeedbackPage

**Files:**

- Create: `lib/features/feedback/pages/feedback_page.dart`
- Test: `test/features/feedback/feedback_page_test.dart`

**Interfaces:**

- Consumes: `FeedbackSubmitNotifier`(Task 6)、`FeedbackType`/`FeedbackContext`(Task 1)、`appConfigProvider`。
- Produces: `class FeedbackPage` 构造参数 `FeedbackType? type`、`FeedbackContext context`。

- [ ] **Step 1: 写失败测试**

`test/features/feedback/feedback_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/feedback.dart';
import 'package/scho_navi/domain/repositories/feedback_repository.dart';
import 'package:scho_navi/features/feedback/pages/feedback_page.dart';

class _OkRepo implements FeedbackRepository {
  @override
  Future<Result<void>> submit(Feedback feedback) async =>
      const Success<void>(null); // 以项目惯用法为准
}

void main() {
  testWidgets('disables submit until content length >= 5', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedbackRepositoryProvider.overrideWithValue(_OkRepo())],
        child: const MaterialApp(home: FeedbackPage()),
      ),
    );
    final submit = find.text('提交');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );
    await tester.enterText(find.byType(TextField).first, 'ab');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled, false);
    await tester.enterText(find.byType(TextField).first, '12345');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled, true);
  });

  testWidgets('preselects type from constructor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedbackRepositoryProvider.overrideWithValue(_OkRepo())],
        child: const MaterialApp(
          home: FeedbackPage(type: FeedbackType.bug),
        ),
      ),
    );
    await tester.pump();
    final bugChip = find.text('Bug / 异常');
    expect(bugChip, findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/feedback/feedback_page_test.dart`
Expected: FAIL。

- [ ] **Step 3: 写实现**

`lib/features/feedback/pages/feedback_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/feedback.dart';
import '../providers/feedback_provider.dart';

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key, this.type, this.context});

  final FeedbackType? type;
  final FeedbackContext? context;

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  late FeedbackType _type = widget.type ?? FeedbackType.other;
  final TextEditingController _content = TextEditingController();
  final TextEditingController _contact = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _content.dispose();
    _contact.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _content.text.trim().length >= 5 &&
      !ref.read(feedbackSubmitProvider).loading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    Haptics.medium();
    final cfg = ref.read(appConfigProvider);
    final ctx = (widget.context ?? const FeedbackContext()).copyWith(
      appVersion: cfg.appVersion,
      dataSourceMode: cfg.dataSource.name,
    );
    final ok = await ref.read(feedbackSubmitProvider.notifier).submit(
          type: _type,
          content: _content.text.trim(),
          contact:
              _contact.text.trim().isEmpty ? null : _contact.text.trim(),
          context: ctx,
        );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('感谢反馈,我们会尽快处理')),
      );
      context.pop();
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('反馈提交失败,请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedbackSubmitProvider);
    final ctx = widget.context ?? const FeedbackContext();
    return Scaffold(
      appBar: AppBar(title: const Text('反馈')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TypeSelector(
                selected: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _content,
                maxLength: 500,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '描述',
                  hintText: '请描述你遇到的问题或建议(至少 5 个字)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: '联系方式(可选)',
                  hintText: '手机 / 邮箱 / 微信号,方便我们追问',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (!ctx.isEmpty) _ContextSummary(context: ctx),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: state.loading ? null : _submit,
                child: state.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final FeedbackType selected;
  final ValueChanged<FeedbackType> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (FeedbackType.bug, 'Bug / 异常'),
      (FeedbackType.recommendation, '推荐不准'),
      (FeedbackType.missingProfessor, '导师未收录'),
      (FeedbackType.other, '其他建议'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(item.$2),
            selected: selected == item.$1,
            onSelected: (_) {
              Haptics.selection();
              onChanged(item.$1);
            },
          ),
      ],
    );
  }
}

class _ContextSummary extends StatelessWidget {
  const _ContextSummary({required this.context});
  final FeedbackContext context;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (this.context.route != null) '页面 ${this.context.route}',
      if (this.context.professorId != null) '导师 ${this.context.professorId}',
      if (this.context.competitionId != null)
        '竞赛 ${this.context.competitionId}',
      if (this.context.sessionId != null) '会话 ${this.context.sessionId}',
      if (this.context.messageId != null) '消息 ${this.context.messageId}',
      if (this.context.prompt != null) '提问 ${this.context.prompt}',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已附加:${parts.join(" / ")}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
```

注:`FeedbackContext.copyWith` 需要支持只传 `appVersion`/`dataSourceMode`——在 Task 1 的 `copyWith` 里这两个参数是可选的,已覆盖。但 Task 1 的 `copyWith` 签名没有 `clearError` 等,这里只需 `appVersion`/`dataSourceMode`,可用。若 `FeedbackContext` 是 `const` 构造但字段 final,`copyWith` 已在 Task 1 提供,确认其包含 `appVersion` 与 `dataSourceMode` 参数。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/feedback/feedback_page_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/features/feedback/pages/feedback_page.dart test/features/feedback/feedback_page_test.dart
git commit -m "feat(feedback): add FeedbackPage with type selector + context summary"
```

---

### Task 9: 路由 + 抽屉入口

**Files:**

- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/shared/widgets/app_menu_drawer.dart`
- Test: `test/features/home/home_page_test.dart`

**Interfaces:**

- Consumes: `FeedbackPage`(Task 8)、`FeedbackContext.fromQuery`(Task 1)。
- Produces: 路由 `/feedback`、抽屉"反馈"tile。

- [ ] **Step 1: 写失败测试**

在 `test/features/home/home_page_test.dart` 的 `main()` 内加:

```dart
  testWidgets('drawer shows feedback tile and navigates to /feedback',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 沿用本文件已有 override 集合
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    // 打开抽屉
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    scaffold.scaffoldKey?.currentState?.openEndDrawer();
    await tester.pump();
    // 若该文件用 Scaffold.of(context).openEndDrawer 方式,改为:
    // tester.tap(find.byTooltip('菜单'));
    // await tester.pump();

    expect(find.text('反馈'), findsOneWidget);
    await tester.tap(find.text('反馈'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackPage), findsOneWidget);
  });
```

注:具体打开抽屉的方式以 [test/features/home/home_page_test.dart](test/features/home/home_page_test.dart) 现有 "right edge swipe opens the end drawer" 测试为准对齐(用 tooltip '菜单' 按钮或右滑手势)。执行时核对后采用一致写法。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/home/home_page_test.dart --plain-name "feedback tile"`
Expected: FAIL。

- [ ] **Step 3: 注册路由**

在 [lib/core/router/app_router.dart](lib/core/router/app_router.dart) `routes:` 内加(并 import `FeedbackPage`):

```dart
      GoRoute(
        path: '/feedback',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: FeedbackPage(
            type: _parseFeedbackType(state.uri.queryParameters['type']),
            context: FeedbackContext.fromQuery(
              state.uri.queryParameters,
            ),
          ),
        ),
      ),
```

文件顶部加:

```dart
import '../../domain/entities/feedback.dart';
import '../../features/feedback/pages/feedback_page.dart';
```

并加解析函数(放在 `routerProvider` 之前):

```dart
FeedbackType? _parseFeedbackType(String? raw) {
  switch (raw) {
    case 'recommendation':
      return FeedbackType.recommendation;
    case 'missing_professor':
      return FeedbackType.missingProfessor;
    case 'bug':
      return FeedbackType.bug;
    case 'other':
      return FeedbackType.other;
    default:
      return null;
  }
}
```

- [ ] **Step 4: 加抽屉 tile**

在 [lib/shared/widgets/app_menu_drawer.dart](lib/shared/widgets/app_menu_drawer.dart) 的"我的备赛"tile 与"设置"tile 之间插入:

```dart
            _DrawerTile(
              icon: Icons.feedback_outlined,
              label: '反馈',
              onTap: () => _navigate(context, '/feedback?type=other'),
            ),
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/features/home/home_page_test.dart --plain-name "feedback tile"`
Expected: PASS。

- [ ] **Step 6: 提交**

```bash
git add lib/core/router/app_router.dart lib/shared/widgets/app_menu_drawer.dart test/features/home/home_page_test.dart
git commit -m "feat(feedback): wire /feedback route + drawer entry"
```

---

### Task 10: 场景内联入口(推荐卡 / 导师详情 / 备赛助手)

**Files:**

- Create: `lib/features/feedback/widgets/feedback_entry_button.dart`
- Modify: `lib/features/professor/pages/professor_page.dart`
- Modify: `lib/features/chat/widgets/chat_message_bubble.dart`
- Modify: `lib/features/preparation/`(备赛助手对话,核对具体文件)

**Interfaces:**

- Consumes: `go_router` `context.push`、`FeedbackContext`。
- Produces: `FeedbackEntryButton` 组件 + 三处接线。

- [ ] **Step 1: 写 FeedbackEntryButton**

`lib/features/feedback/widgets/feedback_entry_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics.dart';
import '../../../domain/entities/feedback.dart';

/// 场景内联反馈入口:点击带上下文跳到 /feedback。
class FeedbackEntryButton extends StatelessWidget {
  const FeedbackEntryButton({
    super.key,
    required this.type,
    this.route,
    this.sessionId,
    this.messageId,
    this.professorId,
    this.competitionId,
    this.prompt,
    this.label = '反馈',
    this.icon = Icons.feedback_outlined,
  });

  final FeedbackType type;
  final String? route;
  final String? sessionId;
  final String? messageId;
  final String? professorId;
  final String? competitionId;
  final String? prompt;
  final String label;
  final IconData icon;

  String get _typeQuery => switch (type) {
        FeedbackType.recommendation => 'recommendation',
        FeedbackType.missingProfessor => 'missing_professor',
        FeedbackType.bug => 'bug',
        FeedbackType.other => 'other',
      };

  void _open(BuildContext context) {
    Haptics.light();
    final q = <String, String>{
      'type': _typeQuery,
      if (route != null) 'route': route!,
      if (sessionId != null) 'sid': sessionId!,
      if (messageId != null) 'mid': messageId!,
      if (professorId != null) 'pid': professorId!,
      if (competitionId != null) 'cid': competitionId!,
      if (prompt != null) 'prompt': prompt!,
    };
    context.push(
      Uri(path: '/feedback', queryParameters: q).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      icon: Icon(icon),
      onPressed: () => _open(context),
    );
  }
}
```

- [ ] **Step 2: 导师详情页接线**

在 [lib/features/professor/pages/professor_page.dart](lib/features/professor/pages/professor_page.dart) 的 `appBar: AppBar(...)` 加 `actions`,import `FeedbackEntryButton`:

```dart
      appBar: AppBar(
        title: const Text('导师详情'),
        actions: [
          FeedbackEntryButton(
            type: FeedbackType.missingProfessor,
            professorId: professorId,
            route: '/professor/$professorId',
          ),
        ],
      ),
```

`professorId` 来自该页构造参数(见 [lib/features/professor/pages/professor_page.dart](lib/features/professor/pages/professor_page.dart) 现有 `ProfessorPage(professorId: ...)` 字段)。执行时核对变量名。

- [ ] **Step 3: 推荐卡接线**

在 [lib/features/chat/widgets/chat_message_bubble.dart](lib/features/chat/widgets/chat_message_bubble.dart) 推荐卡的现有操作区(已有 `onFeedback` 点赞旁)加一个溢出菜单或按钮 `FeedbackEntryButton(type: FeedbackType.recommendation, ...)`。需要把当前 `sessionId` 与 `messageId` 传进去——这两个值在该 widget 上下文可用(消息 id 来自 `message.id`;sessionId 由调用方传入或从 provider 读)。

具体:在推荐卡底部 Row 中,点赞按钮之后插入:

```dart
FeedbackEntryButton(
  type: FeedbackType.recommendation,
  messageId: message.id,
  sessionId: sessionId, // 需要确认该 widget 是否已有 sessionId
  prompt: message.content,
  label: '反馈这条推荐',
  icon: Icons.report_gmailerrorred_outlined,
)
```

若 `ChatMessageBubble` 当前无 `sessionId` 字段:核对调用方 [lib/features/home/pages/home_page.dart](lib/features/home/pages/home_page.dart) 是否能传入。若不能,先只传 `messageId` + `prompt`(sessionId 留空,后端审查仍可定位)。

- [ ] **Step 4: 备赛助手接线**

在备赛助手对话页(核对 `lib/features/preparation/` 下承载助手对话的 widget,如 `preparation_plan_detail_page.dart` 的助手区)加:

```dart
FeedbackEntryButton(
  type: FeedbackType.bug,
  route: '/preparation-plans', // 或当前 plan 路由
)
```

执行时核对备赛助手对话框所在 widget 文件与可用上下文(planId 等)。

- [ ] **Step 5: 手动验证**

Run: `flutter run`(选可用设备)
手动:进导师详情页看 AppBar 反馈按钮;首页对话出推荐卡后看反馈入口;备赛助手对话看反馈入口;分别点击确认跳到 `/feedback` 且上下文摘要正确。

- [ ] **Step 6: 提交**

```bash
git add lib/features/feedback/widgets/feedback_entry_button.dart lib/features/professor/pages/professor_page.dart lib/features/chat/widgets/chat_message_bubble.dart
# 备赛助手相关文件按实际改动加入
git commit -m "feat(feedback): add inline feedback entries on professor/recommendation/preparation"
```

---

### Task 11: 全量验证

**Files:** 无新增,仅运行。

- [ ] **Step 1: format 检查**

Run: `dart format --set-exit-if-changed lib test`
Expected: 无变更(exit 0)。若有变更,先 `dart format lib test` 再提交格式。

- [ ] **Step 2: 静态分析**

Run: `flutter analyze`
Expected: 无 error。warning 需评估是否本次引入。

- [ ] **Step 3: 反馈相关测试**

Run:

```bash
flutter test \
  test/domain/entities/feedback_test.dart \
  test/data/feedback_dto_test.dart \
  test/data/mock_feedback_repository_test.dart \
  test/data/http_feedback_repository_test.dart \
  test/features/feedback/feedback_provider_test.dart \
  test/features/feedback/feedback_page_test.dart \
  test/docs/api_contract_test.dart \
  test/features/home/home_page_test.dart
```

Expected: 全 PASS。

- [ ] **Step 4: 受影响回归**

Run:

```bash
flutter test test/features/chat test/features/professor test/features/preparation
```

Expected: PASS。若 Drift 相关 hang(既有问题,非本次引入),记录跳过原因。

- [ ] **Step 5: 手动端到端**

Run: `flutter run`
走:抽屉"反馈" → 填写 → 提交(mock 模式见成功 SnackBar);导师详情页 AppBar 反馈 → 跳页带"导师 P001"摘要;推荐卡反馈 → 跳页带消息上下文;切换 http 模式(若已配 API_BASE_URL)验证真实提交路径。

- [ ] **Step 6: 提交(若有格式/小修)**

```bash
git add -A
git commit -m "chore(feedback): format + verification"
```

---

## Self-Review

**1. Spec coverage:**

- §4 架构分层 → Task 1–6 覆盖(实体/接口/mock/http/provider/DI)。
- §5 实体与契约 → Task 1(实体)、Task 2(DTO)、Task 5(http 实现)。
- §6 HTTP 契约(信封)→ Task 5 实现 + Task 7 文档。
- §7 Provider/页面/入口 → Task 6(provider)、Task 8(页面)、Task 9(路由+抽屉)、Task 10(内联)。
- §8 错误处理 → Task 5(失败映射)+ Task 8(SnackBar 文案)。
- §9 测试 → 每个 Task 内 TDD + Task 11 全量。
- §10 验证清单 → Task 11。

无遗漏。

**2. Placeholder scan:**

Task 3/4/5 中的 `Success<void>` / `ServerException('boom')` 写法标注了"以项目惯用法为准",并给出核对步骤(Step 2/4)——这是对项目未确认 API 的显式核对指令,非占位符。其余步骤均有完整代码。无 "TBD/TODO"。

**3. Type consistency:**

- `Feedback` 字段在 Task 1 定义,Task 2 DTO、Task 6 Notifier、Task 8 页面一致使用。
- `FeedbackType` 枚举值:Task 1 `{ recommendation, missingProfessor, bug, other }`,Task 2 字符串映射 `recommendation|missing_professor|bug|other`,Task 9 路由解析、Task 10 入口 query 一致。
- `FeedbackContext.fromQuery` 的 query key:`route/sid/mid/pid/cid/prompt/v/mode`——Task 1 定义,Task 9 路由用 `state.uri.queryParameters` 直接传入,Task 10 `FeedbackEntryButton` 产出相同 key。一致。
- `feedbackRepositoryProvider` / `feedbackSubmitProvider` 名称在 Task 6 定义,Task 8 页面、测试一致引用。
- `submit()` 签名:Task 6 Notifier 为 `submit({type, content, contact, context}) → Future<bool>`,Task 8 页面调用一致。

一致。

**4. 已知需执行时核对项(已在对应 Task 标注):**

- `Success<void>` / `Result<void>` 在项目的具体惯用法(Task 3/4/5/6)。
- `home_page_test.dart` 打开抽屉的现有写法(Task 9)。
- `ChatMessageBubble` 是否已有 `sessionId`(Task 10 Step 3)。
- 备赛助手对话所在 widget 文件(Task 10 Step 4)。
- `professor_page.dart` 中 `professorId` 变量名(Task 10 Step 2)。
