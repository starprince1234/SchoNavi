# SchoNavi M1 · 核心闭环转真（真实大模型接入）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把现有「首页输入 → 推荐 → 对话追问」链路的后端实现从关键词 Mock 换成真实 DeepSeek 生成（接地、结构化输出、多轮），presentation/domain 零改动，Mock 保留为离线兜底。

**Architecture:** 新增 `core/ai/`（provider 无关 `LlmClient` + `DeepSeekLlmClient`，OpenAI 兼容、非流式）与 `data/ai/`（`AiRecommendationRepository`/`AiChatRepository` 实现既有 domain 接口 + `ProfessorCandidateSource` 候选检索接缝）。`DataSource` 扩为 `mock|ai|http`，DI 按配置切换；无 key 自动 mock。导师事实回填自 `MockDb` fixtures，模型只产出 matchLevel/reason/limitations/对话文本。

**Tech Stack:** Flutter 3.44 / Dart 3.12；`flutter_riverpod ^3.3.1`（手写 provider）；`go_router ^17`；新增 `dio ^5`（OpenAI 兼容 HTTP）；`gpt_markdown ^1.1.7`。

**Spec 依据:** `docs/superpowers/specs/2026-06-09-schonavi-m1-llm-core-design.md`。

**前置条件（已完成）:** V0.1 推荐链路 + V0.2 收藏/历史/对话（mock）已落地，`flutter test` ~100 测试全绿，分支 `feat/v0.1-prototype`。

**与 spec 的偏差:** 见 spec §13（新增 `DataSource.ai`；对话历史存仓库内部；地区由模型推断；matchScore=null；流式留 M2）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `pubspec.yaml` | **改**：加 `dio` |
| `lib/core/config/app_config.dart` | **改**：`DataSource.ai`、`LlmConfig`、`AppConfig.resolve` |
| `lib/main.dart` | **改**：override `appConfigProvider`（读 dart-define） |
| `lib/core/ai/llm_client.dart` | 新：`LlmMessage` + `LlmClient` 接口 |
| `lib/core/ai/deepseek_llm_client.dart` | 新：dio 实现 + 错误映射 |
| `lib/data/ai/professor_candidate_source.dart` | 新：候选检索接缝 + `MockDbCandidateSource` |
| `lib/data/ai/ai_recommendation_repository.dart` | 新：接地结构化推荐 |
| `lib/data/ai/ai_chat_repository.dart` | 新：多轮 + 接地对话 |
| `lib/core/di/providers.dart` | **改**：`dioProvider`/`llmClientProvider`/`professorCandidateSourceProvider` + 三仓储 `ai` 分支 |
| `test/core/config/app_config_test.dart` | `AppConfig.resolve` 单测 |
| `test/core/ai/deepseek_llm_client_test.dart` | 客户端请求/错误映射（假 adapter） |
| `test/data/ai/ai_recommendation_repository_test.dart` | 解析/接地/空/坏 JSON/失败（假 LlmClient） |
| `test/data/ai/ai_chat_repository_test.dart` | 透传/多轮/接地/regenerate/失败 |
| `test/core/di/ai_providers_test.dart` | `dataSource=ai` 接线 |

> 不改 domain 实体/接口、presentation、既有 mock 文件。既有 ~100 测试默认 `mock`，须保持全绿。

---

## Task 1: 依赖 + 配置 + 启动注入

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/config/app_config.dart`
- Modify: `lib/main.dart`
- Test: `test/core/config/app_config_test.dart`

- [ ] **Step 1: 加 dio 依赖**

Run: `flutter pub add dio`
Expected: `pubspec.yaml` 的 `dependencies` 下新增 `dio: ^5.x`，`flutter pub get` 成功。

- [ ] **Step 2: 写失败测试 `test/core/config/app_config_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';

void main() {
  test('无 key → mock', () {
    final cfg = AppConfig.resolve(apiKey: '');
    expect(cfg.dataSource, DataSource.mock);
    expect(cfg.llm.isConfigured, isFalse);
  });

  test('有 key → ai，并透传 baseUrl/model', () {
    final cfg = AppConfig.resolve(
      apiKey: 'sk-x',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
    );
    expect(cfg.dataSource, DataSource.ai);
    expect(cfg.llm.apiKey, 'sk-x');
    expect(cfg.llm.baseUrl, 'https://api.deepseek.com');
    expect(cfg.llm.model, 'deepseek-chat');
  });
}
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `flutter test test/core/config/app_config_test.dart`
Expected: FAIL（`AppConfig.resolve`/`LlmConfig`/`DataSource.ai` 不存在）。

- [ ] **Step 4: 改 `lib/core/config/app_config.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DataSource { mock, ai, http }

class FeatureFlags {
  const FeatureFlags({this.showMatchScore = false});

  final bool showMatchScore;
}

class LlmConfig {
  const LlmConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-chat',
  });

  final String apiKey;
  final String baseUrl;
  final String model;

  bool get isConfigured => apiKey.isNotEmpty;
}

class AppConfig {
  const AppConfig({
    this.dataSource = DataSource.mock,
    this.appVersion = '0.1.0',
    this.featureFlags = const FeatureFlags(),
    this.llm = const LlmConfig(apiKey: ''),
  });

  final DataSource dataSource;
  final String appVersion;
  final FeatureFlags featureFlags;
  final LlmConfig llm;

  /// 纯函数：有 key → ai，否则 → mock。便于单测，不依赖 dart-define。
  factory AppConfig.resolve({
    required String apiKey,
    String baseUrl = 'https://api.deepseek.com',
    String model = 'deepseek-chat',
    String appVersion = '0.1.0',
  }) {
    final llm = LlmConfig(apiKey: apiKey, baseUrl: baseUrl, model: model);
    return AppConfig(
      dataSource: llm.isConfigured ? DataSource.ai : DataSource.mock,
      appVersion: appVersion,
      llm: llm,
    );
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/core/config/app_config_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 6: 改 `lib/main.dart` 注入配置**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/providers.dart';

const _apiKey = String.fromEnvironment('LLM_API_KEY');
const _baseUrl = String.fromEnvironment(
  'LLM_BASE_URL',
  defaultValue: 'https://api.deepseek.com',
);
const _model = String.fromEnvironment(
  'LLM_MODEL',
  defaultValue: 'deepseek-chat',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: _apiKey, baseUrl: _baseUrl, model: _model),
        ),
      ],
      child: const SchoNaviApp(),
    ),
  );
}
```

- [ ] **Step 7: 验证并提交**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全绿（含既有）。
```bash
git add pubspec.yaml pubspec.lock lib/core/config/app_config.dart lib/main.dart test/core/config/app_config_test.dart
git commit -m "feat: add DataSource.ai + LlmConfig + dart-define wiring (M1)"
```

---

## Task 2: LlmClient 接口 + DeepSeekLlmClient

**Files:**
- Create: `lib/core/ai/llm_client.dart`
- Create: `lib/core/ai/deepseek_llm_client.dart`
- Test: `test/core/ai/deepseek_llm_client_test.dart`

- [ ] **Step 1: 实现 `lib/core/ai/llm_client.dart`**

```dart
import '../result/result.dart';

/// 一条对话消息。role ∈ 'system' | 'user' | 'assistant'。
class LlmMessage {
  const LlmMessage(this.role, this.content);

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// provider 无关的大模型补全客户端。
abstract interface class LlmClient {
  /// 非流式补全。Success(模型文本) | Failure(AppException)。
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  });
}
```

- [ ] **Step 2: 写失败测试 `test/core/ai/deepseek_llm_client_test.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/deepseek_llm_client.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';

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

ResponseBody _json(String body, int code) => ResponseBody.fromString(
  body,
  code,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test('成功取 content；请求体含 model 与 response_format', () async {
    RequestOptions? captured;
    final adapter = _FakeAdapter((options) async {
      captured = options;
      return _json(
        jsonEncode({
          'choices': [
            {
              'message': {'content': '生成结果'},
            },
          ],
        }),
        200,
      );
    });
    final res = await _client(adapter).complete(
      messages: const [LlmMessage('user', 'hi')],
      jsonMode: true,
    );
    expect((res as Success).data, '生成结果');
    final data = captured!.data as Map;
    expect(data['model'], 'deepseek-chat');
    expect(data['response_format'], {'type': 'json_object'});
    expect(data['stream'], false);
  });

  test('500 → ServerException', () async {
    final adapter = _FakeAdapter((_) async => _json('err', 500));
    final res = await _client(
      adapter,
    ).complete(messages: const [LlmMessage('user', 'hi')]);
    expect((res as Failure).error, isA<ServerException>());
  });

  test('接收超时 → TimeoutException', () async {
    final adapter = _FakeAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    final res = await _client(
      adapter,
    ).complete(messages: const [LlmMessage('user', 'hi')]);
    expect((res as Failure).error, isA<TimeoutException>());
  });

  test('连接错误 → NetworkException', () async {
    final adapter = _FakeAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final res = await _client(
      adapter,
    ).complete(messages: const [LlmMessage('user', 'hi')]);
    expect((res as Failure).error, isA<NetworkException>());
  });

  test('空 choices → ServerException', () async {
    final adapter = _FakeAdapter(
      (_) async => _json(jsonEncode({'choices': []}), 200),
    );
    final res = await _client(
      adapter,
    ).complete(messages: const [LlmMessage('user', 'hi')]);
    expect((res as Failure).error, isA<ServerException>());
  });
}
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `flutter test test/core/ai/deepseek_llm_client_test.dart`
Expected: FAIL（`deepseek_llm_client.dart` 不存在）。

- [ ] **Step 4: 实现 `lib/core/ai/deepseek_llm_client.dart`**

```dart
import 'package:dio/dio.dart';

import '../error/app_exception.dart';
import '../result/result.dart';
import 'llm_client.dart';

/// OpenAI 兼容 `POST {baseUrl}/chat/completions` 的非流式实现（DeepSeek 等）。
class DeepSeekLlmClient implements LlmClient {
  DeepSeekLlmClient({
    required Dio dio,
    required String apiKey,
    required String baseUrl,
    required String model,
  }) : _dio = dio,
       _apiKey = apiKey,
       _baseUrl = baseUrl,
       _model = model;

  final Dio _dio;
  final String _apiKey;
  final String _baseUrl;
  final String _model;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.json,
        ),
        data: {
          'model': _model,
          'messages': messages.map((m) => m.toJson()).toList(),
          'temperature': temperature,
          'stream': false,
          if (jsonMode) 'response_format': {'type': 'json_object'},
        },
      );
      final choices = response.data?['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return const Failure(ServerException());
      }
      final message = (choices.first as Map)['message'] as Map?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) {
        return const Failure(ServerException());
      }
      return Success(content);
    } on DioException catch (e) {
      return Failure(_mapDioError(e));
    } catch (_) {
      return const Failure(UnknownException());
    }
  }

  AppException _mapDioError(DioException e) {
    final code = e.response?.statusCode;
    if (code != null) return AppException.fromStatusCode(code);
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      default:
        return const UnknownException();
    }
  }
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/core/ai/deepseek_llm_client_test.dart`
Expected: PASS（5 个）。

- [ ] **Step 6: 提交**

```bash
git add lib/core/ai/llm_client.dart lib/core/ai/deepseek_llm_client.dart test/core/ai/deepseek_llm_client_test.dart
git commit -m "feat: LlmClient + DeepSeekLlmClient (OpenAI-compatible) + tests"
```

---

## Task 3: 候选检索 + AiRecommendationRepository

**Files:**
- Create: `lib/data/ai/professor_candidate_source.dart`
- Create: `lib/data/ai/ai_recommendation_repository.dart`
- Test: `test/data/ai/ai_recommendation_repository_test.dart`

- [ ] **Step 1: 实现 `lib/data/ai/professor_candidate_source.dart`**

```dart
import '../../domain/entities/professor.dart';
import '../mock/mock_db.dart';

/// 候选检索接缝（RAG seam）。M1 返回全部导师；数据变大后可换关键词/向量实现。
abstract interface class ProfessorCandidateSource {
  List<Professor> candidatesFor(String prompt);
}

class MockDbCandidateSource implements ProfessorCandidateSource {
  MockDbCandidateSource(this._db);

  final MockDb _db;

  @override
  List<Professor> candidatesFor(String prompt) => _db.allProfessors;
}
```

- [ ] **Step 2: 写失败测试 `test/data/ai/ai_recommendation_repository_test.dart`**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_recommendation_repository.dart';
import 'package:scho_navi/data/ai/professor_candidate_source.dart';
import 'package:scho_navi/domain/entities/professor.dart';

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
}

class _FixedCandidates implements ProfessorCandidateSource {
  _FixedCandidates(this.pool);

  final List<Professor> pool;

  @override
  List<Professor> candidatesFor(String prompt) => pool;
}

const _p1 = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
  bio: '研究医学影像。',
  homepageUrl: 'https://example.edu.cn/zhangsan',
);

void main() {
  final candidates = _FixedCandidates(const [_p1]);

  test('解析为 RecommendationResult，事实字段回填自 fixture', () async {
    final json = jsonEncode({
      'queryUnderstanding': {
        'researchInterests': ['医学影像'],
        'preferredLocations': ['上海'],
        'preferredUniversities': <String>[],
        'degreeStage': '硕士',
        'uncertainties': <String>[],
      },
      'recommendations': [
        {
          'professorId': 'p_001',
          'matchLevel': 'high',
          'reason': '方向高度相关',
          'limitations': ['以学校官网为准'],
        },
      ],
      'followUpQuestions': ['偏理论还是应用？'],
    });
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(Success(json)),
      candidates: candidates,
    );
    final res = await repo.getRecommendations(prompt: '医学影像 上海 硕士');
    final data = (res as Success).data;
    expect(data.recommendations, hasLength(1));
    final r = data.recommendations.single;
    expect(r.professorId, 'p_001');
    expect(r.name, '张三'); // 回填
    expect(r.university, '上海交通大学'); // 回填
    expect(r.reason, '方向高度相关'); // 模型产出
    expect(data.queryUnderstanding.degreeStage, '硕士');
    expect(data.followUpQuestions, contains('偏理论还是应用？'));
  });

  test('使用 JSON 模式', () async {
    final fake = _FakeLlm(const Success('{"recommendations":[]}'));
    final repo = AiRecommendationRepository(llm: fake, candidates: candidates);
    await repo.getRecommendations(prompt: 'x');
    expect(fake.lastJsonMode, isTrue);
  });

  test('接地：丢弃候选外的 professorId', () async {
    final json = jsonEncode({
      'recommendations': [
        {
          'professorId': 'p_999',
          'matchLevel': 'high',
          'reason': '伪造',
          'limitations': <String>[],
        },
        {
          'professorId': 'p_001',
          'matchLevel': 'medium',
          'reason': '真',
          'limitations': <String>[],
        },
      ],
    });
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(Success(json)),
      candidates: candidates,
    );
    final data = (await repo.getRecommendations(prompt: 'x') as Success).data;
    expect(data.recommendations.map((r) => r.professorId).toList(), ['p_001']);
  });

  test('无相关导师 → 空列表 Success', () async {
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(const Success('{"recommendations":[]}')),
      candidates: candidates,
    );
    final res = await repo.getRecommendations(prompt: 'x');
    expect((res as Success).data.recommendations, isEmpty);
  });

  test('坏 JSON → Failure(ServerException)', () async {
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(const Success('not json')),
      candidates: candidates,
    );
    final res = await repo.getRecommendations(prompt: 'x');
    expect((res as Failure).error, isA<ServerException>());
  });

  test('LlmClient 失败透传', () async {
    final repo = AiRecommendationRepository(
      llm: _FakeLlm(const Failure(NetworkException())),
      candidates: candidates,
    );
    final res = await repo.getRecommendations(prompt: 'x');
    expect((res as Failure).error, isA<NetworkException>());
  });
}
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `flutter test test/data/ai/ai_recommendation_repository_test.dart`
Expected: FAIL（`ai_recommendation_repository.dart` 不存在）。

- [ ] **Step 4: 实现 `lib/data/ai/ai_recommendation_repository.dart`**

```dart
import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/match_level.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/query_understanding.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/repositories/recommendation_repository.dart';
import 'professor_candidate_source.dart';

/// 用大模型做"理解 + 排序 + 生成理由"，导师事实回填自候选 fixture（接地）。
class AiRecommendationRepository implements RecommendationRepository {
  AiRecommendationRepository({
    required LlmClient llm,
    required ProfessorCandidateSource candidates,
  }) : _llm = llm,
       _candidates = candidates;

  final LlmClient _llm;
  final ProfessorCandidateSource _candidates;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    String? sessionId,
  }) async {
    final pool = _candidates.candidatesFor(prompt);
    final res = await _llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', '【用户需求】$prompt\n【候选导师】${_encode(pool)}'),
      ],
      jsonMode: true,
      temperature: 0.3,
    );
    switch (res) {
      case Failure(:final error):
        return Failure(error);
      case Success(:final data):
        try {
          return Success(
            _parse(data, pool, sessionId ?? 's_${prompt.hashCode.toUnsigned(20)}'),
          );
        } catch (_) {
          return const Failure(ServerException());
        }
    }
  }

  String _encode(List<Professor> pool) => jsonEncode([
    for (final p in pool)
      {
        'id': p.id,
        'name': p.name,
        'university': p.university,
        'college': p.college,
        'title': p.title,
        'researchFields': p.researchFields,
        if (p.bio != null) 'bio': p.bio,
      },
  ]);

  RecommendationResult _parse(
    String content,
    List<Professor> pool,
    String sessionId,
  ) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final byId = {for (final p in pool) p.id: p};

    final qu = (json['queryUnderstanding'] as Map<String, dynamic>?) ?? const {};
    final degree = qu['degreeStage'] as String?;
    final understanding = QueryUnderstanding(
      researchInterests: _strs(qu['researchInterests']),
      preferredLocations: _strs(qu['preferredLocations']),
      preferredUniversities: _strs(qu['preferredUniversities']),
      uncertainties: _strs(qu['uncertainties']),
      degreeStage: (degree == null || degree.isEmpty || degree == 'null')
          ? null
          : degree,
    );

    final recs = <Recommendation>[];
    for (final item in (json['recommendations'] as List? ?? const [])) {
      final m = item as Map<String, dynamic>;
      final p = byId[m['professorId'] as String?];
      if (p == null) continue; // 接地：丢弃未知导师
      final reason = (m['reason'] as String?)?.trim();
      recs.add(
        Recommendation(
          professorId: p.id,
          name: p.name,
          university: p.university,
          college: p.college,
          title: p.title,
          researchFields: p.researchFields,
          homepageUrl: p.homepageUrl,
          matchLevel: _level(m['matchLevel'] as String?),
          reason: (reason == null || reason.isEmpty) ? '与你的需求相关。' : reason,
          limitations: _strs(m['limitations']),
        ),
      );
    }

    return RecommendationResult(
      sessionId: sessionId,
      queryUnderstanding: understanding,
      recommendations: recs,
      followUpQuestions: _strs(json['followUpQuestions']),
    );
  }

  List<String> _strs(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  MatchLevel _level(String? s) => switch (s) {
    'high' => MatchLevel.high,
    'low' => MatchLevel.low,
    _ => MatchLevel.medium,
  };

  static const String _systemPrompt = '''
你是 SchoNavi 的导师推荐助手。根据【用户需求】，从【候选导师】中筛选并排序最匹配的导师。
规则：
1. 只能推荐【候选导师】中出现的导师，用其 id 作为 professorId 引用；严禁编造导师、学校或事实。
2. 仅输出一个 JSON 对象，不要 Markdown、不要多余文字（json）。
3. reason：用中文 2-3 句具体说明匹配点（研究方向/学校/地区/阶段）。
4. limitations：只写诚实、通用的注意事项（如"招生信息以学校官网为准"），不要编造具体数字或事实。
5. matchLevel 取值 high、medium、low 之一。
6. queryUnderstanding：抽取研究兴趣/地区/学校/阶段；degreeStage 取"硕士""博士"或 null；uncertainties 写未明确处。地区可据学校常识推断。
7. followUpQuestions：1-3 个细化推荐的中文追问。
8. 候选中无相关导师时 recommendations 用空数组。
输出格式示例：
{"queryUnderstanding":{"researchInterests":["医学影像"],"preferredLocations":["上海"],"preferredUniversities":[],"degreeStage":"硕士","uncertainties":["未明确偏理论或应用"]},"recommendations":[{"professorId":"p_001","matchLevel":"high","reason":"……","limitations":["……"]}],"followUpQuestions":["……"]}
''';
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/data/ai/ai_recommendation_repository_test.dart`
Expected: PASS（6 个）。

- [ ] **Step 6: 提交**

```bash
git add lib/data/ai/professor_candidate_source.dart lib/data/ai/ai_recommendation_repository.dart test/data/ai/ai_recommendation_repository_test.dart
git commit -m "feat: AiRecommendationRepository (grounded structured output) + tests"
```

---

## Task 4: AiChatRepository（多轮 + 接地）

**Files:**
- Create: `lib/data/ai/ai_chat_repository.dart`
- Test: `test/data/ai/ai_chat_repository_test.dart`

- [ ] **Step 1: 写失败测试 `test/data/ai/ai_chat_repository_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';

class _RecordingLlm implements LlmClient {
  _RecordingLlm(this.reply);

  String reply;
  final List<List<LlmMessage>> calls = [];

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    calls.add(messages);
    return Success(reply);
  }
}

class _FailLlm implements LlmClient {
  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async => const Failure(ServerException());
}

void main() {
  test('回答透传 + sessionId 回显 + 无嵌入卡片', () async {
    final repo = AiChatRepository(llm: _RecordingLlm('你好'), db: MockDb());
    final res = await repo.sendMessage(sessionId: 's1', message: '在吗');
    final data = (res as Success<ChatResult>).data;
    expect(data.answer, '你好');
    expect(data.sessionId, 's1');
    expect(data.relatedRecommendations, isEmpty);
  });

  test('多轮：第二次调用包含上一轮历史', () async {
    final llm = _RecordingLlm('A');
    final repo = AiChatRepository(llm: llm, db: MockDb());
    await repo.sendMessage(sessionId: 's1', message: '问题一');
    llm.reply = 'B';
    await repo.sendMessage(sessionId: 's1', message: '问题二');
    final contents = llm.calls.last.map((m) => m.content).toList();
    expect(contents, containsAll(['问题一', 'A', '问题二']));
  });

  test('professorId 注入导师上下文到 system', () async {
    final llm = _RecordingLlm('ok');
    final repo = AiChatRepository(llm: llm, db: MockDb());
    await repo.sendMessage(
      sessionId: 's1',
      message: '为什么推荐他',
      professorId: 'p_001',
    );
    final system = llm.calls.last.first;
    expect(system.role, 'system');
    expect(system.content, contains('张三'));
  });

  test('regenerate：重复末条 user 不重复追加', () async {
    final llm = _RecordingLlm('A1');
    final repo = AiChatRepository(llm: llm, db: MockDb());
    await repo.sendMessage(sessionId: 's1', message: '同一个问题');
    llm.reply = 'A2';
    await repo.sendMessage(sessionId: 's1', message: '同一个问题');
    final userCount = llm.calls.last
        .where((m) => m.role == 'user' && m.content == '同一个问题')
        .length;
    expect(userCount, 1);
  });

  test('失败透传', () async {
    final repo = AiChatRepository(llm: _FailLlm(), db: MockDb());
    final res = await repo.sendMessage(sessionId: 's1', message: 'x');
    expect((res as Failure).error, isA<ServerException>());
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `flutter test test/data/ai/ai_chat_repository_test.dart`
Expected: FAIL（`ai_chat_repository.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/data/ai/ai_chat_repository.dart`**

```dart
import '../../core/ai/llm_client.dart';
import '../../core/result/result.dart';
import '../../domain/entities/chat_result.dart';
import '../../domain/repositories/chat_repository.dart';
import '../mock/mock_db.dart';

/// 用大模型做多轮答疑。仓库按 sessionId 自持 LLM 上下文（presentation 零改动）。
/// professorId 存在时把该导师注入 system 接地。M1 对话只返回文本，不嵌卡片。
class AiChatRepository implements ChatRepository {
  AiChatRepository({required LlmClient llm, required MockDb db})
    : _llm = llm,
      _db = db;

  final LlmClient _llm;
  final MockDb _db;
  final Map<String, List<LlmMessage>> _history = {};

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async {
    final history = _history.putIfAbsent(sessionId, () => []);

    // regenerate：紧接重复同一条 user（其后仅一条 assistant）→ 移除该 assistant 重发。
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

    final res = await _llm.complete(
      messages: [LlmMessage('system', _systemPrompt(professorId)), ...history],
    );
    switch (res) {
      case Failure(:final error):
        return Failure(error);
      case Success(:final data):
        history.add(LlmMessage('assistant', data));
        return Success(
          ChatResult(
            sessionId: sessionId,
            answer: data,
            relatedRecommendations: const [],
          ),
        );
    }
  }

  String _systemPrompt(String? professorId) {
    const base = '''
你是 SchoNavi 的导师咨询助手，帮助学生理解推荐结果、解答关于导师与升学的追问。
规则：
1. 基于（若有）【上下文导师】与对话历史回答；事实以公开资料为准，不确定就说明，不要编造具体数据、联系方式或录取结果。
2. 中文回答，可用 Markdown；简洁、友好、给可执行建议。
3. 涉及"是否适合/能否考上/录取概率"等不确定问题，给方法与建议，不打包票。''';
    if (professorId == null) return base;
    final p = _db.getProfessor(professorId);
    if (p == null) return base;
    return '$base\n【上下文导师】${p.name}（${p.university} ${p.college} ${p.title}），'
        '研究方向：${p.researchFields.join('、')}。${p.bio ?? ''}';
  }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/data/ai/ai_chat_repository_test.dart`
Expected: PASS（5 个）。

- [ ] **Step 5: 提交**

```bash
git add lib/data/ai/ai_chat_repository.dart test/data/ai/ai_chat_repository_test.dart
git commit -m "feat: AiChatRepository (multi-turn + grounding + regenerate) + tests"
```

---

## Task 5: DI 接线（`ai` 分支）

**Files:**
- Modify: `lib/core/di/providers.dart`
- Test: `test/core/di/ai_providers_test.dart`

- [ ] **Step 1: 在 `lib/core/di/providers.dart` 追加 import**

在文件顶部 import 区追加：
```dart
import 'package:dio/dio.dart';

import '../../data/ai/ai_chat_repository.dart';
import '../../data/ai/ai_recommendation_repository.dart';
import '../../data/ai/professor_candidate_source.dart';
import '../ai/deepseek_llm_client.dart';
import '../ai/llm_client.dart';
```

- [ ] **Step 2: 在 `mockDbProvider` 之后追加 AI 基础 provider**

```dart

final dioProvider = Provider<Dio>((ref) => Dio());

final llmClientProvider = Provider<LlmClient>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return DeepSeekLlmClient(
    dio: ref.watch(dioProvider),
    apiKey: cfg.llm.apiKey,
    baseUrl: cfg.llm.baseUrl,
    model: cfg.llm.model,
  );
});

final professorCandidateSourceProvider = Provider<ProfessorCandidateSource>(
  (ref) => MockDbCandidateSource(ref.watch(mockDbProvider)),
);
```

- [ ] **Step 3: 给三个仓储 provider 的 switch 加 `ai` 分支**

把 `recommendationRepositoryProvider` 整体替换为：
```dart
final recommendationRepositoryProvider = Provider<RecommendationRepository>((
  ref,
) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
      return MockRecommendationRepository(ref.watch(mockDbProvider));
    case DataSource.ai:
      return AiRecommendationRepository(
        llm: ref.watch(llmClientProvider),
        candidates: ref.watch(professorCandidateSourceProvider),
      );
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});
```

把 `professorRepositoryProvider` 整体替换为（详情仍走 fixture，无需生成）：
```dart
final professorRepositoryProvider = Provider<ProfessorRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
    case DataSource.ai:
      return MockProfessorRepository(ref.watch(mockDbProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});
```

把 `chatRepositoryProvider` 整体替换为：
```dart
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
      return MockChatRepository(ref.watch(mockDbProvider));
    case DataSource.ai:
      return AiChatRepository(
        llm: ref.watch(llmClientProvider),
        db: ref.watch(mockDbProvider),
      );
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});
```

- [ ] **Step 4: 写接线测试 `test/core/di/ai_providers_test.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/deepseek_llm_client.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/ai/ai_recommendation_repository.dart';

void main() {
  test('dataSource=ai 接 AI 实现 + DeepSeekLlmClient', () {
    final c = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(
      c.read(recommendationRepositoryProvider),
      isA<AiRecommendationRepository>(),
    );
    expect(c.read(chatRepositoryProvider), isA<AiChatRepository>());
    expect(c.read(llmClientProvider), isA<DeepSeekLlmClient>());
  });

  test('默认（mock）不受影响', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(recommendationRepositoryProvider), isNotNull);
    expect(c.read(chatRepositoryProvider), isNotNull);
  });
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/core/di/ai_providers_test.dart`
Expected: PASS（2 个）。

- [ ] **Step 6: 提交**

```bash
git add lib/core/di/providers.dart test/core/di/ai_providers_test.dart
git commit -m "feat: wire ai data source for recommendation/chat (mock fallback) + tests"
```

---

## Task 6: 收尾全量验证

**Files:** 无（仅验证）

- [ ] **Step 1: 全量分析与测试**

Run: `flutter analyze && flutter test`
Expected: analyze 无 error；全部 PASS——既有 ~100 + 本增量（config 2、client 5、推荐 6、对话 5、DI 2 = 20）。

- [ ] **Step 2: 确认工作区干净**

Run: `git status --short`
Expected: 干净（除可能的 `.agents/` 等非本任务文件）。

- [ ] **Step 3: 人工冒烟（需真实 key）**

Run（替换为真实 key）：
```bash
flutter run --dart-define=LLM_API_KEY=sk-你的key
```
手动核对：
- 首页输入「医学影像 上海 硕士」→ 出现真实大模型返回的结构化推荐；导师均为 fixture 内真实存在者，理由为模型生成（每次措辞可不同）。
- 进「继续追问」→ 问「为什么推荐他」「适合硕士申请吗」→ 得到合理多轮回答（Markdown 渲染）。
- 详情页「继续追问」→ 回答含该导师姓名（接地生效）。
- 关 key 直接 `flutter run` → 回到 mock 行为（演示安全）。
- 断网或填错 key → 友好错误 + 重试。

> 本增量解锁后续：M2 真·流式（`streamReply`/SSE）、M3 套磁邮件、M4 多导师对比、M5 背景匹配、M6 打磨与作品说明。

---

## 自查（Self-Review）记录

- **Spec 覆盖**（M1 spec §4–§12）：配置/key→Task 1；`LlmClient`/`DeepSeekLlmClient`+错误映射→Task 2；候选检索+接地推荐→Task 3；多轮+接地对话+regenerate→Task 4；DI 切换→Task 5；全量验收→Task 6。
- **占位扫描**：无 TBD/TODO；每个 code step 给出完整可编译代码 + 可运行命令与期望。
- **类型一致性**：
  - `LlmClient.complete({required List<LlmMessage> messages, bool jsonMode, double temperature}) → Future<Result<String>>` 在接口（T2）、`DeepSeekLlmClient`（T2）、各测试假实现（T2/T3/T4）、两仓储调用（T3/T4）签名一致。
  - `LlmMessage(String role, String content)` 位置参数，全文件一致。
  - `AiRecommendationRepository({required LlmClient llm, required ProfessorCandidateSource candidates})`、`AiChatRepository({required LlmClient llm, required MockDb db})` 在实现、测试、DI（T5）一致。
  - 仍实现既有 `RecommendationRepository.getRecommendations({required String prompt, String? sessionId})` 与 `ChatRepository.sendMessage({required String sessionId, required String message, String? professorId})`，签名未改（presentation 零改动）。
  - `AppConfig.resolve({required String apiKey, String baseUrl, String model, String appVersion})` 在 config（T1）、main（T1）、DI 测试（T5）一致；`LlmConfig{apiKey,baseUrl,model,isConfigured}` 一致。
  - `DataSource{mock,ai,http}` 三分支在三个仓储 provider 全覆盖（T5）。
- **不回归**：默认 `mock`；仅追加 config 字段、ai provider 与分支，不删改既有 mock/presentation/domain。Task 6 跑全量回归。
- **dio API 核实**：`HttpClientAdapter.fetch(RequestOptions, Stream<Uint8List>?, Future<void>?)`、`ResponseBody.fromString(text, code, {headers})`、`DioException.type`/`response?.statusCode`、默认 `validateStatus` 对非 2xx 抛 `DioException`（故 500 经 `fromStatusCode` → `ServerException`）。
