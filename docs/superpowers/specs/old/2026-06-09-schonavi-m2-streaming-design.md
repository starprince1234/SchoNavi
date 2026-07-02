# SchoNavi M2 · 真·流式对话（SSE 逐字 + 中断）设计

- 版本：v1（2026-06-09，首稿——M2 实现前可再细化）
- 关系：引用主设计 §5/§6.4（`streamReply`/流式）与 `2026-06-09-schonavi-m1-llm-core-design.md`（`LlmClient`/`AiChatRepository`）。
- 前置：M1 已落地（真实大模型对话非流式）。

---

## 1. 目标与非目标

**目标**：把对话回答从"整段返回"升级为**逐字流式输出**（SSE），并支持**中途停止生成**，让体验"像真 AI 产品"。复用 M1 的接地与多轮上下文。

**非目标**：对话内嵌推荐卡片（function-calling，留后续）；推荐结果页的流式（推荐是结构化 JSON，不适合逐字展示，仍非流式）。

---

## 2. 架构与改动

延续 M1 分层。核心是给 `LlmClient`、`ChatRepository` 各加一个**流式方法**，presentation 的 `ChatNotifier` 改为订阅流。

### 2.1 `core/ai/llm_client.dart`（扩接口）

```dart
abstract interface class LlmClient {
  Future<Result<String>> complete({ /* M1 不变 */ });

  /// 流式补全：逐段 emit 文本增量（delta）。失败 → Stream error（AppException）。完成 → 正常关闭。
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  });
}
```

`DeepSeekLlmClient.stream`：dio `ResponseType.stream` + body `stream:true`；按 SSE 逐行解析 `data: {...}`，取 `choices[0].delta.content` 累积 emit；遇 `data: [DONE]` 结束；HTTP/网络错误 → `addError(AppException)`。

### 2.2 `domain/repositories/chat_repository.dart`（扩接口）

```dart
abstract interface class ChatRepository {
  Future<Result<ChatResult>> sendMessage({ /* M1 不变，mock 仍用 */ });

  /// 流式回答：emit 文本增量；完成时把整段并入会话历史。
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  });
}
```

- `AiChatRepository.streamReply`：同 M1 组 `[system(接地), ...history, user]` → `llm.stream(...)`；用一个累加器收集全文，流结束后把 `assistant` 全文写入 `_history`（保证下一轮上下文完整）；regenerate 语义同 M1。
- `MockChatRepository.streamReply`：把 M1/现有意图回答整段**切片 + 定时器逐段 emit**（主设计 §6.4），离线也有流式观感。

### 2.3 `domain/entities/chat_message.dart`（加状态）

`ChatMessageStatus` 增 `streaming`（chat plan 当初按 YAGNI 推迟，现在启用）。

### 2.4 presentation：`features/chat/providers/chat_provider.dart`

- `send()`：追加用户消息 + 一条 `streaming` 空助手消息 → 订阅 `streamReply`：每个 delta 追加到该助手消息 `content`（状态 `streaming`）→ 流完成置 `done` → 流出错置 `error`（文案取 `AppException.message`）。
- 新增 `stop()`：取消当前订阅，把进行中的助手消息从 `streaming` 收尾为 `done`（保留已生成部分）。
- `isResponding` 在 streaming 期间为真；保存当前 `StreamSubscription` 以便 `stop()`/`dispose` 取消。

### 2.5 presentation：`features/chat/`（UI）

- `ChatMessageBubble`：`streaming` 状态渲染已到达文本（`GptMarkdown`）+ 轻量"生成中"光标/指示；不再只显示"正在思考…"（思考态仅在首个 delta 到达前短暂出现）。
- `ChatPage`：响应中时，输入栏发送键变为**「停止生成」**（调 `stop()`）；停止后恢复发送。「重新生成」逻辑改为走 `streamReply`。

---

## 3. 错误与兜底

- 流中途出错 → 该助手气泡转 `error` + 文案 + 可「重新生成」。
- `stop()` 是用户主动中断，不算错误，保留已生成内容。
- 仍保留 `mock` 离线流式（演示无网可切 `mock`）。

---

## 4. 测试策略（TDD）

| 测试 | 覆盖 |
|---|---|
| `deepseek_llm_client_stream_test` | 假 adapter 返回多段 SSE（含 `[DONE]`）→ `stream` 逐段 emit 正确 delta；HTTP 错误 → stream error 映射 AppException |
| `ai_chat_repository_stream_test` | 假 `LlmClient.stream` → `streamReply` 透传增量；结束后历史含整段；下一轮含上轮 |
| `mock_chat_repository_stream_test` | `streamReply` 逐段 emit、最终拼回完整答案 |
| `chat_provider_stream_test` | delta 累加进助手消息；完成→done；出错→error；`stop()` 取消并收尾 done |
| `chat_page_stream_test`（widget） | 响应中显示「停止生成」，点击后停止；流式文本上屏 |

> 既有对话测试（M0/M1 非流式 mock）保持：`mock` 的 `sendMessage` 不删，新增 `streamReply`。

---

## 5. 偏差/开放问题

1. **流式从 V1.0 提前到 M2**（主设计 §6.4 原列 V1.0）。
2. **`ChatChunk` 简化为 `Stream<String>`**（纯文本增量）；主设计提到的 `Stream<ChatChunk>` 中"嵌入卡片/结构化分片"留到 function-calling 阶段再引入。
3. **会话历史仍存仓库内部**（M1 偏差延续）；流式下尤其要确保"完成后才并入历史"，避免中断的半句污染上下文——`stop()` 时仍把已生成部分写入历史（用户可见即上下文）。
