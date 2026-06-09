# SchoNavi M2 · 真·流式对话（SSE 逐字 + 中断）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把对话回答从「整段返回」升级为 **SSE 逐字流式输出**并支持**中途停止生成**，复用 M1 的接地与多轮上下文，让体验像真 AI 产品。

**Architecture:** 给 `LlmClient` / `ChatRepository` 各加一个流式方法（`stream` / `streamReply`，返回 `Stream<String>` 纯文本增量）。`DeepSeekLlmClient.stream` 用 dio `ResponseType.stream` + `stream:true`，逐行解析 SSE `data:` 取 `delta.content`。`AiChatRepository.streamReply` 组 `[system(接地), ...history, user]` 调流，累加器在**完成或被取消**时把整段并入历史、**出错则丢弃半句**。`MockChatRepository.streamReply` 把现有意图回答切片定时 emit（离线流式观感）。presentation 的 `ChatNotifier` 改为订阅流：delta 累加进 `streaming` 助手气泡，新增 `stop()` 取消订阅并收尾。DI 零改动。

**Tech Stack:** Flutter 3.44 / Dart 3.12；`flutter_riverpod ^3.3.1`（手写 provider）；`go_router ^17`；`dio ^5.9`（`ResponseType.stream`）；`gpt_markdown ^1.1.7`。流式仅用 `dart:async` / `dart:convert` 内置能力，无新依赖。

**Spec 依据:** `docs/superpowers/specs/2026-06-09-schonavi-m2-streaming-design.md`，引用主设计 §5/§6.4 与 M1 设计。

**前置条件（已核实落地）:** M1 已实现——`lib/core/ai/{llm_client,deepseek_llm_client}.dart`、`lib/data/ai/{ai_chat_repository,ai_recommendation_repository,professor_candidate_source}.dart` 均存在；`ChatRepository.sendMessage`、`LlmClient.complete` 工作正常；`dataSource=mock|ai` 已在 `core/di/providers.dart` 接线。分支 `feat/v0.1-prototype`，`flutter test` 全绿（~120 测试）。

**实现现状要点（与 M1 plan 草稿的差异，本计划按真实代码为准）:**
- `DeepSeekLlmClient` 用**公有**字段 `dio` / `apiKey` / `baseUrl` / `model`（非 `_dio`）。
- `AiChatRepository({required this.llm, required this.db})` 用**公有**字段 `llm` / `db`。
- 错误映射方法名为 `_mapDioError(DioException)`，可直接复用。

**与 spec 的偏差（实现时遵循）:**
1. **对话内嵌推荐卡片在流式下取消**：`streamReply` 是 `Stream<String>` 纯文本，助手消息 `relatedRecommendations` 恒为空（含 mock）。结构化分片留 function-calling 阶段（spec §5.2）。因此 `chat_page_test` 原「回答带卡片、点击卡片跳转」用例改为「流式文本上屏」；气泡渲染卡片的能力与单测保留（`chat_message_bubble_test`），仅页面流程不再产卡。
2. **`ChatMessageStatus.streaming` 启用**（chat plan 当初按 YAGNI 推迟）。
3. **Mock 流式**复用 `sendMessage` 取整段答案再切片 emit（保留逐字观感，丢卡片）；新增可选 `streamChunkDelay`（默认 28ms，测试传 `Duration.zero` 提速）。
4. **取消(stop)与出错的历史语义**：`streamReply` 用 `finally` 在**完成或被取消**时把已生成文本并入历史（用户可见即上下文）；**出错**时用 `failed` 标志丢弃半句，避免污染后续上下文（spec §5.3）。
5. **`sendMessage` 保留**在接口上（`mock_chat_repository_test` 仍直接测它），但 presentation 不再调用它。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `lib/core/ai/llm_client.dart` | **改**：`LlmClient` 加 `stream(...)` 接口方法 |
| `lib/core/ai/deepseek_llm_client.dart` | **改**：实现 `stream`（SSE 解析 + 复用 `_mapDioError`） |
| `lib/domain/repositories/chat_repository.dart` | **改**：`ChatRepository` 加 `streamReply(...)` |
| `lib/data/ai/ai_chat_repository.dart` | **改**：实现 `streamReply`（累加→历史 / 出错丢弃 / 取消保留） |
| `lib/data/mock/mock_chat_repository.dart` | **改**：实现 `streamReply`（切片定时 emit）+ 可选 `streamChunkDelay` |
| `lib/domain/entities/chat_message.dart` | **改**：`ChatMessageStatus` 增 `streaming` |
| `lib/features/chat/providers/chat_provider.dart` | **改**：`send/regenerate` 走 `streamReply` + 新增 `stop()` |
| `lib/features/chat/widgets/chat_message_bubble.dart` | **改**：`streaming` 渲染已到达文本 + 生成中指示 |
| `lib/features/chat/pages/chat_page.dart` | **改**：响应中发送键变「停止生成」 |
| `test/core/ai/deepseek_llm_client_stream_test.dart` | 新：SSE 逐段解析 / 空 delta / HTTP 错误映射 |
| `test/data/ai/ai_chat_repository_test.dart` | **改**：加流式 `_QueueLlm` + 5 个 `streamReply` 测试；给既有 `_RecordingLlm`/`_FailLlm` 补 `stream` 桩 |
| `test/data/ai/ai_recommendation_repository_test.dart` | **改**：给 `_FakeLlm` 补 `stream` 桩（throw） |
| `test/data/mock/mock_chat_repository_test.dart` | **改**：加 1 个 `streamReply` 测试 |
| `test/features/chat/chat_provider_test.dart` | **重写**：流式 fake + delta 累加 / done / error / stop / regenerate |
| `test/features/chat/chat_message_bubble_test.dart` | **改**：加 streaming（有文本 / 空文本）2 个测试 |
| `test/features/chat/chat_page_test.dart` | **重写**：流式 fake + 文本上屏 / 停止生成切换 / regenerate |

> 不改 `core/di/providers.dart`（流式方法挂在既有已接线仓储上）、不改 domain 其它实体、不改推荐/详情链路。既有 ~120 测试默认 `mock`，须保持全绿。

---

## Task 1: `LlmClient.stream` 接口 + `DeepSeekLlmClient.stream`（SSE）

**Files:**
- Modify: `lib/core/ai/llm_client.dart`
- Modify: `lib/core/ai/deepseek_llm_client.dart`
- Modify: `test/data/ai/ai_recommendation_repository_test.dart`（补 `stream` 桩）
- Modify: `test/data/ai/ai_chat_repository_test.dart`（补 `stream` 桩）
- Test: `test/core/ai/deepseek_llm_client_stream_test.dart`

- [ ] **Step 1: 在 `lib/core/ai/llm_client.dart` 给接口加 `stream`**

把 `abstract interface class LlmClient { ... }` 整体替换为：
```dart
abstract interface class LlmClient {
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  });

  /// 流式补全：逐段 emit 文本增量（delta）。
  /// 失败 → Stream 抛错（[AppException]）；完成 → 正常关闭。
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  });
}
```
（`LlmMessage` 类保持不变。`Stream` 由 `dart:core` 导出，无需新增 import。）

- [ ] **Step 2: 写失败测试 `test/core/ai/deepseek_llm_client_stream_test.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/deepseek_llm_client.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';

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

DeepSeekLlmClient _client(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return DeepSeekLlmClient(
    dio: dio,
    apiKey: 'sk-test',
    baseUrl: 'https://api.deepseek.com',
    model: 'deepseek-chat',
  );
}

/// 把若干 SSE 事件行编码为分块字节流（每个事件单独成块，模拟逐段到达）。
ResponseBody _sseBody(List<String> events, {int code = 200}) {
  Stream<Uint8List> chunks() async* {
    for (final e in events) {
      yield Uint8List.fromList(utf8.encode(e));
    }
  }

  return ResponseBody(
    chunks(),
    code,
    headers: {
      Headers.contentTypeHeader: ['text/event-stream'],
    },
  );
}

String _delta(String content) =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': content},
        },
      ],
    })}\n\n';

void main() {
  test('逐段解析 SSE delta，请求体含 stream:true', () async {
    RequestOptions? captured;
    final adapter = _FakeAdapter((options) async {
      captured = options;
      return _sseBody([_delta('你'), _delta('好'), 'data: [DONE]\n\n']);
    });

    final deltas = await _client(
      adapter,
    ).stream(messages: const [LlmMessage('user', 'hi')]).toList();

    expect(deltas, ['你', '好']);
    final data = captured!.data as Map;
    expect(data['model'], 'deepseek-chat');
    expect(data['stream'], true);
  });

  test('忽略空 delta 与非 data 行', () async {
    final adapter = _FakeAdapter(
      (_) async => _sseBody([
        ': keep-alive\n\n',
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'role': 'assistant'},
            },
          ],
        })}\n\n', // 无 content
        _delta('答案'),
        'data: [DONE]\n\n',
      ]),
    );

    final deltas = await _client(
      adapter,
    ).stream(messages: const [LlmMessage('user', 'hi')]).toList();

    expect(deltas, ['答案']);
  });

  test('HTTP 500 → stream 抛 ServerException', () async {
    final adapter = _FakeAdapter(
      (_) async => ResponseBody.fromString(
        '{"error":"err"}',
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    await expectLater(
      _client(adapter).stream(messages: const [LlmMessage('user', 'hi')]),
      emitsError(isA<ServerException>()),
    );
  });

  test('连接错误 → stream 抛 NetworkException', () async {
    final adapter = _FakeAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(
      _client(adapter).stream(messages: const [LlmMessage('user', 'hi')]),
      emitsError(isA<NetworkException>()),
    );
  });
}
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `flutter test test/core/ai/deepseek_llm_client_stream_test.dart`
Expected: FAIL（编译错误：`DeepSeekLlmClient` 未实现接口新增的 `stream`）。

- [ ] **Step 4: 实现 `DeepSeekLlmClient.stream`**

在 `lib/core/ai/deepseek_llm_client.dart` 顶部 import 区加：
```dart
import 'dart:convert';
```
（即文件头变为 `import 'dart:convert';` + `import 'package:dio/dio.dart';` + 既有三个相对 import。）

在 `complete(...)` 方法之后、`_mapDioError` 之前插入 `stream` 实现：
```dart
  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) async* {
    final Response<ResponseBody> response;
    try {
      response = await dio.post<ResponseBody>(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': Headers.jsonContentType,
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': model,
          'messages': messages.map((m) => m.toJson()).toList(),
          'temperature': temperature,
          'stream': true,
        },
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }

    final body = response.data;
    if (body == null) throw const ServerException();

    final lines = body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') return;

        String? delta;
        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty && choices.first is Map) {
            final deltaMap = (choices.first as Map)['delta'];
            if (deltaMap is Map) delta = deltaMap['content'] as String?;
          }
        } catch (_) {
          delta = null; // 坏行跳过，不中断整条流
        }
        if (delta != null && delta.isNotEmpty) yield delta;
      }
    } on DioException catch (e) {
      throw _mapDioError(e); // 流中途网络中断
    }
  }
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/core/ai/deepseek_llm_client_stream_test.dart`
Expected: PASS（4 个）。

- [ ] **Step 6: 给既有 `LlmClient` 假实现补 `stream` 桩（保持全量编译）**

接口新增 `stream` 后，三个非流式假实现需补桩才能编译。它们只服务非流式测试，故桩直接抛异常。

在 `test/data/ai/ai_recommendation_repository_test.dart` 的 `_FakeLlm` 类内（`complete` 之后）追加：
```dart
  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
```

在 `test/data/ai/ai_chat_repository_test.dart` 的 `_RecordingLlm` 与 `_FailLlm` 两个类内各追加同样的桩：
```dart
  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) => throw UnimplementedError();
```

- [ ] **Step 7: 全量验证并提交**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全绿（既有 + 本任务新增 4）。
```bash
git add lib/core/ai/llm_client.dart lib/core/ai/deepseek_llm_client.dart test/core/ai/deepseek_llm_client_stream_test.dart test/data/ai/ai_recommendation_repository_test.dart test/data/ai/ai_chat_repository_test.dart
git commit -m "feat: add LlmClient.stream + DeepSeek SSE streaming (M2)"
```

---

## Task 2: `ChatRepository.streamReply` + Ai/Mock 实现

**Files:**
- Modify: `lib/domain/repositories/chat_repository.dart`
- Modify: `lib/data/ai/ai_chat_repository.dart`
- Modify: `lib/data/mock/mock_chat_repository.dart`
- Modify: `test/data/ai/ai_chat_repository_test.dart`（加流式 fake + 5 测试）
- Modify: `test/data/mock/mock_chat_repository_test.dart`（加 1 测试）
- Modify: `test/features/chat/chat_provider_test.dart`（临时补 `streamReply` 桩）
- Modify: `test/features/chat/chat_page_test.dart`（临时补 `streamReply` 桩）

- [ ] **Step 1: 在 `lib/domain/repositories/chat_repository.dart` 给接口加 `streamReply`**

把整个文件替换为：
```dart
import '../../core/result/result.dart';
import '../entities/chat_result.dart';

abstract interface class ChatRepository {
  /// 发送一条追问消息，返回助手回答（非流式，mock 直接测用）。
  /// [sessionId] 维持多轮上下文；[professorId] 可锚定某位导师。
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  });

  /// 流式回答：逐段 emit 文本增量；完成或被取消时把已生成整段并入会话历史，
  /// 出错则丢弃半句。失败经 Stream 抛 [AppException]。
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  });
}
```

- [ ] **Step 2: 写失败测试——在 `test/data/ai/ai_chat_repository_test.dart` 顶部加流式 fake，并追加 5 个 `streamReply` 测试**

在文件顶部 import 区追加（用于受控取消测试）：
```dart
import 'dart:async';
```

在既有 `_FailLlm` 类之后、`void main()` 之前，新增一个按队列返回流的假实现：
```dart
/// 每次调用 stream() 按队列取下一条预置流；记录每次传入的 messages 供断言历史。
class _QueueLlm implements LlmClient {
  _QueueLlm(this.queue);

  final List<Stream<String>> queue;
  int _call = 0;
  final List<List<LlmMessage>> calls = [];

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async => throw UnimplementedError();

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) {
    calls.add(messages);
    return queue[_call++];
  }
}
```

在 `main()` 内（既有 sendMessage 测试之后）追加：
```dart
  group('streamReply', () {
    test('透传增量', () async {
      final repo = AiChatRepository(
        llm: _QueueLlm([Stream.fromIterable(const ['你', '好'])]),
        db: MockDb(),
      );
      final out = await repo
          .streamReply(sessionId: 's1', message: '在吗')
          .toList();
      expect(out, ['你', '好']);
    });

    test('完成后整段并入历史，下一轮带上轮上下文', () async {
      final llm = _QueueLlm([
        Stream.fromIterable(const ['你', '好']),
        Stream.fromIterable(const ['再见']),
      ]);
      final repo = AiChatRepository(llm: llm, db: MockDb());
      await repo.streamReply(sessionId: 's1', message: '问题一').toList();
      await repo.streamReply(sessionId: 's1', message: '问题二').toList();
      final contents = llm.calls.last.map((m) => m.content).toList();
      expect(contents, containsAll(['问题一', '你好', '问题二']));
    });

    test('professorId 注入导师上下文到 system', () async {
      final llm = _QueueLlm([Stream.fromIterable(const ['ok'])]);
      final repo = AiChatRepository(llm: llm, db: MockDb());
      await repo
          .streamReply(sessionId: 's1', message: '为什么', professorId: 'p_001')
          .toList();
      final system = llm.calls.last.first;
      expect(system.role, 'system');
      expect(system.content, contains('张三'));
    });

    test('流出错：错误透传且半句不入历史', () async {
      final llm = _QueueLlm([
        Stream<String>.error(const ServerException()),
        Stream.fromIterable(const ['好的']),
      ]);
      final repo = AiChatRepository(llm: llm, db: MockDb());
      await expectLater(
        repo.streamReply(sessionId: 's1', message: '问题一'),
        emitsError(isA<ServerException>()),
      );
      await repo.streamReply(sessionId: 's1', message: '问题二').toList();
      // 第二轮入参里没有 assistant 半句（仅 system + 两条 user）
      expect(llm.calls.last.where((m) => m.role == 'assistant'), isEmpty);
    });

    test('取消订阅(stop)：已生成部分并入历史', () async {
      final controller = StreamController<String>();
      addTearDown(controller.close);
      final llm = _QueueLlm([
        controller.stream,
        Stream.fromIterable(const ['继续']),
      ]);
      final repo = AiChatRepository(llm: llm, db: MockDb());

      final got = <String>[];
      final sub = repo
          .streamReply(sessionId: 's1', message: '问题一')
          .listen(got.add);
      controller.add('部分');
      controller.add('答案');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel(); // 模拟用户 stop()

      await repo.streamReply(sessionId: 's1', message: '问题二').toList();
      final contents = llm.calls.last.map((m) => m.content).toList();
      expect(contents, containsAllInOrder(['问题一', '部分答案', '问题二']));
    });
  });
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `flutter test test/data/ai/ai_chat_repository_test.dart`
Expected: FAIL（`AiChatRepository` 未实现接口新增的 `streamReply`）。

- [ ] **Step 4: 实现 `AiChatRepository.streamReply`**

在 `lib/data/ai/ai_chat_repository.dart` 的 `sendMessage(...)` 方法之后、`_systemPrompt(...)` 之前插入：
```dart
  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) async* {
    final history = _history.putIfAbsent(sessionId, () => []);
    final isRegenerate =
        history.length >= 2 &&
        history[history.length - 2].role == 'user' &&
        history[history.length - 2].content == message &&
        history.last.role == 'assistant';

    if (isRegenerate) {
      history.removeLast();
    } else {
      history.add(LlmMessage('user', message));
    }

    final buffer = StringBuffer();
    var failed = false;
    try {
      await for (final delta in llm.stream(
        messages: [LlmMessage('system', _systemPrompt(professorId)), ...history],
      )) {
        buffer.write(delta);
        yield delta;
      }
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      // 完成或被取消(stop)都并入已生成文本（用户可见即上下文）；
      // 出错则丢弃半句，避免污染后续上下文。
      if (!failed && buffer.isNotEmpty) {
        history.add(LlmMessage('assistant', buffer.toString()));
      }
    }
  }
```
（`Stream` / `StringBuffer` 均由 `dart:core` 导出，无需新增 import。）

- [ ] **Step 5: 运行 AI 仓储测试，确认通过**

Run: `flutter test test/data/ai/ai_chat_repository_test.dart`
Expected: PASS（既有 sendMessage 5 个 + 新增 streamReply 5 个）。

- [ ] **Step 6: 写 Mock 流式失败测试——在 `test/data/mock/mock_chat_repository_test.dart` 追加**

在 `main()` 内末尾追加：
```dart
  test('streamReply 逐段 emit 且可拼回完整答案', () async {
    final repo = MockChatRepository(MockDb(), streamChunkDelay: Duration.zero);
    final chunks = await repo
        .streamReply(sessionId: 's_1', message: '为什么推荐他', professorId: 'p_001')
        .toList();
    expect(chunks.length, greaterThan(1));
    expect(chunks.join(), contains('依据'));
  });
```

- [ ] **Step 7: 运行测试，确认失败**

Run: `flutter test test/data/mock/mock_chat_repository_test.dart`
Expected: FAIL（`MockChatRepository` 未实现 `streamReply`，且构造函数无 `streamChunkDelay`）。

- [ ] **Step 8: 实现 `MockChatRepository.streamReply` + `streamChunkDelay`**

在 `lib/data/mock/mock_chat_repository.dart` 顶部 import 区追加：
```dart
import 'dart:math' as math;
```

把构造函数与字段：
```dart
  MockChatRepository(this._db);

  final MockDb _db;
```
替换为：
```dart
  MockChatRepository(this._db, {this.streamChunkDelay = const Duration(milliseconds: 28)});

  final MockDb _db;

  /// 每片之间的间隔，制造逐字流式观感；测试可传 [Duration.zero] 提速。
  final Duration streamChunkDelay;
```

在 `sendMessage(...)` 方法之后、`bool _contains(...)` 之前插入：
```dart
  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) async* {
    final res = await sendMessage(
      sessionId: sessionId,
      message: message,
      professorId: professorId,
    );
    final answer = switch (res) {
      Success(:final data) => data.answer,
      Failure(:final error) => error.message,
    };
    for (final chunk in _sliceForStream(answer)) {
      await Future<void>.delayed(streamChunkDelay);
      yield chunk;
    }
  }

  /// 把整段答案按固定字符数切片，离线兜底的逐字流式（不含推荐卡片）。
  Iterable<String> _sliceForStream(String text, {int size = 4}) sync* {
    for (var i = 0; i < text.length; i += size) {
      yield text.substring(i, math.min(i + size, text.length));
    }
  }
```

- [ ] **Step 9: 运行 Mock 测试，确认通过**

Run: `flutter test test/data/mock/mock_chat_repository_test.dart`
Expected: PASS（既有 6 + 新增 1）。

- [ ] **Step 10: 给 widget 测试的 `_FakeChatRepo` 补 `streamReply` 桩（保持全量编译）**

`ChatRepository` 新增 `streamReply` 后，provider/page 测试里的假实现需补桩。presentation 此刻仍走 `sendMessage`（Task 3 才切流式），故桩返回空流即可——这两个文件分别在 Task 3 / Task 5 被整体重写。

在 `test/features/chat/chat_provider_test.dart` 的 `_FakeChatRepo` 类内（`sendMessage` 之后）追加：
```dart
  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) => Stream<String>.empty();
```

在 `test/features/chat/chat_page_test.dart` 的 `_FakeChatRepo` 类内追加同样的桩。

- [ ] **Step 11: 全量验证并提交**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全绿（既有 + 本任务 streamReply AI 5 + Mock 1）。
```bash
git add lib/domain/repositories/chat_repository.dart lib/data/ai/ai_chat_repository.dart lib/data/mock/mock_chat_repository.dart test/data/ai/ai_chat_repository_test.dart test/data/mock/mock_chat_repository_test.dart test/features/chat/chat_provider_test.dart test/features/chat/chat_page_test.dart
git commit -m "feat: add ChatRepository.streamReply (Ai grounded + Mock sliced) (M2)"
```

---

## Task 3: `ChatMessageStatus.streaming` + `ChatNotifier` 流式（send/stop/regenerate）

**Files:**
- Modify: `lib/domain/entities/chat_message.dart`
- Modify: `lib/features/chat/providers/chat_provider.dart`
- Rewrite: `test/features/chat/chat_provider_test.dart`

- [ ] **Step 1: 给 `ChatMessageStatus` 加 `streaming`**

在 `lib/domain/entities/chat_message.dart` 把：
```dart
/// 消息状态。V0.2 非流式只用 sending/done/error；streaming 留待 V1.0。
enum ChatMessageStatus { sending, done, error }
```
替换为：
```dart
/// 消息状态。streaming = 正在逐字接收；sending 保留为「等待首个增量」的思考态。
enum ChatMessageStatus { sending, streaming, done, error }
```
（无 exhaustive switch 依赖该枚举，新增值非破坏性。）

- [ ] **Step 2: 写失败测试——整体重写 `test/features/chat/chat_provider_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/features/chat/providers/chat_provider.dart';

/// 流式假仓储：每次 streamReply 由 [build] 现造一条流。
class _StreamChatRepo implements ChatRepository {
  _StreamChatRepo(this.build);

  final Stream<String> Function() build;
  int streamCalls = 0;
  String? lastSessionId;
  String? lastMessage;
  String? lastProfessorId;

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async => throw UnimplementedError();

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) {
    streamCalls++;
    lastSessionId = sessionId;
    lastMessage = message;
    lastProfessorId = professorId;
    return build();
  }
}

ProviderContainer _containerWith(ChatRepository repo) => ProviderContainer(
  overrides: [chatRepositoryProvider.overrideWithValue(repo)],
);

void main() {
  test('start 注入会话并植入一条助手问候', () {
    final container = _containerWith(
      _StreamChatRepo(() => Stream.fromIterable(const ['x'])),
    );
    addTearDown(container.dispose);

    container
        .read(chatProvider.notifier)
        .start(sessionId: 's_1', professorId: 'p_001');
    final state = container.read(chatProvider);

    expect(state.sessionId, 's_1');
    expect(state.professorId, 'p_001');
    expect(state.messages, hasLength(1));
    expect(state.messages.single.role, ChatRole.assistant);
    expect(state.isResponding, isFalse);
  });

  test('send：逐段增量累加为助手回答并置 done', () async {
    final repo = _StreamChatRepo(
      () => Stream.fromIterable(const ['测', '试', '回答']),
    );
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier)
      ..start(sessionId: 's_1', professorId: 'p_001');

    await notifier.send('为什么推荐他');
    final msgs = container.read(chatProvider).messages;

    expect(msgs, hasLength(3));
    expect(msgs[1].role, ChatRole.user);
    expect(msgs[1].content, '为什么推荐他');
    expect(msgs.last.role, ChatRole.assistant);
    expect(msgs.last.status, ChatMessageStatus.done);
    expect(msgs.last.content, '测试回答');
    expect(container.read(chatProvider).isResponding, isFalse);
    expect(repo.lastSessionId, 's_1');
    expect(repo.lastMessage, '为什么推荐他');
    expect(repo.lastProfessorId, 'p_001');
  });

  test('send 失败：助手消息标记 error 并显示文案', () async {
    final container = _containerWith(
      _StreamChatRepo(() => Stream<String>.error(const ServerException())),
    );
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier)
      ..start(sessionId: 's_1');

    await notifier.send('为什么推荐他');
    final last = container.read(chatProvider).messages.last;

    expect(last.status, ChatMessageStatus.error);
    expect(last.content, '服务异常，请稍后重试');
    expect(container.read(chatProvider).isResponding, isFalse);
  });

  test('regenerate 重发上一条用户消息（再次流式）', () async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答']));
    final container = _containerWith(repo);
    addTearDown(container.dispose);
    final notifier = container.read(chatProvider.notifier)
      ..start(sessionId: 's_1');

    await notifier.send('为什么推荐他');
    expect(repo.streamCalls, 1);

    await notifier.regenerate();
    expect(repo.streamCalls, 2);
    expect(repo.lastMessage, '为什么推荐他');
    expect(container.read(chatProvider).messages, hasLength(3));
  });

  test('stop 取消流并把流式消息收尾为 done（保留已生成部分）', () async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    final notifier =
        (_containerWith(_StreamChatRepo(() => controller.stream))
              ..read(chatProvider.notifier).start(sessionId: 's_1'))
            .read(chatProvider.notifier);

    final pending = notifier.send('为什么'); // 不 await：流未结束
    controller.add('部分');
    await Future<void>.delayed(Duration.zero);
    controller.add('答案');
    await Future<void>.delayed(Duration.zero);

    final mid = notifier.state;
    expect(mid.messages.last.status, ChatMessageStatus.streaming);
    expect(mid.messages.last.content, '部分答案');
    expect(mid.isResponding, isTrue);

    await notifier.stop();
    await pending; // stop 完成挂起的 send

    final last = notifier.state.messages.last;
    expect(last.status, ChatMessageStatus.done);
    expect(last.content, '部分答案');
    expect(notifier.state.isResponding, isFalse);
  });
}
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `flutter test test/features/chat/chat_provider_test.dart`
Expected: FAIL（`ChatNotifier` 无 `stop()`，且仍调用 `sendMessage`；流式断言不通过）。

- [ ] **Step 4: 重写 `lib/features/chat/providers/chat_provider.dart`**

`ChatState` 类整体保持不变（含 `copyWith` / `initial`）；只改 `ChatNotifier` 与 import。把文件替换为：
```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/entities/chat_message.dart';

/// 单屏对话状态。messages 含问候 / 用户 / 助手消息；isResponding 控制输入禁用。
class ChatState {
  const ChatState({
    required this.sessionId,
    required this.professorId,
    required this.messages,
    required this.isResponding,
  });

  const ChatState.initial()
    : sessionId = null,
      professorId = null,
      messages = const [],
      isResponding = false;

  final String? sessionId;
  final String? professorId;
  final List<ChatMessage> messages;
  final bool isResponding;

  ChatState copyWith({
    String? sessionId,
    String? professorId,
    List<ChatMessage>? messages,
    bool? isResponding,
  }) => ChatState(
    sessionId: sessionId ?? this.sessionId,
    professorId: professorId ?? this.professorId,
    messages: messages ?? this.messages,
    isResponding: isResponding ?? this.isResponding,
  );
}

/// 每页一个 Notifier。对话同一时刻仅一个屏幕，故用全局 Notifier + 显式 start 注入会话。
class ChatNotifier extends Notifier<ChatState> {
  int _seq = 0;
  StreamSubscription<String>? _sub;
  Completer<void>? _turn;

  @override
  ChatState build() {
    ref.onDispose(() {
      _sub?.cancel();
    });
    return const ChatState.initial();
  }

  void start({required String sessionId, String? professorId}) {
    if (state.sessionId == sessionId && state.professorId == professorId) {
      return;
    }
    _seq = 0;
    state = ChatState(
      sessionId: sessionId,
      professorId: professorId,
      messages: [
        _assistant(
          '你好，我可以基于上一步的推荐继续解答。\n\n'
          '试试问我：**为什么推荐**、**相似导师**、**只看某地**、**是否适合硕士 / 博士**。',
        ),
      ],
      isResponding: false,
    );
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || state.sessionId == null || state.isResponding) {
      return;
    }

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id: _nextId(),
          role: ChatRole.user,
          content: content,
          createdAt: DateTime.now(),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
      ],
    );

    await _streamRespond(content);
  }

  Future<void> regenerate() async {
    if (state.isResponding || state.sessionId == null) return;

    final messages = state.messages;
    final lastUserIndex = messages.lastIndexWhere(
      (m) => m.role == ChatRole.user,
    );
    if (lastUserIndex == -1) return;

    final lastUserText = messages[lastUserIndex].content;
    state = state.copyWith(messages: messages.sublist(0, lastUserIndex + 1));
    await _streamRespond(lastUserText);
  }

  /// 用户主动停止生成：取消订阅，把进行中的 streaming 助手消息收尾为 done（保留已生成部分）。
  Future<void> stop() async {
    final sub = _sub;
    if (sub == null) return;
    _sub = null;
    await sub.cancel();

    final messages = [...state.messages];
    final i = messages.lastIndexWhere(
      (m) => m.status == ChatMessageStatus.streaming,
    );
    if (i != -1) {
      messages[i] = _withStatus(messages[i], ChatMessageStatus.done);
    }
    state = state.copyWith(messages: messages, isResponding: false);
    _completeTurn();
  }

  Future<void> _streamRespond(String content) async {
    final assistantId = _nextId();
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id: assistantId,
          role: ChatRole.assistant,
          content: '',
          createdAt: DateTime.now(),
          relatedRecommendations: const [],
          status: ChatMessageStatus.streaming,
        ),
      ],
      isResponding: true,
    );

    final buffer = StringBuffer();
    _turn = Completer<void>();
    _sub = ref
        .read(chatRepositoryProvider)
        .streamReply(
          sessionId: state.sessionId!,
          message: content,
          professorId: state.professorId,
        )
        .listen(
          (delta) {
            buffer.write(delta);
            _setAssistant(
              assistantId,
              buffer.toString(),
              ChatMessageStatus.streaming,
            );
          },
          onError: (Object error) {
            final message = error is AppException
                ? error.message
                : const UnknownException().message;
            _setAssistant(assistantId, message, ChatMessageStatus.error);
            _sub = null;
            state = state.copyWith(isResponding: false);
            _completeTurn();
          },
          onDone: () {
            _setAssistant(assistantId, buffer.toString(), ChatMessageStatus.done);
            _sub = null;
            state = state.copyWith(isResponding: false);
            _completeTurn();
          },
          cancelOnError: true,
        );

    await _turn!.future;
  }

  void _setAssistant(String id, String content, ChatMessageStatus status) {
    final messages = [...state.messages];
    final i = messages.indexWhere((m) => m.id == id);
    if (i == -1) return;
    messages[i] = ChatMessage(
      id: id,
      role: ChatRole.assistant,
      content: content,
      createdAt: messages[i].createdAt,
      relatedRecommendations: const [],
      status: status,
    );
    state = state.copyWith(messages: messages);
  }

  ChatMessage _withStatus(ChatMessage m, ChatMessageStatus status) =>
      ChatMessage(
        id: m.id,
        role: m.role,
        content: m.content,
        createdAt: m.createdAt,
        relatedRecommendations: m.relatedRecommendations,
        status: status,
      );

  void _completeTurn() {
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
  }

  String _nextId() => 'm_${_seq++}';

  ChatMessage _assistant(String content) => ChatMessage(
    id: _nextId(),
    role: ChatRole.assistant,
    content: content,
    createdAt: DateTime.now(),
    relatedRecommendations: const [],
    status: ChatMessageStatus.done,
  );
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/features/chat/chat_provider_test.dart`
Expected: PASS（5 个）。

- [ ] **Step 6: 全量验证并提交**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全绿。
```bash
git add lib/domain/entities/chat_message.dart lib/features/chat/providers/chat_provider.dart test/features/chat/chat_provider_test.dart
git commit -m "feat: stream chat via streamReply + stop() in ChatNotifier (M2)"
```

---

## Task 4: `ChatMessageBubble` 流式渲染

**Files:**
- Modify: `lib/features/chat/widgets/chat_message_bubble.dart`
- Modify: `test/features/chat/chat_message_bubble_test.dart`

- [ ] **Step 1: 写失败测试——在 `test/features/chat/chat_message_bubble_test.dart` 追加两个 streaming 用例**

在 `main()` 内（既有用例之后）追加：
```dart
  testWidgets('流式中（有文本）显示 Markdown 与生成中指示', (tester) async {
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '正在生成的**部分**',
        status: ChatMessageStatus.streaming,
      ),
    );

    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.text('生成中…'), findsOneWidget);
  });

  testWidgets('流式中（空文本）显示正在思考', (tester) async {
    await _pump(
      tester,
      _msg(
        role: ChatRole.assistant,
        content: '',
        status: ChatMessageStatus.streaming,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在思考…'), findsOneWidget);
  });
```

> 注意：streaming 有文本时气泡含一个无限循环的 `CircularProgressIndicator`，**不要**用 `pumpAndSettle`（会超时）；`_pump` 只泵一帧即可断言。

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: FAIL（streaming 有文本时当前渲染为普通 `GptMarkdown`，找不到「生成中…」）。

- [ ] **Step 3: 改 `lib/features/chat/widgets/chat_message_bubble.dart`**

把 `build` 方法里开头的「sending → 正在思考…」整段：
```dart
    if (message.status == ChatMessageStatus.sending) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('正在思考…'),
            ],
          ),
        ),
      );
    }
```
替换为（thinking = sending 或 streaming 但还没有文本）：
```dart
    final isThinking =
        message.status == ChatMessageStatus.sending ||
        (message.status == ChatMessageStatus.streaming &&
            message.content.isEmpty);
    if (isThinking) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('正在思考…'),
            ],
          ),
        ),
      );
    }
```

在其后、`final scheme = ...` 一段里加 `isStreaming`，把：
```dart
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    final isError = message.status == ChatMessageStatus.error;
    final bubbleColor = isUser
        ? scheme.primaryContainer
        : isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final maxWidth = math.min(360.0, MediaQuery.sizeOf(context).width * 0.78);

    final Widget content = (isUser || isError)
        ? Text(message.content)
        : GptMarkdown(message.content);
```
替换为：
```dart
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    final isError = message.status == ChatMessageStatus.error;
    final isStreaming = message.status == ChatMessageStatus.streaming;
    final bubbleColor = isUser
        ? scheme.primaryContainer
        : isError
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final maxWidth = math.min(360.0, MediaQuery.sizeOf(context).width * 0.78);

    final Widget body = (isUser || isError)
        ? Text(message.content)
        : GptMarkdown(message.content);
    final Widget content = isStreaming
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              body,
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 6),
                  Text('生成中…', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          )
        : body;
```
（`Container` 的 `child: content` 一行不变；后续 `relatedRecommendations` 渲染保持不变。）

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: PASS（既有 5 + 新增 2）。

- [ ] **Step 5: 提交**

```bash
git add lib/features/chat/widgets/chat_message_bubble.dart test/features/chat/chat_message_bubble_test.dart
git commit -m "feat: render streaming bubble (partial text + generating indicator) (M2)"
```

---

## Task 5: `ChatPage` 停止生成切换

**Files:**
- Modify: `lib/features/chat/pages/chat_page.dart`
- Rewrite: `test/features/chat/chat_page_test.dart`

- [ ] **Step 1: 写失败测试——整体重写 `test/features/chat/chat_page_test.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/features/chat/pages/chat_page.dart';

/// 流式假仓储：每次 streamReply 由 [build] 现造一条流。
class _StreamChatRepo implements ChatRepository {
  _StreamChatRepo(this.build);

  final Stream<String> Function() build;
  int streamCalls = 0;

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async => throw UnimplementedError();

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) {
    streamCalls++;
    return build();
  }
}

Widget _wrap(_StreamChatRepo repo) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ChatPage(sessionId: 's_test'),
      ),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
    ],
  );
  return ProviderScope(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('挂载后显示标题与快捷问题', (tester) async {
    await tester.pumpWidget(
      _wrap(_StreamChatRepo(() => Stream.fromIterable(const ['x']))),
    );
    await tester.pumpAndSettle();

    expect(find.text('继续追问'), findsOneWidget);
    expect(find.text('有没有相似的导师？'), findsOneWidget);
  });

  testWidgets('点击快捷问题：用户消息上屏并流式返回回答', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['流式', '回答']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('有没有相似的导师？'));
    await tester.pumpAndSettle();

    expect(find.text('有没有相似的导师？'), findsWidgets); // 用户气泡（纯文本）
    expect(repo.streamCalls, 1);
    expect(find.byType(GptMarkdown), findsWidgets); // 问候 + 助手回答
  });

  testWidgets('响应中显示「停止生成」，点击后恢复「发送」', (tester) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    await tester.pumpWidget(_wrap(_StreamChatRepo(() => controller.stream)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士申请吗？'));
    await tester.pump();
    controller.add('部分答案');
    await tester.pump();

    expect(find.byTooltip('停止生成'), findsOneWidget);
    expect(find.byTooltip('发送'), findsNothing);

    await tester.tap(find.byTooltip('停止生成'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byTooltip('发送'), findsOneWidget);
    expect(find.byTooltip('停止生成'), findsNothing);
  });

  testWidgets('重新生成会再次调用仓储', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士申请吗？'));
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 1);

    await tester.tap(find.byTooltip('重新生成'));
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 2);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/features/chat/chat_page_test.dart`
Expected: FAIL（当前输入栏无「停止生成」tooltip）。

- [ ] **Step 3: 改 `lib/features/chat/pages/chat_page.dart`**

把 `build` 里的 `_InputBar(...)` 调用：
```dart
          _InputBar(
            controller: _controller,
            enabled: !state.isResponding,
            onSubmit: _send,
          ),
```
替换为：
```dart
          _InputBar(
            controller: _controller,
            isResponding: state.isResponding,
            onSubmit: _send,
            onStop: () => ref.read(chatProvider.notifier).stop(),
          ),
```

把整个 `_InputBar` 类替换为：
```dart
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isResponding,
    required this.onSubmit,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isResponding;
  final void Function(String) onSubmit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isResponding,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: isResponding ? null : onSubmit,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '输入你的追问…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isResponding)
              IconButton.filled(
                tooltip: '停止生成',
                onPressed: onStop,
                icon: const Icon(Icons.stop),
              )
            else
              IconButton.filled(
                tooltip: '发送',
                onPressed: () => onSubmit(controller.text),
                icon: const Icon(Icons.send),
              ),
          ],
        ),
      ),
    );
  }
}
```
（`_QuickQuestions` 仍用 `enabled: !state.isResponding`，不变；AppBar「重新生成」按钮不变。）

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/features/chat/chat_page_test.dart`
Expected: PASS（4 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/features/chat/pages/chat_page.dart test/features/chat/chat_page_test.dart
git commit -m "feat: toggle send/stop button while streaming in ChatPage (M2)"
```

---

## Task 6: 收尾全量验证 + 人工冒烟

**Files:** 无（仅验证）

- [ ] **Step 1: 全量分析与测试**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全部 PASS——既有 + 本里程碑新增（deepseek stream 4、AI streamReply 5、Mock streamReply 1、provider 5、bubble +2、page 4，去掉 page 原 3 个里被替换的部分）。

- [ ] **Step 2: 确认工作区干净**

Run: `git status --short`
Expected: 干净（除可能的 `.agents/` 等非本任务文件）。

- [ ] **Step 3: 人工冒烟（需真实 key）**

Run（替换为真实 key）：
```bash
flutter run --dart-define=LLM_API_KEY=sk-你的key
```
手动核对：
- 首页输入「医学影像 上海 硕士」→ 进「继续追问」→ 问「为什么推荐他」→ **回答逐字上屏**（不是整段突现），底部出现「生成中…」指示，发送键变为**停止**图标。
- 生成途中点**停止** → 立即停下，已生成文本保留，发送键恢复；再问下一句，上下文仍连贯（上一句被并入历史）。
- 断网或填错 key → 流式气泡转**错误态**显示友好文案，可「重新生成」。
- 关 key 直接 `flutter run` → `mock` 流式：回答仍逐字出现（离线演示安全），无推荐卡片（已知偏差）。
- 详情页「继续追问」→ 流式回答含该导师姓名（接地生效）。

> 本里程碑解锁后续：M3 套磁邮件（生成式长文 + 流式）、M4 多导师对比、M5 背景匹配、M6 打磨与作品说明。

---

## 自查（Self-Review）记录

- **Spec 覆盖**（M2 spec §2–§5）：
  - §2.1 `LlmClient.stream` + DeepSeek SSE → Task 1。
  - §2.2 `ChatRepository.streamReply` + `AiChatRepository`（接地/多轮/累加入历史）+ `MockChatRepository`（切片 emit）→ Task 2。
  - §2.3 `ChatMessageStatus.streaming` → Task 3 Step 1。
  - §2.4 `ChatNotifier`：delta 累加 / 完成 done / 出错 error / 新增 `stop()` → Task 3。
  - §2.5 `ChatMessageBubble`（streaming 渲染文本 + 生成中）→ Task 4；`ChatPage`（发送↔停止切换、regenerate 走流）→ Task 5。
  - §3 错误与兜底（流中途出错转 error；stop 不算错误保留；mock 离线流式）→ Task 2/3/6。
  - §4 测试策略 5 张表 → 分别落在 Task 1（client stream）、Task 2（ai/mock repo stream）、Task 3（provider stream + stop）、Task 5（page stream）；既有非流式 mock/`sendMessage` 测试保留。
  - §5 偏差（流式提前到 M2、`Stream<String>` 简化、完成后并入历史 + stop 保留半句）→ 已在「与 spec 的偏差」与实现注释体现。
- **占位扫描**：无 TBD/TODO；每个 code step 给出完整可编译代码 + 可运行命令与期望。
- **接口扩展的连锁编译**：`LlmClient.stream` 影响 `DeepSeekLlmClient`(T1 实现) + 三个非流式假实现 `_FakeLlm`/`_RecordingLlm`/`_FailLlm`(T1 补桩)；`ChatRepository.streamReply` 影响 `AiChatRepository`/`MockChatRepository`(T2 实现) + provider/page `_FakeChatRepo`(T2 临时桩 → T3/T5 整体重写)。每个 Task 末尾 `flutter analyze && flutter test` 保证全量编译与全绿。
- **类型一致性**：
  - `LlmClient.stream({required List<LlmMessage> messages, double temperature}) → Stream<String>` 在接口(T1)、`DeepSeekLlmClient`(T1)、`_QueueLlm`(T2) 签名一致；非流式假实现的桩签名一致。
  - `ChatRepository.streamReply({required String sessionId, required String message, String? professorId}) → Stream<String>` 在接口(T1/T2)、`AiChatRepository`(T2)、`MockChatRepository`(T2)、`_StreamChatRepo`(T3/T5) 一致；`sendMessage` 旧签名未改。
  - `ChatNotifier`：`send`/`regenerate`/`stop`/`_streamRespond`/`_setAssistant`/`_withStatus`/`_completeTurn` 字段 `_sub`(`StreamSubscription<String>?`)、`_turn`(`Completer<void>?`) 自洽。
  - `MockChatRepository(this._db, {Duration streamChunkDelay = const Duration(milliseconds: 28)})` 在实现(T2)、DI（未改，用默认）、测试（传 `Duration.zero`）一致；既有位置构造仍合法。
  - `ChatMessageStatus{sending, streaming, done, error}` 在 entity(T3)、bubble(T4)、provider(T3)、测试一致；无 exhaustive switch 受影响。
- **dio 流式 API 核实**（dio 5.9.2 源码）：`ResponseBody(Stream<Uint8List>, statusCode, {headers})` 主构造可造流；`ResponseType.stream` 时 `transformResponse` 原样返回 `ResponseBody`，故 `response.data` 即 `ResponseBody`，读 `.stream`；非 2xx 由默认 `validateStatus` 抛 `DioException(badResponse)`，`_mapDioError` 经 `fromStatusCode` → `ServerException`；`utf8.decoder`/`LineSplitter` 来自 `dart:convert`；`StreamController`/`Completer`/`StreamSubscription` 处显式 `import 'dart:async'`。
- **取消语义核实**：`AiChatRepository.streamReply` 为 `async*`，挂起在 `yield`/`await for` 时被消费方 `cancel()` 触发 `finally`（不进 `catch`），`failed` 仍为 false → 写入已生成部分；正常完成同样经 `finally` 写整段；出错经 `catch` 置 `failed=true` → `finally` 跳过。provider `stop()` 取消订阅后自行 `_completeTurn()` 解挂 `send` 的 await（cancel 不触发 onDone/onError）。
- **不回归**：默认 `mock`；`sendMessage` 与其 mock 单测保留；推荐/详情/收藏/历史链路零改动；DI 不改。Task 6 跑全量回归。
- **已知偏差留痕**：流式下对话内不再产推荐卡片（含 mock），`chat_page_test` 原卡片导航用例改为流式文本用例；气泡卡片渲染能力与其单测仍在。
