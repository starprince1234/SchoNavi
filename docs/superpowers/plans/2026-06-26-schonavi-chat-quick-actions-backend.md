# 对话快捷输入后端化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让对话页快捷操作 chip 在每轮助手回复后（含初始态、对话轮、推荐轮）都由后端生成，硬编码常量仅作网络失败兜底。

**Architecture:** 照搬已实现的 `/chat/route` 迁移模子——新增 `POST /api/v1/chat/quick-actions` 端点 + `HttpQuickActionsSource`/`LlmQuickActionsSource` 双实现 + 按 `DataSource` 切换的 `quickActionsSourceProvider`。`ChatNotifier` 在 `start()` 与对话轮 stream `onDone` 调用，复用 `_operation` token 防竞态。`Result<List<String>>` 区分失败（→ 硬编码兜底）与成功空（→ 不显示）。`ChatQuickActions` widget 的 `fallback` 参数中和为空，兜底所有权上移到 ChatNotifier。

**Tech Stack:** Flutter / Riverpod 3.2.1 / Dio / DeepSeek LLM / 现有 `guardApi` 信封 + `Result<T>` / `FakeBackendAdapter` 假后端 / `flutter_test`。

**Spec:** [docs/superpowers/specs/2026-06-26-schonavi-chat-quick-actions-backend-design.md](../specs/2026-06-26-schonavi-chat-quick-actions-backend-design.md)

## Global Constraints

- Riverpod 3.2.1 手写 provider，不代码生成。
- 数据层分层：domain 接口 → DTO → http/ai/mock 实现 → `core/di/providers.dart` 装配，按 `appConfigProvider.dataSource` 切换。
- API 信封统一 `{code, message, data}`，`code != 0` 由 `guardApi`/`decodeEnvelope` 抛 `ValidationException` → `Failure`。
- 接口契约「宁可少 chip，不阻断对话」：`Failure` → 兜底常量，`Success([])` → 不显示，绝不抛错打断对话流。
- 测试约定：每单元先写测试再写实现（TDD）；HTTP 层 `_FakeAdapter`、LLM 层 `_FakeLlm`、ChatNotifier 层假源 + `ProviderContainer` override，全部纯前端离线可测。
- 中文注释与文案；commit message 用 conventional commits（`feat:`/`test:`/`docs:`）。
- 关键已有签名：`guardApi<T>(Future<Response<dynamic>> Function() request, JsonDecoder<T> decode) → Future<Result<T>>`；`asJsonObject(Object?) → Map<String, dynamic>`；`RecommendationRecapDto.fromEntity(Recommendation r)`；`LlmClient.complete({required List<LlmMessage> messages, bool jsonMode, double temperature}) → Future<Result<String>>`；`_beginOperation() → int`（`++_operation` 并返回新值）；`_isCurrent(int token) → bool`。

---

## File Structure

**新建（8 个）：**

| 文件 | 职责 |
|---|---|
| `lib/shared/utils/quick_actions_source.dart` | 领域接口 `QuickActionsSource`，返回 `Result<List<String>>` |
| `lib/data/dto/quick_actions_dto.dart` | `QuickActionsRequestDto` / `QuickActionsResponseDto`，复用 `RecommendationRecapDto` |
| `lib/data/http/http_quick_actions_source.dart` | HTTP 实现，`POST /chat/quick-actions` |
| `lib/data/ai/llm_quick_actions_source.dart` | LLM 实现，`llm.complete(jsonMode:true)` |
| `lib/data/mock/fake_chat_quick_actions_backend.dart` | 假后端 handler `chatQuickActionsHandler` + 纯函数 `pickQuickActionsByContext` |
| `test/data/mock/fake_chat_quick_actions_backend_test.dart` | handler 纯函数单测 |
| `test/data/http/http_quick_actions_source_test.dart` | HTTP 实现单测 |
| `test/data/ai/llm_quick_actions_source_test.dart` | LLM 实现单测 |

**改动（8 个）：**

| 文件 | 改动 |
|---|---|
| `lib/core/di/providers.dart` | 新增 `quickActionsSourceProvider` |
| `lib/data/mock/fake_backend.dart` | `_defaultHandlers` 注册 `/chat/quick-actions` |
| `lib/features/chat/widgets/chat_quick_actions.dart` | `fallback` 参数默认值 → `const <String>[]` |
| `lib/features/chat/pages/chat_page.dart` | 删 `fallback: _quickActions` 入参与 `_quickActions` 常量 |
| `lib/features/home/pages/home_page.dart` | 删 `fallback: _quickActions` 入参与 `_quickActions` 常量 |
| `lib/features/chat/providers/chat_provider.dart` | 新增 `_refreshQuickActions`、`start()` 加 token、`_streamConversation.onDone` 调用、导入兜底常量 |
| `docs/api-contract.md` | 追加 `POST /chat/quick-actions` 契约 |
| `test/features/chat/chat_notifier_test.dart` | 扩展三调用点 + 竞态测试 |

**同步改动现有测试（widget 测试会因 chip 来源异步化而需要 override）：**

- `test/features/chat/chat_page_test.dart` — `ProviderScope.overrides` 加 `quickActionsSourceProvider`
- `test/features/home/home_page_conversation_test.dart` — 同上
- `test/features/chat/widgets/chat_quick_actions_test.dart` — 加 fallback 中和断言

**零改动（仅验证）：** `lib/data/ai/ai_recommendation_repository.dart`、`lib/data/mock/mock_db.dart`、`lib/features/chat/widgets/chat_quick_questions.dart`、`lib/data/dto/route_need_dto.dart`。

---

## Task 1: 领域接口 QuickActionsSource

**Files:**
- Create: `lib/shared/utils/quick_actions_source.dart`
- Test: 无独立测试（纯接口，由实现类测试覆盖）

**Interfaces:**
- Consumes: `lib/core/result/result.dart` 的 `Result<T>`；`lib/domain/entities/recommendation_result.dart` 的 `RecommendationResult`
- Produces: `abstract interface class QuickActionsSource`，方法 `Future<Result<List<String>>> fetch({required String followUp, RecommendationResult? lastResult})`

- [ ] **Step 1: 写接口**

Create `lib/shared/utils/quick_actions_source.dart`:

```dart
import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';

/// 快捷操作（输入框上方 chip）的后端来源。
///
/// 返回 [Result] 以区分「失败」与「成功但空」——失败由调用方降级到硬编码
/// 兜底常量，成功空则不显示 chip（对齐 spec 降级规则：宁可少 chip，
/// 不阻断对话）。语义对称 [RecommendationNeedClassifier]，但后者在实现
/// 内部塌缩为 bool，这里把「失败 vs 空」的区分交回调用方。
abstract interface class QuickActionsSource {
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  });
}
```

- [ ] **Step 2: 验证编译**

Run: `dart analyze lib/shared/utils/quick_actions_source.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/shared/utils/quick_actions_source.dart
git commit -m "feat(chat): QuickActionsSource 领域接口"
```

---

## Task 2: DTO（QuickActionsRequestDto / QuickActionsResponseDto）

**Files:**
- Create: `lib/data/dto/quick_actions_dto.dart`
- Test: `test/data/dto/quick_actions_dto_test.dart`（新建）

**Interfaces:**
- Consumes: `RecommendationRecapDto`（`lib/data/dto/route_need_dto.dart`，已存在，`fromEntity(Recommendation)` / `toJson()`）
- Produces: `QuickActionsRequestDto({required String followUp, List<RecommendationRecapDto>? lastRecommendations})` + `toJson()`；`QuickActionsResponseDto({required List<String> quickActions})` + `QuickActionsResponseDto.fromJson(Map<String, dynamic>)`

- [ ] **Step 1: 写失败测试**

Create `test/data/dto/quick_actions_dto_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/dto/quick_actions_dto.dart';
import 'package:scho_navi/data/dto/route_need_dto.dart';

void main() {
  group('QuickActionsRequestDto', () {
    test('followUp 写入 follow_up 字段', () {
      final json = const QuickActionsRequestDto(followUp: '换一批').toJson();
      expect(json['follow_up'], '换一批');
      expect(json.containsKey('last_recommendations'), isFalse);
    });

    test('lastRecommendations 非 null 时写入 last_recommendations', () {
      final json = QuickActionsRequestDto(
        followUp: '只看北京',
        lastRecommendations: [
          const RecommendationRecapDto(
            professorId: 'p_001',
            name: '张三',
            university: '清华大学',
            researchFields: ['计算机视觉'],
          ),
        ],
      ).toJson();
      expect(json['follow_up'], '只看北京');
      final recs = json['last_recommendations'] as List;
      expect(recs, hasLength(1));
      expect((recs.single as Map)['professor_id'], 'p_001');
      expect((recs.single as Map)['research_fields'], ['计算机视觉']);
    });
  });

  group('QuickActionsResponseDto.fromJson', () {
    test('解码 quick_actions 字符串列表', () {
      final dto = QuickActionsResponseDto.fromJson(const {
        'quick_actions': ['换一批', '偏应用'],
      });
      expect(dto.quickActions, ['换一批', '偏应用']);
    });

    test('quick_actions 缺省视为空列表', () {
      final dto = QuickActionsResponseDto.fromJson(const <String, dynamic>{});
      expect(dto.quickActions, isEmpty);
    });

    test('quick_actions 类型错误视为空列表', () {
      final dto = QuickActionsResponseDto.fromJson(const {
        'quick_actions': 'not-a-list',
      });
      expect(dto.quickActions, isEmpty);
    });

    test('过滤 null 与空字符串元素', () {
      final dto = QuickActionsResponseDto.fromJson(const {
        'quick_actions': ['换一批', null, '', '偏应用'],
      });
      expect(dto.quickActions, ['换一批', '偏应用']);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/dto/quick_actions_dto_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:scho_navi/data/dto/quick_actions_dto.dart'`

- [ ] **Step 3: 写实现**

Create `lib/data/dto/quick_actions_dto.dart`:

```dart
import 'route_need_dto.dart';

/// 请求体：`{"follow_up": "...", "last_recommendations": [...]}`。
///
/// `follow_up` 缺省/空字符串表示会话开始，后端按通用 chip 语义返回。
/// `last_recommendations` 首轮省略，后续轮由调用方 cap 到 5 条——
/// 复用 [RecommendationRecapDto]，与 `/chat/route` 同款摘要，避免端点间 DTO 重复。
class QuickActionsRequestDto {
  const QuickActionsRequestDto({
    required this.followUp,
    this.lastRecommendations,
  });

  final String followUp;
  final List<RecommendationRecapDto>? lastRecommendations;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'follow_up': followUp,
    if (lastRecommendations != null)
      'last_recommendations': [
        for (final r in lastRecommendations!) r.toJson(),
      ],
  };
}

/// 响应 data：`{"quick_actions": ["换一批","偏应用",...]}`。
///
/// `quick_actions` 缺省/类型错误 → 视为空 `[]`（由 [fromJson] 兜底），不报错——
/// 对齐「后端返回空则不显示」。
class QuickActionsResponseDto {
  const QuickActionsResponseDto({required this.quickActions});

  final List<String> quickActions;

  factory QuickActionsResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['quick_actions'];
    return QuickActionsResponseDto(
      quickActions: list is List
          ? list
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/data/dto/quick_actions_dto_test.dart`
Expected: PASS（全部 5 个 case）

- [ ] **Step 5: Commit**

```bash
git add lib/data/dto/quick_actions_dto.dart test/data/dto/quick_actions_dto_test.dart
git commit -m "feat(chat): QuickActionsRequestDto/ResponseDto"
```

---

## Task 3: 假后端 handler + pickQuickActionsByContext 纯函数

**Files:**
- Create: `lib/data/mock/fake_chat_quick_actions_backend.dart`
- Test: `test/data/mock/fake_chat_quick_actions_backend_test.dart`（新建）

**Interfaces:**
- Consumes: `dio` 的 `RequestOptions` / `ResponseBody`；`lib/data/dto/route_need_dto.dart` 的 `RecommendationRecapDto`（仅在测试构造里用）
- Produces: `Future<ResponseBody> chatQuickActionsHandler(RequestOptions options)`；`List<String> pickQuickActionsByContext(String followUp, List<Map<String, dynamic>> recaps)`

**说明：** `pickQuickActionsByContext` 暴露为顶层公开函数（非 `_` 私有），便于单测直接调；签名用 `List<Map<String, dynamic>> recaps` 而非裸 `List`，类型更安全。关键词分派规则见 spec §4。

- [ ] **Step 1: 写失败测试**

Create `test/data/mock/fake_chat_quick_actions_backend_test.dart`:

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/mock/fake_backend.dart';
import 'package:scho_navi/data/mock/fake_chat_quick_actions_backend.dart';

void main() {
  group('pickQuickActionsByContext', () {
    test('followUp 空 → 返回通用 4 个 chip', () {
      final actions = pickQuickActionsByContext('', const []);
      expect(actions, hasLength(4));
      expect(actions, containsAll(['换一批', '偏应用', '只看985', '适合硕士']));
    });

    test('含「换一批/再推荐」→ 返回换一批系', () {
      final actions = pickQuickActionsByContext('换一批导师', const []);
      expect(actions.first, '换一批');
      expect(actions, contains('相似导师'));
    });

    test('含「只看/北京」→ 返回筛选系', () {
      final actions = pickQuickActionsByContext('只看北京', const []);
      expect(actions, contains('只看北京'));
      expect(actions, contains('只看985'));
    });

    test('recaps 非空时优先返回方向相关 chip', () {
      final recaps = <Map<String, dynamic>>[
        const {
          'professor_id': 'p_001',
          'name': '张三',
          'university': '清华大学',
          'research_fields': ['计算机视觉', '医学影像'],
        },
      ];
      final actions = pickQuickActionsByContext('详情', recaps);
      expect(actions, contains('偏应用'));
      expect(actions, contains('偏理论'));
    });
  });

  group('chatQuickActionsHandler', () {
    test('返回信封 {code:0, message:ok, data:{quick_actions:[...]}}', () async {
      final body = await chatQuickActionsHandler(_post({'follow_up': '换一批'}));
      final json = await _decode(body);

      expect(json['code'], 0);
      expect(json['message'], 'ok');
      expect((json['data'] as Map)['quick_actions'], isA<List>());
    });

    test('follow_up 缺省视为空，返回通用 chip', () async {
      final body = await chatQuickActionsHandler(_post(<String, dynamic>{}));
      final json = await _decode(body);
      expect(((json['data'] as Map)['quick_actions'] as List), hasLength(4));
    });

    test('非 Map 请求体按空 followUp 处理', () async {
      final body = await chatQuickActionsHandler(_post('not-a-map'));
      final json = await _decode(body);
      expect(((json['data'] as Map)['quick_actions'] as List), hasLength(4));
    });
  });

  group('FakeBackendAdapter', () {
    test('把 POST /api/v1/chat/quick-actions 分派到 handler', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = FakeBackendAdapter();

      final res = await dio.post<dynamic>(
        '/api/v1/chat/quick-actions',
        data: {'follow_up': '换一批'},
      );
      expect(res.data['code'], 0);
      expect((res.data['data'] as Map)['quick_actions'], isA<List>());
    });
  });
}

RequestOptions _post(Object? data) {
  return RequestOptions(
    path: '/api/v1/chat/quick-actions',
    method: 'POST',
    data: data,
  );
}

Future<Map<String, dynamic>> _decode(ResponseBody body) async {
  final bytes = <int>[];
  await for (final chunk in body.stream) {
    bytes.addAll(chunk);
  }
  return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/mock/fake_chat_quick_actions_backend_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:scho_navi/data/mock/fake_chat_quick_actions_backend.dart'`

- [ ] **Step 3: 写实现**

Create `lib/data/mock/fake_chat_quick_actions_backend.dart`:

```dart
import 'dart:convert';

import 'package:dio/dio.dart';

/// 假后端对 `POST /api/v1/chat/quick-actions` 的处理：读请求体 `follow_up`
/// 与 `last_recommendations`，调纯函数 [pickQuickActionsByContext] 挑 chip，
/// 按 API 信封约定（`{code, message, data}`）返回。
///
/// - `follow_up` 缺省或空 → 通用 4 个 chip（会话开始语义）。
/// - `options.data` 非 Map 时视为空 `follow_up`，不崩。
///
/// 由 `FakeBackendAdapter` 注册，亦可被单测直接经 `RequestOptions` 调用，
/// 以精确断言请求体——同一函数两处消费，避免重复（对齐 `chatRouteHandler`）。
Future<ResponseBody> chatQuickActionsHandler(RequestOptions options) async {
  final data = options.data;
  final followUp = data is Map<String, dynamic>
      ? (data['follow_up']?.toString() ?? '')
      : '';
  final recaps = data is Map<String, dynamic>
      ? (data['last_recommendations'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final actions = pickQuickActionsByContext(followUp, recaps);
  return _jsonEnvelope(actions);
}

/// 纯函数：按上下文挑 1-4 个短操作 chip，便于独立单测。
///
/// 关键词驱动（保证 mock 模式下 chip 也会随会话变化、而非恒定硬编码）：
/// - `followUp` 空（首轮/会话开始）→ 通用 4 个。
/// - 含「换/再推荐/相似」→ 换一批系。
/// - 含「只看/地区名（北京/上海…）」→ 筛选系。
/// - 否则 → 通用 4 个兜底（含上一轮方向时仍可用）。
List<String> pickQuickActionsByContext(
  String followUp,
  List<Map<String, dynamic>> recaps,
) {
  final text = followUp.trim();

  if (text.isEmpty) {
    return const ['换一批', '偏应用', '只看985', '适合硕士'];
  }

  if (RegExp(r'换|再推荐|相似|类似的导师').hasMatch(text)) {
    return const ['换一批', '相似导师', '只看985', '偏应用'];
  }

  if (RegExp(r'只看|北京|上海|江浙|广州|深圳').hasMatch(text)) {
    // 若有上一轮推荐且含地区，提炼「只看<地区>」；否则通用筛选。
    final location = _firstLocation(recaps);
    return location == null
        ? const ['只看北京', '只看985', '换一批', '偏应用']
        : ['只看$location', '只看985', '换一批', '偏应用'];
  }

  // 默认：方向相关 + 通用。
  return const ['偏应用', '偏理论', '换一批', '适合硕士'];
}

String? _firstLocation(List<Map<String, dynamic>> recaps) {
  for (final r in recaps) {
    final uni = r['university']?.toString() ?? '';
    if (uni.contains('北京')) return '北京';
    if (uni.contains('上海')) return '上海';
  }
  return null;
}

ResponseBody _jsonEnvelope(List<String> actions) {
  return ResponseBody.fromString(
    jsonEncode({
      'code': 0,
      'message': 'ok',
      'data': {'quick_actions': actions},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/data/mock/fake_chat_quick_actions_backend_test.dart`
Expected: PASS（全部 7 个 case）

- [ ] **Step 5: 注册到 FakeBackendAdapter**

Modify `lib/data/mock/fake_backend.dart`。在文件顶部 import：

```dart
import 'fake_chat_quick_actions_backend.dart';
```

修改 `_defaultHandlers()`（[fake_backend.dart:47-52](lib/data/mock/fake_backend.dart#L47-L52)）：

```dart
  static Map<_RouteKey, Future<ResponseBody> Function(RequestOptions)>
      _defaultHandlers() {
    return {
      _RouteKey('POST', '/api/v1/chat/route'): chatRouteHandler,
      _RouteKey('POST', '/api/v1/chat/quick-actions'): chatQuickActionsHandler,
    };
  }
```

同时更新顶部文档注释「本次只注册 `/chat/route` 一个端点」→ 「已注册 `/chat/route` 与 `/chat/quick-actions`」。

- [ ] **Step 6: 跑全量假后端测试确认不破坏 /chat/route**

Run: `flutter test test/data/mock/`
Expected: PASS（含 `follow_up_routing_test.dart` 回归）

- [ ] **Step 7: Commit**

```bash
git add lib/data/mock/fake_chat_quick_actions_backend.dart \
        lib/data/mock/fake_backend.dart \
        test/data/mock/fake_chat_quick_actions_backend_test.dart
git commit -m "feat(chat): 假后端 /chat/quick-actions handler + 纯函数分派"
```

---

## Task 4: HTTP 实现 HttpQuickActionsSource

**Files:**
- Create: `lib/data/http/http_quick_actions_source.dart`
- Test: `test/data/http/http_quick_actions_source_test.dart`（新建）

**Interfaces:**
- Consumes: `QuickActionsSource`（Task 1）；`QuickActionsRequestDto`/`QuickActionsResponseDto`（Task 2）；`RecommendationRecapDto`（已有）；`guardApi`/`asJsonObject`（`lib/data/dto/api_envelope.dart`）
- Produces: `class HttpQuickActionsSource implements QuickActionsSource`，构造 `HttpQuickActionsSource(Dio)`，方法 `fetch({required String followUp, RecommendationResult? lastResult}) → Future<Result<List<String>>>`

- [ ] **Step 1: 写失败测试**

Create `test/data/http/http_quick_actions_source_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/http/http_quick_actions_source.dart';
import 'package:scho_navi/data/mock/fake_chat_quick_actions_backend.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';

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
  ) => handler(options);
}

Dio _dio(Future<ResponseBody> Function(RequestOptions options) handler) {
  return Dio(BaseOptions(baseUrl: 'https://api.example.com'))
    ..httpClientAdapter = _FakeAdapter(handler);
}

ResponseBody _jsonString(String text) => ResponseBody.fromString(
      text,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

RecommendationResult _resultWith(List<Recommendation> recs) {
  return RecommendationResult(
    sessionId: 's_1',
    queryUnderstanding: const QueryUnderstanding(
      researchInterests: ['计算机视觉'],
      preferredLocations: ['北京'],
      preferredUniversities: [],
      degreeStage: null,
      uncertainties: [],
    ),
    recommendations: recs,
    followUpQuestions: const [],
  );
}

const _rec = Recommendation(
  professorId: 'p_001',
  name: '张三',
  university: '清华大学',
  college: '计算机学院',
  title: '教授',
  researchFields: ['计算机视觉', '医学影像'],
  matchLevel: MatchLevel.high,
  reason: '方向契合',
  limitations: [],
);

void main() {
  group('HttpQuickActionsSource', () {
    test('posts to /chat/quick-actions with follow_up and last_recommendations recap',
        () async {
      RequestOptions? captured;
      final src = HttpQuickActionsSource(
        _dio((options) async {
          captured = options;
          return chatQuickActionsHandler(options);
        }),
      );

      final result = await src.fetch('换一批', lastResult: _resultWith([_rec]));

      expect(captured!.path, '/api/v1/chat/quick-actions');
      expect(captured!.method, 'POST');
      expect((captured!.data as Map)['follow_up'], '换一批');
      final recap = (captured!.data as Map)['last_recommendations'] as List;
      expect(recap, hasLength(1));
      expect((recap.single as Map)['professor_id'], 'p_001');
      expect((recap.single as Map)['research_fields'], ['计算机视觉', '医学影像']);
      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, isNotEmpty);
    });

    test('omits last_recommendations when lastResult is null', () async {
      RequestOptions? captured;
      final src = HttpQuickActionsSource(
        _dio((options) async {
          captured = options;
          return chatQuickActionsHandler(options);
        }),
      );

      await src.fetch('换一批', lastResult: null);

      expect(
        (captured!.data as Map).containsKey('last_recommendations'),
        isFalse,
      );
    });

    test('caps recap to 5 recommendations', () async {
      final recs = [
        for (var i = 0; i < 7; i++)
          Recommendation(
            professorId: 'p_$i',
            name: '导师$i',
            university: '大学$i',
            college: '学院',
            title: '教授',
            researchFields: ['计算机视觉'],
            matchLevel: MatchLevel.medium,
            reason: 'r',
            limitations: [],
          ),
      ];
      RequestOptions? captured;
      final src = HttpQuickActionsSource(
        _dio((options) async {
          captured = options;
          return chatQuickActionsHandler(options);
        }),
      );

      await src.fetch('换一批', lastResult: _resultWith(recs));

      expect(
        (captured!.data as Map)['last_recommendations'] as List,
        hasLength(5),
      );
    });

    test('decodes quick_actions list as Success', () async {
      final src = HttpQuickActionsSource(
        _dio((_) async => _jsonString(
              jsonEncode({
                'code': 0,
                'message': 'ok',
                'data': {'quick_actions': ['换一批', '偏应用']},
              }),
            )),
      );

      final result = await src.fetch('x', lastResult: null);

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, ['换一批', '偏应用']);
    });

    test('empty quick_actions decodes as Success with empty list', () async {
      final src = HttpQuickActionsSource(
        _dio((_) async => _jsonString(
              jsonEncode({
                'code': 0,
                'message': 'ok',
                'data': {'quick_actions': <String>[]},
              }),
            )),
      );

      final result = await src.fetch('x', lastResult: null);

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, isEmpty);
    });

    test('non-zero envelope returns Failure', () async {
      final src = HttpQuickActionsSource(
        _dio((_) async => _jsonString(
              jsonEncode({
                'code': 40001,
                'message': '输入内容不合法',
                'data': null,
              }),
            )),
      );

      final result = await src.fetch('x', lastResult: null);

      expect(result, isA<Failure<List<String>>>());
    });

    test('malformed success data returns Failure', () async {
      final src = HttpQuickActionsSource(
        _dio((_) async => _jsonString(
              jsonEncode({
                'code': 0,
                'message': 'ok',
                'data': {'bad': true},
              }),
            )),
      );

      // quick_actions 缺省 → ResponseDto 返回空，但 guardApi 仍 Success([])。
      // 此 case 验证 data 是 Map（含 bad 字段）时 quick_actions 视为空 → Success([])。
      final result = await src.fetch('x', lastResult: null);
      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, isEmpty);
    });

    test('DioException returns Failure', () async {
      final src = HttpQuickActionsSource(
        _dio((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }),
      );

      final result = await src.fetch('x', lastResult: null);

      expect(result, isA<Failure<List<String>>>());
      expect((result as Failure<List<String>>).error, isA<TimeoutException>());
    });

    test('never throws — self-degrades per interface contract', () async {
      final src = HttpQuickActionsSource(
        _dio((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }),
      );

      // 接口契约要求降级返回 Failure，不得抛错阻断对话。
      final result = await src.fetch('x', lastResult: null);
      expect(result, isA<Failure<List<String>>>());
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/http/http_quick_actions_source_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:scho_navi/data/http/http_quick_actions_source.dart'`

- [ ] **Step 3: 写实现**

Create `lib/data/http/http_quick_actions_source.dart`:

```dart
import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../shared/utils/quick_actions_source.dart';
import '../dto/api_envelope.dart';
import '../dto/quick_actions_dto.dart';
import '../dto/route_need_dto.dart';

/// 快捷操作的 HTTP 实现：`POST /api/v1/chat/quick-actions`。
///
/// 把请求交给后端，客户端不做关键词兜底。失败一律降级返回 [Failure]——
/// 由 [ChatNotifier] 决定是否填硬编码兜底常量（对齐 spec 降级规则）。
/// 请求体对称 `/chat/route`：`follow_up` + 可选 `last_recommendations` recap（cap 5）。
class HttpQuickActionsSource implements QuickActionsSource {
  HttpQuickActionsSource(this._dio);

  final Dio _dio;

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/chat/quick-actions',
        data: QuickActionsRequestDto(
          followUp: followUp,
          lastRecommendations: lastResult == null
              ? null
              : [
                  for (final r in lastResult.recommendations.take(5))
                    RecommendationRecapDto.fromEntity(r),
                ],
        ).toJson(),
      ),
      (data) =>
          QuickActionsResponseDto.fromJson(asJsonObject(data)).quickActions,
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/data/http/http_quick_actions_source_test.dart`
Expected: PASS（全部 9 个 case）

- [ ] **Step 5: Commit**

```bash
git add lib/data/http/http_quick_actions_source.dart \
        test/data/http/http_quick_actions_source_test.dart
git commit -m "feat(chat): HttpQuickActionsSource HTTP 实现"
```

---

## Task 5: LLM 实现 LlmQuickActionsSource

**Files:**
- Create: `lib/data/ai/llm_quick_actions_source.dart`
- Test: `test/data/ai/llm_quick_actions_source_test.dart`（新建）

**Interfaces:**
- Consumes: `QuickActionsSource`（Task 1）；`LlmClient` / `LlmMessage`（`lib/core/ai/llm_client.dart`）；`RecommendationResult`
- Produces: `class LlmQuickActionsSource implements QuickActionsSource`，构造 `LlmQuickActionsSource(LlmClient)`，方法 `fetch(...) → Future<Result<List<String>>>`

**说明：** 畸形输出降级为 `Success(<String>[])`（视为「后端成功但无建议」，不显示 chip，不触发硬编码兜底）；LLM 调用本身失败返回 `Failure`（触发兜底）。prompt 复用 [ai_recommendation_repository.dart:186](lib/data/ai/ai_recommendation_repository.dart#L186) 的短操作规则文案。

- [ ] **Step 1: 写失败测试**

Create `test/data/ai/llm_quick_actions_source_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/llm_quick_actions_source.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';

class _FakeLlm implements LlmClient {
  const _FakeLlm(this._result);
  final Result<String> _result;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async => _result;

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
}

class _RecordingLlm implements LlmClient {
  _RecordingLlm(this._delegate, this.calls);
  final LlmClient _delegate;
  final List<List<LlmMessage>> calls;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) {
    calls.add(messages);
    return _delegate.complete(
      messages: messages,
      jsonMode: jsonMode,
      temperature: temperature,
    );
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => _delegate.stream(messages: messages, temperature: temperature);
}

RecommendationResult _resultWith({List<Recommendation>? recs}) {
  return RecommendationResult(
    sessionId: 's_1',
    queryUnderstanding: const QueryUnderstanding(
      researchInterests: ['计算机视觉'],
      preferredLocations: ['北京'],
      preferredUniversities: [],
      degreeStage: null,
      uncertainties: [],
    ),
    recommendations: recs ?? const [],
    followUpQuestions: const [],
  );
}

const _rec = Recommendation(
  professorId: 'p_001',
  name: '张三',
  university: '清华大学',
  college: '计算机学院',
  title: '教授',
  researchFields: ['计算机视觉'],
  matchLevel: MatchLevel.high,
  reason: '方向契合',
  limitations: [],
);

void main() {
  group('LlmQuickActionsSource', () {
    test('解析 quick_actions 数组返回 Success', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Success('{"quick_actions":["换一批","偏应用"]}')),
      );
      final result = await src.fetch('换一批', lastResult: _resultWith());

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, ['换一批', '偏应用']);
    });

    test('畸形 JSON 降级为 Success 空列表（非 Failure）', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Success('{"intent":"other"}')),
      );
      final result = await src.fetch('x', lastResult: _resultWith());

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, isEmpty);
    });

    test('quick_actions 非 List 降级为 Success 空列表', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Success('{"quick_actions":"not-a-list"}')),
      );
      final result = await src.fetch('x', lastResult: _resultWith());

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, isEmpty);
    });

    test('LLM 失败返回 Failure（触发硬编码兜底）', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Failure(NetworkException())),
      );
      final result = await src.fetch('x', lastResult: _resultWith());

      expect(result, isA<Failure<List<String>>>());
      expect(
        (result as Failure<List<String>>).error,
        isA<NetworkException>(),
      );
    });

    test('无上一轮结果时仍可生成', () async {
      final src = LlmQuickActionsSource(
        const _FakeLlm(Success('{"quick_actions":["偏应用"]}')),
      );
      final result = await src.fetch('继续', lastResult: null);

      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).data, ['偏应用']);
    });

    test('prompt 含上一轮推荐摘要', () async {
      final calls = <List<LlmMessage>>[];
      final llm = _RecordingLlm(
        const _FakeLlm(Success('{"quick_actions":["偏应用"]}')),
        calls,
      );
      final src = LlmQuickActionsSource(llm);

      await src.fetch('第一位的研究方向', lastResult: _resultWith(recs: [_rec]));

      expect(calls, hasLength(1));
      final userContent = calls.single
          .where((m) => m.role == 'user')
          .map((m) => m.content)
          .join();
      expect(userContent, contains('张三'));
      expect(userContent, contains('计算机视觉'));
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/ai/llm_quick_actions_source_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:scho_navi/data/ai/llm_quick_actions_source.dart'`

- [ ] **Step 3: 写实现**

Create `lib/data/ai/llm_quick_actions_source.dart`:

```dart
import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../shared/utils/quick_actions_source.dart';

/// 快捷操作的 LLM 实现：让大模型基于追问文本 + 上一轮推荐摘要生成
/// 1-4 个短操作 chip。
///
/// 输出 `{"quick_actions":[...]}`。**畸形输出降级为 [Success] 空列表**——
/// 视为「后端成功但无建议」，不显示 chip、不触发硬编码兜底（对齐 spec：
/// 空则不显示）。**LLM 调用本身失败返回 [Failure]**，由 [ChatNotifier]
/// 填硬编码兜底常量。这是「大模型应用能力」评分维度的直接增量。
class LlmQuickActionsSource implements QuickActionsSource {
  LlmQuickActionsSource(this._llm);

  final LlmClient _llm;

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async {
    final res = await _llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(followUp, lastResult)),
      ],
      jsonMode: true,
      temperature: 0.8, // chip 略带多样性，避免每轮雷同
    );

    if (res is Failure<String>) return Failure(res.error);

    try {
      final decoded = jsonDecode((res as Success<String>).data);
      if (decoded is! Map<String, dynamic>) {
        return const Success(<String>[]);
      }
      final list = decoded['quick_actions'];
      if (list is! List) return const Success(<String>[]);
      final actions = list
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      return Success(actions);
    } catch (_) {
      return const Success(<String>[]); // 畸形输出降级为成功空
    }
  }

  static const String _systemPrompt = '''
你是 SchoNavi 对话式推荐的「快捷操作生成器」。基于用户追问与上一轮推荐，生成 1-4 个短操作 chip 供用户点击继续追问。
规则：
1. 只写操作短语，如「换一批」「只看北京」「偏应用」「适合博士」。
2. 每个不超过 8 个汉字。
3. 不要写完整问句，不要包含问号。
4. 不要以「你/是否/请问/能否/除了」等提问措辞开头。
5. 结合上一轮推荐的研究方向/地区调整，使其切题。
6. 候选不足时返回 2-3 个，最少 1 个；实在无建议返回空数组。
只输出一个 JSON 对象，不要 Markdown 或多余文字。
{"quick_actions":["换一批","偏应用"]}''';

  String _userPrompt(String followUp, RecommendationResult? lastResult) {
    final recap = lastResult == null
        ? '（本轮尚无推荐结果）'
        : '【上一轮已推荐】\n${_summarize(lastResult)}';
    return '【用户追问】$followUp\n$recap';
  }

  String _summarize(RecommendationResult result) {
    final recs = result.recommendations;
    if (recs.isEmpty) return '（上一轮未匹配到导师）';
    final lines = <String>[];
    for (final r in recs.take(5)) {
      lines.add(
        '- ${r.name}（${r.university} ${r.college}，'
        '方向：${r.researchFields.join('、')}，'
        '匹配：${r.matchLevel.name}）：${r.reason}',
      );
    }
    return lines.join('\n');
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/data/ai/llm_quick_actions_source_test.dart`
Expected: PASS（全部 6 个 case）

- [ ] **Step 5: Commit**

```bash
git add lib/data/ai/llm_quick_actions_source.dart \
        test/data/ai/llm_quick_actions_source_test.dart
git commit -m "feat(chat): LlmQuickActionsSource LLM 实现"
```

---

## Task 6: quickActionsSourceProvider 装配

**Files:**
- Modify: `lib/core/di/providers.dart`（在 `recommendationNeedClassifierProvider` 后追加）

**Interfaces:**
- Consumes: `QuickActionsSource`（Task 1）、`HttpQuickActionsSource`（Task 4）、`LlmQuickActionsSource`（Task 5）、`appConfigProvider`、`dioProvider`、`llmClientProvider`
- Produces: `final quickActionsSourceProvider = Provider<QuickActionsSource>(...)`

- [ ] **Step 1: 加 import 与 provider**

Modify `lib/core/di/providers.dart`。在文件顶部 import 区追加（按字母序插入）：

```dart
import '../../data/ai/llm_quick_actions_source.dart';
```

```dart
import '../../data/http/http_quick_actions_source.dart';
```

```dart
import '../../shared/utils/quick_actions_source.dart';
```

在 `recommendationNeedClassifierProvider` 定义之后（[providers.dart:114-124](lib/core/di/providers.dart#L114-L124) 之后）追加：

```dart
/// 快捷操作 chip 的后端来源。失败返回 [Failure]（由 ChatNotifier 填硬编码
/// 兜底常量），成功空返回 [Success] 空列表（不显示 chip）。见 spec §5。
final quickActionsSourceProvider = Provider<QuickActionsSource>((ref) {
  return switch (ref.watch(appConfigProvider).dataSource) {
    DataSource.llm => LlmQuickActionsSource(ref.watch(llmClientProvider)),
    DataSource.http => HttpQuickActionsSource(ref.watch(dioProvider)),
  };
});
```

- [ ] **Step 2: 验证编译**

Run: `dart analyze lib/core/di/providers.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/core/di/providers.dart
git commit -m "feat(chat): quickActionsSourceProvider 装配"
```

---

## Task 7: ChatQuickActions widget fallback 中和

**Files:**
- Modify: `lib/features/chat/widgets/chat_quick_actions.dart`
- Test: `test/features/chat/widgets/chat_quick_actions_test.dart`（扩展）

**Interfaces:**
- Consumes: 无新依赖
- Produces: `ChatQuickActions` 构造参数 `fallback` 默认值从 `defaultChatQuickActions` 改为 `const <String>[]`

**说明：** `normalizeChatQuickActions(actions, fallback)` 在 `actions` 归一化为空时回退到 `fallback`（[chat_quick_actions.dart:22-31](lib/features/chat/widgets/chat_quick_actions.dart#L22-L31)）。中和后 `Success([])` 能真正隐藏，兜底所有权上移到 ChatNotifier。`defaultChatQuickActions` 常量保留（Task 9 由 ChatNotifier 导入使用）。

- [ ] **Step 1: 扩展 widget 测试**

Modify `test/features/chat/widgets/chat_quick_actions_test.dart`。在文件末尾 `main` 闭合 `}` 之前追加：

```dart
  testWidgets('actions 为空且不传 fallback 时隐藏 chip（不渲染兜底常量）',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: ChatQuickActions(
            actions: const [],
            enabled: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    // fallback 默认中和为空 → 空 actions → SizedBox.shrink，不渲染任何 chip。
    expect(find.byType(BentoTile), findsNothing);
    expect(find.text('换一批'), findsNothing);
    expect(find.text('适合硕士'), findsNothing);
  });

  testWidgets('显式传 fallback=defaultChatQuickActions 时仍显示兜底', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SingleChildScrollView(
          child: ChatQuickActions(
            actions: const [],
            fallback: defaultChatQuickActions,
            enabled: true,
            onTap: (_) {},
          ),
        ),
      ),
    );

    // fallback 参数本身行为不变，调用方显式传入时仍兜底。
    expect(find.text('换一批'), findsOneWidget);
  });
```

- [ ] **Step 2: 跑测试确认新 case 失败（旧默认值会渲染兜底）**

Run: `flutter test test/features/chat/widgets/chat_quick_actions_test.dart`
Expected: FAIL — 第一个新 case 断言 `find.byType(BentoTile)` 为 `findsNothing` 失败（因旧默认 fallback 非空，空 actions 会渲染兜底常量）

- [ ] **Step 3: 中和 fallback 默认值**

Modify `lib/features/chat/widgets/chat_quick_actions.dart`。把构造参数默认值（[chat_quick_actions.dart:65](lib/features/chat/widgets/chat_quick_actions.dart#L65)）：

```dart
    this.fallback = defaultChatQuickActions,
```

改为：

```dart
    this.fallback = const <String>[],
```

`normalizeChatQuickActions` 顶层函数的 `fallback` 命名参数默认值（[chat_quick_actions.dart:11](lib/features/chat/widgets/chat_quick_actions.dart#L11)）同步改为 `const <String>[]`：

```dart
List<String> normalizeChatQuickActions(
  List<String> actions, {
  List<String> fallback = const <String>[],
}) {
```

**不要删** `defaultChatQuickActions` 常量（Task 9 由 ChatNotifier 导入）。

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/chat/widgets/chat_quick_actions_test.dart`
Expected: PASS（3 个 case：原有纤细高度 + 2 个新 case）

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/widgets/chat_quick_actions.dart \
        test/features/chat/widgets/chat_quick_actions_test.dart
git commit -m "feat(chat): ChatQuickActions fallback 中和为空，兜底上移 ChatNotifier"
```

---

## Task 8: ChatNotifier 集成 _refreshQuickActions + 三调用点

**Files:**
- Modify: `lib/features/chat/providers/chat_provider.dart`
- Test: `test/features/chat/chat_notifier_test.dart`（扩展）

**Interfaces:**
- Consumes: `quickActionsSourceProvider`（Task 6）、`defaultChatQuickActions`（[chat_quick_actions.dart:7](lib/features/chat/widgets/chat_quick_actions.dart#L7)）、`Result`/`Success`/`Failure`、`_beginOperation`/`_isCurrent`/`_lastRecommendationResult`（已有）
- Produces: `ChatNotifier._refreshQuickActions({required String followUp, required int token})`；`start()` 加 token；`_streamConversation.onDone` 调用

**说明：** 这是 spec 的核心集成，也是最易踩竞态处。先写测试再改实现。`_container()` helper 需加 `quickActionsSourceProvider` override。

- [ ] **Step 1: 扩展 chat_notifier_test.dart 的测试基建**

Modify `test/features/chat/chat_notifier_test.dart`。在文件顶部 import 区追加：

```dart
import 'package:scho_navi/features/chat/widgets/chat_quick_actions.dart';
import 'package:scho_navi/shared/utils/quick_actions_source.dart';
```

在 `_StreamChatRepo` 类定义之后、`_container` 之前，新增可编程假源：

```dart
class _ScriptedQuickActionsSource implements QuickActionsSource {
  _ScriptedQuickActionsSource();

  final List<Completer<Result<List<String>>>> _pending = [];
  Result<List<String>>? _immediate;

  /// 设置下一次 fetch 立即返回的结果（同步完成）。
  void setNext(Result<List<String>> result) => _immediate = result;

  /// 设置下一次 fetch 挂起，返回 Completer 让测试控制何时完成（竞态测试用）。
  Completer<Result<List<String>>> parkNext() {
    final c = Completer<Result<List<String>>>();
    _pending.add(c);
    return c;
  }

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async {
    if (_pending.isNotEmpty) return _pending.removeAt(0).future;
    return _immediate ?? const Success(<String>[]);
  }
}
```

修改 `_container()` helper（[chat_notifier_test.dart:44-50](test/features/chat/chat_notifier_test.dart#L44-L50)）让它接收假源并 override：

```dart
ProviderContainer _container(
  _StreamChatRepo repo, {
  _ScriptedQuickActionsSource? quickActions,
}) {
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      if (quickActions != null)
        quickActionsSourceProvider.overrideWithValue(quickActions),
    ],
  );
  container.listen(_chatTestProvider, (_, _) {});
  return container;
}
```

- [ ] **Step 2: 写失败测试**

在 `chat_notifier_test.dart` 的 `main` 内追加（放在现有测试之后）：

```dart
  group('quick actions 后端化', () {
    test('start 后 followUpQuestions 来自后端 Success', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource()..setNext(
        const Success(['换一批', '偏应用']),
      );
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump();

      expect(
        container.read(_chatTestProvider).followUpQuestions,
        ['换一批', '偏应用'],
      );
    });

    test('后端 Failure → fallback 到 defaultChatQuickActions', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource()
        ..setNext(const Failure(NetworkException()));
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump();

      expect(
        container.read(_chatTestProvider).followUpQuestions,
        defaultChatQuickActions,
      );
    });

    test('后端 Success 空列表 → followUpQuestions 为空（不显示）', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource()
        ..setNext(const Success(<String>[]));
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump();

      expect(
        container.read(_chatTestProvider).followUpQuestions,
        isEmpty,
      );
    });

    test('对话轮 stream onDone 后刷新 chip', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource()
        ..setNext(const Success(<String>[])); // 初始 fetch 消费
      // 第二次 fetch（对话轮 onDone）返回新 chip
      // 用 parkNext 让初始 fetch 先完成，再设 immediate 给对话轮
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump(); // 初始 fetch 完成（Success 空）

      src.setNext(const Success(['再推荐', '换一批'])); // 对话轮要返回的
      await container.read(_chatTestProvider.notifier).send('继续');
      await container.pump();

      expect(
        container.read(_chatTestProvider).followUpQuestions,
        ['再推荐', '换一批'],
      );
    });

    test('过期 fetch 不覆盖新 state（token 竞态）', () async {
      final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
      final src = _ScriptedQuickActionsSource();
      final container = _container(repo, quickActions: src);
      addTearDown(container.dispose);

      // 初始 fetch 挂起
      final initialGate = src.parkNext();
      container.read(_chatTestProvider.notifier).start(sessionId: 's1');
      await container.pump();

      // 对话轮的 fetch 立即返回新值
      src.setNext(const Success(['新值']));
      await container.read(_chatTestProvider.notifier).send('继续');
      await container.pump();
      expect(
        container.read(_chatTestProvider).followUpQuestions,
        ['新值'],
      );

      // 初始 fetch 慢回来，旧值不应覆盖
      initialGate.complete(const Success(['旧值']));
      await container.pump();
      expect(
        container.read(_chatTestProvider).followUpQuestions,
        ['新值'],
        reason: '过期 fetch 的旧值不应覆盖新 state',
      );
    });
  });
```

- [ ] **Step 3: 跑测试确认失败**

Run: `flutter test test/features/chat/chat_notifier_test.dart`
Expected: FAIL — `start()` 当前不调 `quickActionsSourceProvider`，`followUpQuestions` 保持空列表，多数 case 断言不通过

- [ ] **Step 4: 改 ChatNotifier 实现**

Modify `lib/features/chat/providers/chat_provider.dart`。

顶部 import 区追加：

```dart
import '../../../data/ai/llm_recommendation_need_classifier.dart';
```
（仅在已存在该 import 时跳过——本任务实际只需：）

```dart
import '../../chat/widgets/chat_quick_actions.dart' show defaultChatQuickActions;
```

```dart
import '../../../core/di/providers.dart' show quickActionsSourceProvider;
```

```dart
import '../../../core/result/result.dart';
```

（注意：`providers.dart` 与 `result.dart` 等可能已被 import；先读文件顶部确认，只追加缺失的。`show defaultChatQuickActions` 限定只导入常量，避免命名污染。`chat_quick_actions.dart` 与 `chat_provider.dart` 同在 `features/chat/`，用相对路径 `../../chat/widgets/chat_quick_actions.dart`——实际就是 `../widgets/chat_quick_actions.dart`，按文件实际位置写。）

修改 `start()`（[chat_provider.dart:85-104](lib/features/chat/providers/chat_provider.dart#L85-L104)）。把方法体开头的「重置 + `_operation++`」改为引入 token：

```dart
  void start({required String sessionId, String? professorId}) {
    if (state.sessionId == sessionId && state.professorId == professorId) {
      return;
    }
    final token = _beginOperation();           // ← 新增：让初始 fetch 纳入操作计数
    final sub = _sub;
    _sub = null;
    _activeAssistantId = null;
    if (sub != null) unawaited(sub.cancel());
    _completeTurn();

    _seq = 0;
    state = ChatState(
      sessionId: sessionId,
      professorId: professorId,
      messages: const [],
      activity: ChatActivity.idle,
      followUpQuestions: const [],
    );
    unawaited(_refreshQuickActions(followUp: '', token: token));
  }
```

新增私有方法（放在 `_requestRecommendations` 之前或 `_lastRecommendationResult` 之前，按现有代码组织习惯）：

```dart
  /// 向后端拉取快捷操作 chip 并写入 state。失败降级到 [defaultChatQuickActions]，
  /// 成功空不显示，成功非空直接写入（widget 显示时仍归一化过滤问句/cap 4/去重）。
  /// 过期 token 的回调直接丢弃，防止旧轮覆盖新 state。
  Future<void> _refreshQuickActions({
    required String followUp,
    required int token,
  }) async {
    final result = await ref.read(quickActionsSourceProvider).fetch(
      followUp: followUp,
      lastResult: _lastRecommendationResult(),
    );
    if (!_isCurrent(token)) return; // 过期请求丢弃
    final actions = result is Success<List<String>> && result.data.isNotEmpty
        ? result.data
        : (result is Failure<List<String>>
            ? defaultChatQuickActions
            : const <String>[]);
    state = state.copyWith(followUpQuestions: actions);
  }
```

修改 `_streamConversation` 的 `onDone` 回调（[chat_provider.dart:360-370](lib/features/chat/providers/chat_provider.dart#L360-L370)）。把：

```dart
            onDone: () {
              if (_isCurrent(token)) {
                _setAssistant(
                  assistantId,
                  buffer.toString(),
                  ChatMessageStatus.done,
                );
                state = state.copyWith(activity: ChatActivity.idle);
              }
              _clearActiveTurn(turn: turn, assistantId: assistantId);
            },
```

改为（在 `activity: idle` 后追加 chip 刷新）：

```dart
            onDone: () {
              if (_isCurrent(token)) {
                _setAssistant(
                  assistantId,
                  buffer.toString(),
                  ChatMessageStatus.done,
                );
                state = state.copyWith(activity: ChatActivity.idle);
                unawaited(_refreshQuickActions(followUp: content, token: token));
              }
              _clearActiveTurn(turn: turn, assistantId: assistantId);
            },
```

`onError` 分支不改动（保留上一轮 chip，不刷新）。

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/features/chat/chat_notifier_test.dart`
Expected: PASS（原有测试 + 新增 5 个 case）

**注意：** 现有 `chat_notifier_test.dart` 里不传 `quickActions` 的 `_container(repo)` 调用，`quickActionsSourceProvider` 未被 override → 会解析到真实 `LlmQuickActionsSource(MissingLlmClient)`（因 `appConfig` 默认 `DataSource.llm` 且无 apiKey）。`MissingLlmClient.complete` 返回 `Failure` → `_refreshQuickActions` 降级到 `defaultChatQuickActions`。现有测试若不断言 `followUpQuestions` 为空，应不受影响；若有断言为空的测试失败，需把该测试的 `_container(repo)` 改成 `_container(repo, quickActions: _ScriptedQuickActionsSource()..setNext(const Success(<String>[])))`。跑完测试逐个核对。

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/providers/chat_provider.dart \
        test/features/chat/chat_notifier_test.dart
git commit -m "feat(chat): ChatNotifier 三调用点刷新 chip + token 竞态防护"
```

---

## Task 9: chat_page / home_page 删除本地 _quickActions 常量

**Files:**
- Modify: `lib/features/chat/pages/chat_page.dart`
- Modify: `lib/features/home/pages/home_page.dart`

**Interfaces:**
- Consumes: 无（widget `fallback` 默认已中和，Task 7）
- Produces: 删除两处 `static const _quickActions` / `const _quickActions` 与 `fallback: _quickActions` 入参

**说明：** widget 的 `fallback` 参数在 Task 7 已中和为空默认值，调用处不再需要传 `fallback: _quickActions`。本地常量也删除，避免与 `defaultChatQuickActions` 重复。

- [ ] **Step 1: chat_page.dart 删除常量与入参**

Modify `lib/features/chat/pages/chat_page.dart`：

1. 删除 [chat_page.dart:41](lib/features/chat/pages/chat_page.dart#L41) 的 `static const List<String> _quickActions = ['解释理由', '换一批', '只看北京', '适合硕士'];`
2. 删除 [chat_page.dart:199](lib/features/chat/pages/chat_page.dart#L199) 的 `fallback: _quickActions,` 这一行（保留 `ChatQuickActions(actions:..., enabled:..., onTap:...)` 其余入参）。

- [ ] **Step 2: home_page.dart 删除常量与入参**

Modify `lib/features/home/pages/home_page.dart`：

1. 删除 [home_page.dart:686](lib/features/home/pages/home_page.dart#L686) 的 `const List<String> _quickActions = ['解释理由', '换一批', '只看北京', '适合硕士'];`（含上一行注释 `/// 对话态快捷操作回退（与 ChatPage 默认操作一致）。`）
2. 删除 [home_page.dart:535](lib/features/home/pages/home_page.dart#L535) 的 `fallback: _quickActions,` 这一行。

- [ ] **Step 3: 验证编译**

Run: `dart analyze lib/features/chat/pages/chat_page.dart lib/features/home/pages/home_page.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/chat/pages/chat_page.dart lib/features/home/pages/home_page.dart
git commit -m "refactor(chat): 删除 chat_page/home_page 本地 _quickActions 常量"
```

---

## Task 10: 同步现有 widget 测试 override + 全量回归

**Files:**
- Modify: `test/features/chat/chat_page_test.dart`
- Modify: `test/features/home/home_page_conversation_test.dart`
- Modify（如需要）: `test/features/home/home_page_test.dart`

**说明：** `chat_page`/`home_page_conversation` 测试用 `DataSource.llm + apiKey:'test-key'`，改动后 `start()` 异步调 `quickActionsSourceProvider` → `DeepSeekLlmClient` → 真实网络 `Failure`。必须在 `ProviderScope.overrides` 加假源，让 chip 来源确定且离线。假源返回 `Failure`（→ `defaultChatQuickActions`，与旧 `_quickActions` 内容一致），现有 `find.text('换一批')`/`'适合硕士')` 断言不变。

- [ ] **Step 1: chat_page_test.dart 加 override**

Modify `test/features/chat/chat_page_test.dart`。顶部 import 追加：

```dart
import 'package:scho_navi/shared/utils/quick_actions_source.dart';
```

新增一个总是返回 `Failure` 的假源（放在 `_FakeNeedClassifier` 类附近）：

```dart
class _FailingQuickActionsSource implements QuickActionsSource {
  const _FailingQuickActionsSource();

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async => const Failure(NetworkException());
}
```

在两个 `_wrap` 辅助函数的 `ProviderScope.overrides` 列表里（[chat_page_test.dart:73-82](test/features/chat/chat_page_test.dart#L73-L82) 与含 `recommendationRepositoryProvider` 的那个 [chat_page_test.dart:302-317](test/features/chat/chat_page_test.dart#L302-L317)）追加：

```dart
      quickActionsSourceProvider.overrideWithValue(
        const _FailingQuickActionsSource(),
      ),
```

**注意：** `chat_page_test.dart` 顶部还有一处 `ProviderScope`（[chat_page_test.dart:354-359](test/features/chat/chat_page_test.dart#L354-L359) `AppConfig()` 默认 `llm` 未配 apiKey → `MissingLlmClient` 本就 `Failure`，且无 `chatRepositoryProvider` override，跑的是另一条路径）。逐个 `ProviderScope` 核对：凡是有 `ChatPage` 挂载且会触发 `start()` 的，都要加 override。共两处（`_wrap` 函数内 + 第 302 行那个）。第 354 行那个是 `initialPrompt` 路径且 override 不同，单独核对。

- [ ] **Step 2: home_page_conversation_test.dart 加 override**

Modify `test/features/home/home_page_conversation_test.dart`。同样 import + 新增 `_FailingQuickActionsSource`（或提取到共享 test helper——本任务为简单起见内联重复）。在其 `ProviderScope.overrides`（含 `recommendationRepositoryProvider` 那处）追加 `quickActionsSourceProvider.overrideWithValue(const _FailingQuickActionsSource())`。

- [ ] **Step 3: home_page_test.dart 核对**

Run 先跑：
```bash
flutter test test/features/home/home_page_test.dart
```
若 PASS（未断言 chip、或未触发 `start()`）则不动；若 FAIL，按同样方式加 override。

- [ ] **Step 4: 跑受影响 widget 测试**

Run:
```bash
flutter test test/features/chat/chat_page_test.dart \
             test/features/home/home_page_conversation_test.dart \
             test/features/home/home_page_test.dart
```
Expected: PASS

**断言调整核对：** 若某测试断言 `find.text('解释理由')`（旧 `_quickActions` 含「解释理由」，但 `defaultChatQuickActions` 也含「解释理由」，内容一致）→ 不变。`Failure` 降级到 `defaultChatQuickActions = ['解释理由','换一批','只看北京','适合硕士']`，与旧 `_quickActions` 完全相同，所以 `find.text` 断言零改动。

- [ ] **Step 5: 跑全量回归**

Run: `flutter test`
Expected: 全绿。重点确认：`chat_notifier_test`、`chat_page_test`、`home_page_conversation_test`、`home_page_test`、`chat_bootstrap_test`、`chat_entry_points_test`、三个新单测文件。

- [ ] **Step 6: Commit**

```bash
git add test/features/chat/chat_page_test.dart \
        test/features/home/home_page_conversation_test.dart \
        test/features/home/home_page_test.dart
git commit -m "test(chat): widget 测试 override quickActionsSourceProvider 避免真实网络"
```

---

## Task 11: api-contract.md 追加端点契约文档

**Files:**
- Modify: `docs/api-contract.md`（在 `/chat/route` 一节之后追加）

**说明：** 文档同步。紧跟现有 `/chat/route` 章节格式。

- [ ] **Step 1: 读现有 /chat/route 章节**

Run: 读 `docs/api-contract.md` 中 `### POST /chat/route` 一节（约 [api-contract.md:264-294](docs/api-contract.md#L264-L294)），了解信封与 recap 写法。

- [ ] **Step 2: 追加 /chat/quick-actions 章节**

在 `/chat/route` 章节之后追加：

```markdown
### POST `/chat/quick-actions`

Generate short quick-action chip labels for the input bar above the composer. Called on conversation start and after each conversational turn's stream completes (recommendation turns already carry `follow_up_questions` in their result).

Request:

```json
{
  "follow_up": "只看上海的导师",
  "last_recommendations": [
    {
      "professor_id": "p_001",
      "name": "张三",
      "university": "清华大学",
      "research_fields": ["计算机视觉", "医学影像"]
    }
  ]
}
```

`follow_up` is required (empty string on conversation start). `last_recommendations` is optional; omit on the first turn (no prior recommendation). The recap carries only routing-relevant fields — see `RecommendationRecap` (same shape as `/chat/route`), capped to 5 entries by the client.

Response data:

```json
{
  "quick_actions": ["换一批", "偏应用", "只看985", "适合博士"]
}
```

`quick_actions` should be 1-4 short action labels (≤8 CJK chars each), operation phrases only — no full questions, no question marks, no interrogative prefixes like "你/是否/请问". On empty/missing `quick_actions`, the client hides the chips for that turn. On transport failure, the client falls back to a hardcoded default set.
```

- [ ] **Step 3: Commit**

```bash
git add docs/api-contract.md
git commit -m "docs(api): POST /chat/quick-actions 端点契约"
```

---

## Task 12: 最终全量验证

**Files:** 无（纯验证）

- [ ] **Step 1: 全量 analyze**

Run: `dart analyze lib/ test/`
Expected: `No issues found!`

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: 全绿。核对测试总数较基线增长（新增 DTO 5 + 假后端 7 + HTTP 9 + LLM 6 + notifier 5 + widget 2 = 34 个新 case）。

- [ ] **Step 3: 确认未触碰零改动文件**

Run:
```bash
git diff main -- lib/data/ai/ai_recommendation_repository.dart \
                 lib/data/mock/mock_db.dart \
                 lib/features/chat/widgets/chat_quick_questions.dart \
                 lib/data/dto/route_need_dto.dart
```
Expected: 空输出（这些文件零改动）。

- [ ] **Step 4: 终态自检**

人工核对：
- `defaultChatQuickActions` 常量仍在 [chat_quick_actions.dart:7](lib/features/chat/widgets/chat_quick_actions.dart#L7)
- widget `fallback` 默认值为 `const <String>[]`
- chat_page / home_page 不再有 `_quickActions` 常量
- `quickActionsSourceProvider` 在 `lib/core/di/providers.dart`
- `FakeBackendAdapter._defaultHandlers` 含 `/chat/quick-actions`
- `docs/api-contract.md` 含新端点

无需 commit（本任务无文件改动）。

---

## Self-Review

**1. Spec 覆盖核对：**

| Spec 要求 | 对应 Task |
|---|---|
| §1 领域接口 `QuickActionsSource` 返回 `Result<List<String>>` | Task 1 |
| §2 DTO（请求/响应，复用 `RecommendationRecapDto`） | Task 2 |
| §3 端点契约 `POST /chat/quick-actions` | Task 11（文档）+ Task 3/4（实现） |
| §4 HTTP 实现 | Task 4 |
| §4 LLM 实现（畸形降级 Success 空、LLM 失败 Failure） | Task 5 |
| §4 假后端 handler + 纯函数 | Task 3 |
| §5 Provider 按 DataSource 切换 | Task 6 |
| §6 ChatNotifier `_refreshQuickActions` + 三调用点 + token 防护 | Task 8 |
| §6 `start()` 引入 token | Task 8 |
| §6 `onError` 不刷新 chip | Task 8（不改 onError，自然保留） |
| §7 widget `fallback` 中和 | Task 7 |
| §7 chat_page/home_page 删本地常量 | Task 9 |
| §测试 ① 假后端纯函数 | Task 3 |
| §测试 ② HTTP | Task 4 |
| §测试 ③ LLM | Task 5 |
| §测试 ④ ChatNotifier 三调用点 + 竞态 | Task 8 |
| §测试 ⑤ widget fallback 中和 | Task 7 |
| §测试 widget 测试 override 避免真实网络 | Task 10 |
| §影响范围 零改动文件 | Task 12 Step 3 验证 |

无遗漏。

**2. 占位符扫描：** 全文无 TBD/TODO；每个 code step 含完整代码；测试含完整断言。Task 8 Step 4 的 import 说明已注明「先读文件顶部确认，只追加缺失的」——这是对现有文件的谨慎，非占位。

**3. 类型一致性核对：**
- `QuickActionsSource.fetch` 签名在 Task 1/4/5/8/10 全部一致：`Future<Result<List<String>>> fetch({required String followUp, RecommendationResult? lastResult})`
- `pickQuickActionsByContext(String, List<Map<String, dynamic>>)` 在 Task 3 定义与测试一致
- `_ScriptedQuickActionsSource`（Task 8）与 `_FailingQuickActionsSource`（Task 10）都 `implements QuickActionsSource`，签名匹配
- `defaultChatQuickActions` 在 Task 7 保留、Task 8 import 使用、Task 10 测试断言一致
- token：`_beginOperation()` 返回 int，`_refreshQuickActions` 的 `required int token` 与 `_isCurrent(int)` 一致

无类型不一致。
