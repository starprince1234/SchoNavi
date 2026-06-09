# SchoNavi M1 · 核心闭环转真（真实大模型接入）设计

- 版本：v1（2026-06-09）
- 关系：本文是 **AIGC 能力改造**的第一份子项目 spec，引用 `2026-06-07-schonavi-master-design.md`（架构/模型/契约）与评分标准（见项目记忆 `schonavi-aigc-competition-rubric`）。不重复主设计内容。
- 背景：当前 App 所有"智能"都是 `String.contains()` 关键词匹配，**零真实大模型**；而比赛评分明确含「大模型应用能力」。本改造把核心链路从假智能换成真实 DeepSeek 生成。

---

## 1. 目标与非目标

**目标（M1）**：在 **presentation / domain 零改动**的前提下，把现有「首页输入 → 推荐结果 → 对话追问」链路的后端实现，从关键词 Mock 换成**真实大模型（DeepSeek）生成**，并以**候选导师接地（grounding）**避免编造。Mock 仓储保留为可切换的离线兜底。

**非目标（留待后续里程碑）**：

- 流式逐字输出 / 中断（M2）。
- 套磁邮件生成、多导师对比、背景匹配分析（M3–M5，新功能各自 spec）。
- 向量检索 / 大规模导师库（数据仍 12 位；候选检索此期返回全量，见 §5.3）。
- 真实后端服务 / key 代理（V1.0；M1 客户端直连，见 §9）。
- 对话中嵌入推荐卡片（M1 对话只返回文本；卡片留 M2 用 function-calling 做）。

---

## 2. 整体 AIGC 路线（仅记录，后续各自立 spec）

| 里程碑 | 内容 |
|---|---|
| **M1** | 核心闭环转真：`LlmClient` + 推荐/对话接真模型（本文） |
| M2 | 真·流式对话（SSE 逐字 + 中断） |
| M3 | 套磁邮件生成 |
| M4 | 多导师对比报告 |
| M5 | 背景匹配分析 |
| M6 | 打磨 + AI 能力可视化 + APK + 作品说明 |

每个里程碑独立 spec → plan → 实现。本文只交付 M1。

---

## 3. 架构与接地原则

延续主设计三层 + 横切 core。**新增**一个 `core/ai/`（大模型客户端，provider 无关）与 `data/ai/`（实现已有 domain 仓储接口的真实现）。DI 把 `DataSource` 扩成 `mock | ai`，按配置返回 Mock 或 AI 实现；presentation 仍只 `ref.watch(...RepositoryProvider)`，不感知实现。

```text
presentation(features/*)  →  domain(已有接口/实体, 不变)  ←  data/ai (AI 真实现, 新增)
                                                          ←  data/mock (离线兜底, 不变)
                                   core/ai (LlmClient, 新增) ┘
```

**接地原则（核心技术点）**：导师**事实**数据仍来自 `MockDb` fixtures（当知识库）。每次请求把**候选导师**作为 context 喂给模型，模型只负责**理解 / 排序 / 生成理由 / 多轮答疑**，**不负责编造导师**。解析结果时，导师的姓名/学校/院系/方向/主页一律**回填自 fixture**（可信源），模型只贡献 `matchLevel / reason / limitations`。未在候选中出现的 `professorId` 一律丢弃。这套"检索候选 + 接地生成 + 结构化输出"是 RAG-lite，也是「大模型应用能力」的核心展示点。

---

## 4. 配置与 key（`core/config/app_config.dart` 改动）

```dart
enum DataSource { mock, ai, http } // 新增 ai；http 仍留 V1.0 真实后端

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

  /// 纯函数，便于单测：有 key → ai，否则 → mock。
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
```

key 经 `--dart-define` 注入，**不硬编码、不进仓库**：

```dart
// main.dart 内构造（dart-define 读取必须是 const 默认值形式）
const _apiKey = String.fromEnvironment('LLM_API_KEY');
const _baseUrl = String.fromEnvironment('LLM_BASE_URL', defaultValue: 'https://api.deepseek.com');
const _model = String.fromEnvironment('LLM_MODEL', defaultValue: 'deepseek-chat');
```

`main()` 追加 `appConfigProvider.overrideWithValue(AppConfig.resolve(apiKey: _apiKey, baseUrl: _baseUrl, model: _model))`。

- 无 key（如 `flutter run` / `flutter test`）：`dataSource = mock`，行为与现状完全一致，**既有 ~100 测试不受影响**。
- 有 key（`flutter run --dart-define=LLM_API_KEY=sk-xxx`）：`dataSource = ai`，走真实 DeepSeek。

---

## 5. 组件设计

### 5.1 `core/ai/llm_client.dart` — provider 无关大模型客户端

```dart
class LlmMessage {
  const LlmMessage(this.role, this.content); // role: 'system' | 'user' | 'assistant'
  final String role;
  final String content;
}

abstract interface class LlmClient {
  /// 非流式补全。返回 Result：Success(模型文本) | Failure(AppException)。
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  });
}
```

`core/ai/deepseek_llm_client.dart`：用 `dio` 实现 OpenAI 兼容 `POST {baseUrl}/chat/completions`：

- Header：`Authorization: Bearer <apiKey>`、`Content-Type: application/json`。
- Body：`{model, messages:[{role,content}], temperature, stream:false, response_format: jsonMode ? {"type":"json_object"} : null}`。
- 成功：取 `choices[0].message.content`（String）→ `Success`。
- **错误映射到现有 `AppException`**（复用 `AppException.fromStatusCode`）：
  - `DioException` 有响应码 → `fromStatusCode(code)`；
  - 连接超时/接收超时 → `TimeoutException`；
  - 无网络/连接失败 → `NetworkException`；
  - 响应 `choices` 为空或 content 为空 → `ServerException`；
  - 其它 → `UnknownException`。
- 构造：`DeepSeekLlmClient({required Dio dio, required String apiKey, required String baseUrl, required String model})`。

> jsonMode 时按 DeepSeek 要求：prompt 中必须出现 "json" 字样并给出输出样例（在 §7 system prompt 里满足）。

### 5.2 `data/ai/professor_candidate_source.dart` — 候选检索接缝（RAG seam）

```dart
abstract interface class ProfessorCandidateSource {
  /// 为给定需求返回候选导师（M1：返回全部 12 位）。
  List<Professor> candidatesFor(String prompt);
}

class MockDbCandidateSource implements ProfessorCandidateSource {
  MockDbCandidateSource(this._db);
  final MockDb _db;
  @override
  List<Professor> candidatesFor(String prompt) => _db.allProfessors; // 数据小，全量
}
```

> 数据变大后只需换成关键词/向量实现（如 `VectorCandidateSource`），`AiRecommendationRepository` 不变。这是"数据越丰富越好 + prompt 不超载"的接缝。

### 5.3 `data/ai/ai_recommendation_repository.dart` — 实现 `RecommendationRepository`

流程：`candidatesFor(prompt)` → 紧凑序列化候选 → 组 system+user 消息（jsonMode=true）→ `llmClient.complete` → 解析 JSON → **接地回填** → `RecommendationResult`。

- 候选紧凑序列化（只取模型需要的字段，省 token）：每位 `{id, name, university, college, title, researchFields, bio}`。**不含地区字段**（`Professor` 无该字段）；地区由模型据学校常识推断（§7 prompt 说明），M1 够用，后续可显式加。
- 解析与接地：
  - 逐条 `recommendations[i]`：用 `professorId` 在候选里查 `Professor`；查不到 → **丢弃**。
  - 命中则构造 `Recommendation`：`name/university/college/title/researchFields/homepageUrl` **取自 fixture**；`matchLevel`（解析 `high|medium|low`，非法 → `medium`）、`reason`、`limitations` 取自模型。`matchScore = null`（UI 默认不显示分数）。
  - `queryUnderstanding` 从 JSON 映射（`degreeStage` 的 `"null"`/`""` → `null`）。
  - `followUpQuestions` 取 JSON（缺省 → 空列表）。
  - `sessionId`：用入参 `sessionId ?? 's_${prompt.hashCode.toUnsigned(20)}'`（沿用 mock 习惯）。
  - 候选无相关 / 全被丢弃 → 返回 `Success`，`recommendations` 为空（合法"无结果"态，由现有 `EmptyView` 呈现），不报错。
- 失败：`complete` 返回 `Failure` → 直接透传；JSON 解析失败 / 缺关键字段 → `Failure(ServerException())`（M1 复用现有异常集，不扩 taxonomy）。
- 构造：`AiRecommendationRepository({required LlmClient llm, required ProfessorCandidateSource candidates})`。

### 5.4 `data/ai/ai_chat_repository.dart` — 实现 `ChatRepository`

- **多轮**：仓库内部 `Map<String, List<LlmMessage>> _history`（按 `sessionId`）。`sendMessage`：取该 session 历史 → 追加 user 消息 → 组 `[system, ...history, user]` → `complete`（jsonMode=false）→ 追加 assistant 消息入历史 → 返回 `ChatResult(sessionId, answer, relatedRecommendations: const [])`。
  - 零改 presentation：`ChatNotifier` 仍维护可视消息列表，仓库另存 LLM 上下文（职责分离）。
- **接地**：`professorId != null` 时，用候选源/`MockDb.getProfessor(id)` 取该导师，注入 system 末尾的【上下文导师】块（§7）。
- **regenerate 处理**：`ChatNotifier.regenerate()` 会用同一条用户文本再次 `sendMessage`。约定：**若新 user 消息与历史中最后一条 user 消息相同且其后只有一条 assistant 消息，视为重新生成**——移除那条 assistant 历史后重发，不重复追加 user，保持上下文干净。
- 失败：`complete` 的 `Failure` 透传（`ChatNotifier` 已把 `Failure` 渲染为 error 气泡）。
- 构造：`AiChatRepository({required LlmClient llm, required MockDb db})`（取导师上下文用）。

### 5.5 DI 接线（`core/di/providers.dart` 改动）

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

三个仓储 provider 的 `switch` 各加 `DataSource.ai` 分支：

```dart
// recommendationRepositoryProvider
case DataSource.ai:
  return AiRecommendationRepository(
    llm: ref.watch(llmClientProvider),
    candidates: ref.watch(professorCandidateSourceProvider),
  );
// chatRepositoryProvider
case DataSource.ai:
  return AiChatRepository(llm: ref.watch(llmClientProvider), db: ref.watch(mockDbProvider));
// professorRepositoryProvider
case DataSource.ai:
  return MockProfessorRepository(ref.watch(mockDbProvider)); // 详情仍走 fixture，无需生成
```

`http` 分支保持 `throw UnimplementedError(...)`（V1.0）。

### 5.6 `pubspec.yaml`

`flutter pub add dio`（解析与 Dart 3.12 兼容的最新 stable，锁定版本）。

---

## 6. 数据流

**推荐**：首页提交 → `recommendationProvider(prompt)` → `AiRecommendationRepository.getRecommendations` → 候选检索 + `LlmClient.complete(jsonMode)` → 解析+接地 → `RecommendationResult` → 现有结果页/`QueryUnderstandingCard`/`ProfessorCard`。失败 → `Failure` → 现有 `ErrorView`（重试）。

**对话**：结果页/详情页「继续追问」→ `/chat` → `ChatNotifier.send` → `AiChatRepository.sendMessage`（含历史+导师接地）→ `LlmClient.complete` → `ChatResult` → 现有 `ChatMessageBubble`（Markdown）。

---

## 7. Prompt 设计

**推荐 system prompt（jsonMode）**：

```text
你是 SchoNavi 的导师推荐助手。根据【用户需求】，从【候选导师】中筛选并排序最匹配的导师。
规则：
1. 只能推荐【候选导师】中出现的导师，用其 professorId 引用；严禁编造导师、学校或事实。
2. 仅输出一个 JSON 对象，不要 Markdown、不要多余文字（json）。
3. reason：用中文 2-3 句具体说明匹配点（研究方向/学校/地区/阶段）。
4. limitations：只写诚实、通用的注意事项（如"招生信息以学校官网为准""建议邮件确认名额"），不要编造具体数字或事实。
5. matchLevel ∈ {high, medium, low}，按契合度给出。
6. queryUnderstanding：抽取研究兴趣/地区/学校/阶段；degreeStage ∈ {硕士, 博士} 或 null；uncertainties 写用户未明确处。地区可据学校常识推断。
7. followUpQuestions：1-3 个有助于细化推荐的中文追问。
8. 候选中无相关导师时 recommendations 用空数组，并在 followUpQuestions 引导放宽条件。
输出格式示例：
{"queryUnderstanding":{"researchInterests":["医学影像"],"preferredLocations":["上海"],"preferredUniversities":[],"degreeStage":"硕士","uncertainties":["未明确偏理论或应用"]},"recommendations":[{"professorId":"p_001","matchLevel":"high","reason":"……","limitations":["……"]}],"followUpQuestions":["……"]}
```

user：`【用户需求】<prompt>\n【候选导师】<candidates json>`

**对话 system prompt**：

```text
你是 SchoNavi 的导师咨询助手，帮助学生理解推荐结果、解答关于导师与升学的追问。
规则：
1. 基于（若有）【上下文导师】与对话历史回答；事实以公开资料为准，不确定就说明，不要编造具体数据、联系方式或录取结果。
2. 中文回答，可用 Markdown（加粗/列表）；简洁、友好、给可执行建议。
3. 涉及"是否适合/能否考上/录取概率"等不确定问题，给方法与建议，不打包票。
（professorId 存在时追加）
【上下文导师】{name, university, college, title, researchFields, bio}
```

messages：`[system, ...history, LlmMessage('user', message)]`。

---

## 8. 错误处理与兜底策略

- `ai` 数据源调用失败 → 走现有 `Result.Failure` + `AppException` + `ErrorView` 重试链路，**不自动回退 mock**（避免"是否真 AI"含糊）。
- `mock` 数据源作为**可手动切换**的离线演示档（演示无网时把 `dataSource` 切回 `mock` 即可，或不传 key 启动）。
- JSON 解析失败/格式异常 → `ServerException`（"服务异常，请稍后重试"），用户可重试。

---

## 9. 安全与 key

- M1 客户端直连大模型，key 经 `--dart-define` 注入、不入库、不硬编码。**比赛 demo 阶段可接受**。
- 上线前（V1.0）加轻量代理后端转发持有 key，对应 `DataSource.http` 实现；本期不做。
- 日志不打印 key 与完整 prompt 中的敏感字段。

---

## 10. 测试策略（TDD，沿用现有约定）

**全部不打真网络**：用假 `LlmClient` 注入固定返回；客户端自身用假 `dio` adapter 测。

| 测试文件 | 覆盖 |
|---|---|
| `test/core/config/app_config_test.dart` | `AppConfig.resolve`：无 key→mock、有 key→ai；baseUrl/model 透传 |
| `test/core/ai/deepseek_llm_client_test.dart` | 用注入的假 `HttpClientAdapter`：请求体含 model/messages/response_format；成功取 content；状态码/超时/网络/空 choices → 对应 `AppException` |
| `test/data/ai/ai_recommendation_repository_test.dart` | 假 LlmClient 返回固定 JSON → 解析成 `RecommendationResult`；**接地**（未知 professorId 被丢弃，字段回填自 fixture）；无相关→空列表 Success；坏 JSON→`Failure(ServerException)` |
| `test/data/ai/ai_chat_repository_test.dart` | 假 LlmClient（记录收到的 messages）→ 回答透传；**多轮**（第二次调用含上一轮历史）；professorId→system 含导师上下文；regenerate 重复末条 user 时替换而非重复 |
| `test/core/di/ai_providers_test.dart` | `dataSource=ai` 时三仓储为 AI/Mock 对应实现；`llmClientProvider` 为 `DeepSeekLlmClient` |

> 既有 ~100 个测试默认 `dataSource=mock`，**保持全绿**。新增约 5 个测试文件、~18 个用例。

---

## 11. 文件结构

| 文件 | 职责 |
|---|---|
| `lib/core/config/app_config.dart` | **改**：`DataSource.ai`、`LlmConfig`、`AppConfig.resolve` |
| `lib/core/ai/llm_client.dart` | 新：`LlmMessage` + `LlmClient` 接口 |
| `lib/core/ai/deepseek_llm_client.dart` | 新：dio 实现 + 错误映射 |
| `lib/data/ai/professor_candidate_source.dart` | 新：候选检索接缝 + `MockDbCandidateSource` |
| `lib/data/ai/ai_recommendation_repository.dart` | 新：接地结构化推荐 |
| `lib/data/ai/ai_chat_repository.dart` | 新：多轮 + 接地对话 |
| `lib/core/di/providers.dart` | **改**：`dioProvider`/`llmClientProvider`/`professorCandidateSourceProvider` + 三仓储 `ai` 分支 |
| `lib/main.dart` | **改**：override `appConfigProvider`（读 dart-define） |
| `pubspec.yaml` | **改**：加 `dio` |
| `test/...` | 5 个新测试文件（见 §10） |

> 不改 domain 实体/接口、不改 presentation、不改既有 mock 文件（仅 `MockDbCandidateSource` 复用 `MockDb.allProfessors`/`getProfessor`）。

---

## 12. 验收标准

1. `flutter analyze` 无 error。
2. `flutter test` 全绿：既有 ~100 + 新增 ~18。
3. 不带 key 跑 `flutter run` → 仍是 mock 行为（演示安全）。
4. 带 `--dart-define=LLM_API_KEY=...` 跑：首页输入真实需求 → 真模型返回结构化推荐（导师为 fixture 内真实存在者，理由由模型生成）；进对话 → 多轮问答；问"为什么推荐 X" / "适合硕士吗"得到合理生成回答；断网/坏 key → 友好错误 + 重试。

---

## 13. 与主设计的偏差（记录）

1. **新增 `DataSource.ai`**：主设计只列 `mock|http`。`ai` = 客户端直连大模型；`http` 仍留给 V1.0 真实后端。
2. **`streamReply` 仍不实现**（主设计 §6.4 列 V1.0；此处 M2 提前做）。M1 用非流式 `complete`。
3. **对话上下文存仓库内部**：为零改 `ChatRepository` 接口与 presentation，`AiChatRepository` 按 sessionId 自持历史（mock 思路一致）。M2 接流式时可重新评估是否把历史显式经接口传入。
4. **地区不进候选序列化**：`Professor` 实体无地区字段，由模型据学校常识推断；后续 enrich 数据时再显式加。
5. **`matchScore = null`**：模型不产出分数，UI 本就默认不显示分数（`featureFlags.showMatchScore=false`）。

---

## 14. 自查（Self-Review）记录

- **占位扫描**：无 TBD/TODO；契约（签名 / JSON / prompt）均给全。
- **类型一致性**：`LlmClient.complete(...) → Future<Result<String>>` 在接口、`DeepSeekLlmClient`、假实现、两仓储一致；仓储仍实现既有 `RecommendationRepository`/`ChatRepository`（签名不变）；`RecommendationResult`/`QueryUnderstanding`/`Recommendation`/`ChatResult` 字段对齐 §4 实体源码。
- **不回归**：默认 `mock`，既有测试与离线演示不受影响；仅追加 provider 分支与 config 字段，不删改既有逻辑。
- **范围**：聚焦"现有两条链路转真 + 接地 + 配置/DI/测试"，单份 plan 可实现；新功能与流式明确切出。
- **歧义**：候选规模（全量）、失败兜底（不自动回退）、默认数据源（按 key）、regenerate 语义均已显式定义。
