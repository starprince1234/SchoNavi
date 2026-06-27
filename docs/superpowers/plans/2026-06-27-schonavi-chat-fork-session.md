# Fork 式追问会话 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「继续追问」改造成主 session 的 copy-on-fork 分支——fork 时复制主对话全部历史、绑定所选教授，追问页顶部常驻教授锚点条，fork 内不再产卡而以友好双选项引导回首页，追问内容本地持久化并可在历史页折叠展开恢复。

**Architecture:** fork 作为显式领域概念：`ChatRepository` 新增 `forkSession`/`loadHistory`/`listForks`/`deleteFork` 四个纯抽象方法（面向生产，可对接 REST 端点）；mock 数据源下用新增 `ChatHistoryStore` 抽象 + `LocalChatHistoryStore`（SharedPreferences/JSON）持久化。`ChatNotifier` 新增 `startFork`/`resume` 启动路径，fork 模式拦截再产卡改为重路由双选项。详情页「继续追问」FAB 改 fork，首页卡片点击透传主 sessionId，推荐页 FAB 移除。历史页 `_HistoryTile` 改有状态折叠展开（v3：线条加号旋转 + 子项头像姓名学校）。

**Tech Stack:** Flutter, Riverpod 3.2.1（手写 provider，无 codegen）, go_router, SharedPreferences, gpt_markdown, TDD（ProviderContainer 注入假仓储）。

## Global Constraints

- 分层：`presentation(features/*) → domain(entities + repository 抽象) ← data(mock/local)`，横切 `core`。presentation 只依赖 domain 抽象。
- Riverpod 3.2.1 手写 provider。`Notifier<T>.build()` 无参；有状态页用 `NotifierProvider.autoDispose.family` + 显式 `start()` 注入参数。
- 远程类仓储返回 `Future<Result<T>>`（`sealed Result = Success|Failure`，`Failure` 携 `AppException`）。本地类（收藏/历史）直接返回 + `watch()`。
- DTO 仅为 JSON 边界服务。`LocalStore` 读方法同步、写方法异步；缺失/解析失败返回 null 不抛。
- 测试 TDD：`ProviderContainer(overrides:[...])` 注入假仓储测 provider；widget 测用 `MaterialApp.router(GoRouter(...))` + 假路由占位；需 LocalStore 时 `SharedPreferences.setMockInitialValues({})` 并 override `sharedPreferencesProvider`。
- 中文 UI 文案；缺失字段显示「暂无信息」绝不渲染 null。Markdown 用 `GptMarkdown(String)`（位置参数）。
- 每个 task 结束跑相关测试 + `flutter analyze`，全绿后 commit。基线 ~442 测试。
- spec：`docs/superpowers/specs/2026-06-27-schonavi-chat-fork-session-design.md`

参考文件（实现前通读）：
- `lib/features/chat/providers/chat_provider.dart`（ChatNotifier/ChatState 全貌）
- `lib/data/ai/ai_chat_repository.dart`（_history 内存 Map + streamReply/seedRecommendationTurn）
- `lib/features/chat/pages/chat_page.dart`、`lib/core/router/app_router.dart`（路由分发）
- `lib/features/history/pages/history_page.dart`（_HistoryTile 现状）
- `lib/features/professor/pages/professor_page.dart`、`lib/features/recommendation/pages/recommendation_page.dart`（两个 FAB 入口）
- `lib/features/home/pages/home_page.dart`（卡片点击 push /professor/:id）
- `lib/data/local/local_history_repository.dart`（LocalStore 持久化范式）
- `lib/data/mock/mock_chat_repository.dart`、`lib/data/http/http_chat_repository.dart`（另两个 ChatRepository 实现）

---

## File Structure

**新增**：
- `lib/domain/entities/fork_ref.dart` — ForkRef 实体（fork 元数据：展示+恢复入口）
- `lib/data/dto/chat_message_dto.dart` — ChatMessageDto（消息序列化，复用 RecommendationDto）
- `lib/data/local/chat_history_store.dart` — ChatHistoryStore 抽象
- `lib/data/local/local_chat_history_store.dart` — LocalChatHistoryStore（SharedPreferences/JSON 实现）
- `lib/features/chat/widgets/professor_anchor_bar.dart` — sticky 教授锚点条
- 对应测试文件（见各 task）

**修改**：
- `lib/domain/repositories/chat_repository.dart` — +4 抽象方法
- `lib/data/ai/ai_chat_repository.dart` — 持久化改造 + 4 方法实现
- `lib/data/mock/mock_chat_repository.dart` — +4 方法
- `lib/data/http/http_chat_repository.dart` — +4 方法（抛 UnimplementedError）
- `lib/data/dto/recommendation_dtos.dart` — +RecommendationDto.fromEntity
- `lib/domain/entities/chat_message.dart` — +ChatMessageKind.forkReroute
- `lib/features/chat/providers/chat_provider.dart` — ChatState+forkAnchor、startFork/resume、send 拦截
- `lib/features/chat/pages/chat_page.dart` — fork 分发 + 锚点条挂载
- `lib/features/chat/widgets/chat_message_bubble.dart` — +重路由双选项渲染
- `lib/core/router/app_router.dart` — /chat fork 参数 + /professor msid
- `lib/features/professor/pages/professor_page.dart` — FAB 改 fork
- `lib/features/home/pages/home_page.dart` — 卡片点击透传 msid
- `lib/features/recommendation/pages/recommendation_page.dart` — 移除 FAB
- `lib/features/history/pages/history_page.dart` — _HistoryTile 折叠展开 v3

---

## Task 1: ForkRef 实体

**Files:**
- Create: `lib/domain/entities/fork_ref.dart`
- Test: `test/domain/entities/fork_ref_test.dart`

**Interfaces:**
- Produces: `ForkRef` 类（构造 + 字段），供 ChatRepository/ChatState/UI 使用。

- [ ] **Step 1: 写失败测试**

`test/domain/entities/fork_ref_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';

void main() {
  group('ForkRef', () {
    test('构造与字段', () {
      final ref = ForkRef(
        forkId: 'f_s1_p1',
        mainSessionId: 's1',
        professorId: 'p1',
        professorName: '李卫国',
        university: '清华大学',
        college: '计算机系',
        createdAt: DateTime(2026, 6, 27, 14, 22),
      );
      expect(ref.forkId, 'f_s1_p1');
      expect(ref.mainSessionId, 's1');
      expect(ref.professorId, 'p1');
      expect(ref.professorName, '李卫国');
      expect(ref.university, '清华大学');
      expect(ref.college, '计算机系');
      expect(ref.createdAt, DateTime(2026, 6, 27, 14, 22));
    });

    test('college 可空', () {
      final ref = ForkRef(
        forkId: 'f_s1_p1',
        mainSessionId: 's1',
        professorId: 'p1',
        professorName: '李卫国',
        university: '清华大学',
        college: null,
        createdAt: DateTime(2026, 6, 27),
      );
      expect(ref.college, isNull);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/domain/entities/fork_ref_test.dart`
Expected: FAIL — `fork_ref.dart` 不存在，导入失败。

- [ ] **Step 3: 写实现**

`lib/domain/entities/fork_ref.dart`：

```dart
/// 一次 fork 追问的元数据。
///
/// 仅存展示与恢复入口所需信息；对话内容由 [ChatRepository.loadHistory]
/// 按 forkId 按需拉取，不塞进本实体。
class ForkRef {
  const ForkRef({
    required this.forkId,
    required this.mainSessionId,
    required this.professorId,
    required this.professorName,
    required this.university,
    required this.college,
    required this.createdAt,
  });

  /// 恢复对话用，跳 /chat?fork&fid=$forkId。
  final String forkId;

  /// 归属主 session（树形挂载用）。
  final String mainSessionId;

  final String professorId;

  /// 头像姓氏 + 姓名展示用。
  final String professorName;

  final String university;

  /// 形如「计算机系」，与 university 组合「清华大学 · 计算机系」。
  final String? college;

  final DateTime createdAt;

  /// 姓氏首字（头像展示）。中文取首字，非中文取首字母大写。
  String get avatarLabel {
    if (professorName.isEmpty) return '?';
    return professorName.substring(0, 1);
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/domain/entities/fork_ref_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/fork_ref.dart test/domain/entities/fork_ref_test.dart
git commit -m "feat(chat): ForkRef 实体"
```

---

## Task 2: ChatMessageKind.forkReroute + ChatMessageDto

**Files:**
- Modify: `lib/domain/entities/chat_message.dart`（+forkReroute 枚举值）
- Modify: `lib/data/dto/recommendation_dtos.dart`（+RecommendationDto.fromEntity）
- Create: `lib/data/dto/chat_message_dto.dart`
- Test: `test/data/dto/chat_message_dto_test.dart`

**Interfaces:**
- Consumes: `ChatMessage`、`RecommendationDto`
- Produces: `ChatMessageDto.fromJson/toJson/toEntity`，`RecommendationDto.fromEntity`，`ChatMessageKind.forkReroute`。

- [ ] **Step 1: 写失败测试**

`test/data/dto/chat_message_dto_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/dto/chat_message_dto.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';

Recommendation _rec() => Recommendation(
      professorId: 'p1',
      name: '李卫国',
      university: '清华大学',
      college: '计算机系',
      title: '教授',
      researchFields: const ['CV'],
      matchLevel: MatchLevel.high,
      reason: '方向匹配',
      limitations: const [],
      homepageUrl: 'http://x',
      matchScore: 0.9,
    );

void main() {
  group('ChatMessageDto', () {
    test('用户消息往返', () {
      final m = ChatMessage(
        id: 'm1',
        role: ChatRole.user,
        content: '为什么推荐他',
        createdAt: DateTime(2026, 6, 27, 14, 0),
        relatedRecommendations: const [],
        status: ChatMessageStatus.done,
      );
      final dto = ChatMessageDto.fromEntity(m);
      final json = dto.toJson();
      final back = ChatMessageDto.fromJson(json).toEntity('m1');
      expect(back.role, ChatRole.user);
      expect(back.content, '为什么推荐他');
      expect(back.status, ChatMessageStatus.done);
      expect(back.kind, ChatMessageKind.conversation);
      expect(back.relatedRecommendations, isEmpty);
    });

    test('助手推荐消息含卡片往返', () {
      final m = ChatMessage(
        id: 'm2',
        role: ChatRole.assistant,
        content: '为你挑了 1 位导师',
        createdAt: DateTime(2026, 6, 27, 14, 1),
        relatedRecommendations: [_rec()],
        status: ChatMessageStatus.done,
        kind: ChatMessageKind.recommendation,
      );
      final back = ChatMessageDto.fromEntity(m)
          .toJson()
          .let((j) => ChatMessageDto.fromJson(j).toEntity('m2'));
      expect(back.kind, ChatMessageKind.recommendation);
      expect(back.relatedRecommendations.length, 1);
      expect(back.relatedRecommendations.first.professorId, 'p1');
      expect(back.relatedRecommendations.first.name, '李卫国');
    });

    test('forkReroute kind 往返', () {
      final m = ChatMessage(
        id: 'm3',
        role: ChatRole.assistant,
        content: '回首页重挑吧',
        createdAt: DateTime(2026, 6, 27, 14, 2),
        relatedRecommendations: const [],
        status: ChatMessageStatus.done,
        kind: ChatMessageKind.forkReroute,
      );
      final back = ChatMessageDto.fromEntity(m)
          .toJson()
          .let((j) => ChatMessageDto.fromJson(j).toEntity('m3'));
      expect(back.kind, ChatMessageKind.forkReroute);
    });
  });
}

extension on Object {
  T let<T>(T Function(Object) f) => f(this);
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/dto/chat_message_dto_test.dart`
Expected: FAIL — `forkReroute` 不存在、`ChatMessageDto` 不存在、`RecommendationDto.fromEntity` 不存在。

- [ ] **Step 3: 加 forkReroute 枚举值**

`lib/domain/entities/chat_message.dart`，把 `ChatMessageKind` 枚举改为：

```dart
/// 助手消息所属的业务轮次。
///
/// 推荐轮由结构化推荐接口直接产出，不支持"重新生成文字"；普通聊天轮才允许
/// 重新生成。forkReroute 是 fork 追问内识别到再推荐意图时的重路由提示轮，
/// 不可重新生成、无推荐卡片。
enum ChatMessageKind { conversation, recommendation, forkReroute }
```

- [ ] **Step 4: 加 RecommendationDto.fromEntity**

`lib/data/dto/recommendation_dtos.dart`，在 `RecommendationDto` 类内 `toEntity()` 方法后追加：

```dart
  factory RecommendationDto.fromEntity(Recommendation r) =>
      RecommendationDto(
        professorId: r.professorId,
        name: r.name,
        university: r.university,
        college: r.college,
        title: r.title,
        researchFields: r.researchFields,
        matchLevel: r.matchLevel.name,
        reason: r.reason,
        limitations: r.limitations,
        homepageUrl: r.homepageUrl,
        matchScore: r.matchScore,
      );
```

- [ ] **Step 5: 写 ChatMessageDto**

`lib/data/dto/chat_message_dto.dart`：

```dart
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/recommendation.dart';
import 'recommendation_dtos.dart';

class ChatMessageDto {
  const ChatMessageDto({
    required this.role,
    required this.content,
    required this.createdAt,
    required this.status,
    required this.kind,
    required this.feedback,
    required this.relatedRecommendations,
  });

  final String role; // 'user' | 'assistant'
  final String content;
  final String createdAt; // ISO8601
  final String status; // sending|streaming|done|error
  final String kind; // conversation|recommendation|forkReroute
  final String feedback; // none|like|dislike
  final List<RecommendationDto> relatedRecommendations;

  factory ChatMessageDto.fromEntity(ChatMessage m) => ChatMessageDto(
        role: m.role == ChatRole.user ? 'user' : 'assistant',
        content: m.content,
        createdAt: m.createdAt.toIso8601String(),
        status: m.status.name,
        kind: m.kind.name,
        feedback: m.feedback.name,
        relatedRecommendations: m.relatedRecommendations
            .map(RecommendationDto.fromEntity)
            .toList(),
      );

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) => ChatMessageDto(
        role: json['role'] as String? ?? 'assistant',
        content: json['content'] as String? ?? '',
        createdAt: json['created_at'] as String? ??
            DateTime.now().toIso8601String(),
        status: json['status'] as String? ?? 'done',
        kind: json['kind'] as String? ?? 'conversation',
        feedback: json['feedback'] as String? ?? 'none',
        relatedRecommendations:
            (json['related_recommendations'] as List<dynamic>? ?? const [])
                .map((e) => RecommendationDto.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role,
        'content': content,
        'created_at': createdAt,
        'status': status,
        'kind': kind,
        'feedback': feedback,
        'related_recommendations':
            relatedRecommendations.map((d) => d.toJson()).toList(),
      };

  ChatMessage toEntity(String id) => ChatMessage(
        id: id,
        role: role == 'user' ? ChatRole.user : ChatRole.assistant,
        content: content,
        createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
        relatedRecommendations:
            relatedRecommendations.map((d) => d.toEntity()).toList(),
        status: ChatMessageStatus.values.byName(status),
        kind: ChatMessageKind.values.byName(kind),
        feedback: ChatMessageFeedback.values.byName(feedback),
      );
}
```

- [ ] **Step 6: 跑测试确认通过**

Run: `flutter test test/data/dto/chat_message_dto_test.dart`
Expected: PASS

- [ ] **Step 7: 跑 analyze 确认 ChatMessageKind.forkReroute 无破坏**

Run: `flutter analyze lib/domain/entities/chat_message.dart lib/data/dto/`
Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add lib/domain/entities/chat_message.dart lib/data/dto/recommendation_dtos.dart lib/data/dto/chat_message_dto.dart test/data/dto/chat_message_dto_test.dart
git commit -m "feat(chat): ChatMessageDto + forkReroute kind"
```

---

## Task 3: ChatRepository 抽象接口扩展

**Files:**
- Modify: `lib/domain/repositories/chat_repository.dart`
- Test: 编译期检查（无独立测试，接口契约由后续实现 task 覆盖）

**Interfaces:**
- Consumes: `ChatMessage`、`ForkRef`、`Result`
- Produces: `ChatRepository` 的 4 个新抽象方法签名（所有实现类须实现）。

- [ ] **Step 1: 加抽象方法**

`lib/domain/repositories/chat_repository.dart`，在 `seedRecommendationTurn` 方法后、类闭合 `}` 前追加：

```dart
  /// 从源会话 fork 出一个新会话：复制源的全部历史到新 forkId，
  /// 绑定 professorId。同主session+同professorId 复用已有 fork（不新建）。
  /// 返回 forkId 供后续追问/恢复。
  /// 生产对接：POST /chat/fork {source_session_id, professor_id}
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  });

  /// 拉取某个会话（主或 fork）的全部消息历史，供页面恢复。
  /// 生产对接：GET /chat/{id}/history
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  });

  /// 列出某主 session 下的所有 fork（按 createdAt 倒序），供历史页展开。
  /// 生产对接：GET /chat/sessions/{id}/forks
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  });

  /// 删除某个 fork（子项左滑删除）。主 session 不受影响。
  /// 生产对接：DELETE /chat/forks/{forkId}
  Future<Result<void>> deleteFork({required String forkId});
```

文件顶部 import 补：

```dart
import '../entities/chat_message.dart';
import '../entities/fork_ref.dart';
```

- [ ] **Step 2: 跑 analyze 确认接口编译 + 实现类尚未实现报错**

Run: `flutter analyze lib/domain/repositories/chat_repository.dart`
Expected: 接口自身 No issues。`AiChatRepository`/`MockChatRepository`/`HttpChatRepository` 因缺方法实现会报 `Missing concrete implementation` 错误——这是预期的，后续 task 修复。

- [ ] **Step 3: Commit**

```bash
git add lib/domain/repositories/chat_repository.dart
git commit -m "feat(chat): ChatRepository 新增 forkSession/loadHistory/listForks/deleteFork 抽象"
```

---

## Task 4: ChatHistoryStore 抽象 + LocalChatHistoryStore 实现

**Files:**
- Create: `lib/data/local/chat_history_store.dart`
- Create: `lib/data/local/local_chat_history_store.dart`
- Test: `test/data/local/local_chat_history_store_test.dart`

**Interfaces:**
- Consumes: `LocalStore`、`ChatMessageDto`、`ForkRef`
- Produces: `ChatHistoryStore` 抽象 + `LocalChatHistoryStore`，供 AiChatRepository/MockChatRepository 委托。

存储设计（两个 LocalStore key）：
- `chat_history_<sessionId>` → `List<Map>`（ChatMessageDto.toJson 数组），存消息。
- `chat_forks` → `List<Map>`（所有 ForkRef 平铺），按 mainSessionId 过滤。

- [ ] **Step 1: 写失败测试**

`test/data/local/local_chat_history_store_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/dto/chat_message_dto.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemLocalStore implements LocalStore {
  final Map<String, dynamic> _m = {};
  @override
  String? getString(String key) => _m[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
  @override
  bool? getBool(String key) => _m[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;
  @override
  Map<String, dynamic>? getJson(String key) => _m[key] as Map<String, dynamic>?;
  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      _m[key] = value;
  @override
  List<dynamic>? getJsonList(String key) => _m[key] as List<dynamic>?;
  @override
  Future<void> setJsonList(String key, List<dynamic> value) async =>
      _m[key] = value;
  @override
  bool containsKey(String key) => _m.containsKey(key);
  @override
  Future<void> remove(String key) async => _m.remove(key);
  @override
  Future<void> clear() async => _m.clear();
}

ChatMessage _msg(String id, String content,
        {ChatRole role = ChatRole.assistant}) =>
    ChatMessage(
      id: id,
      role: role,
      content: content,
      createdAt: DateTime(2026, 6, 27),
      relatedRecommendations: const [],
      status: ChatMessageStatus.done,
    );

void main() {
  late LocalChatHistoryStore store;
  late _MemLocalStore backing;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backing = _MemLocalStore();
    store = LocalChatHistoryStore(backing);
  });

  group('消息持久化', () {
    test('save 后 load 回来', () async {
      await store.save('s1', [_msg('m1', 'hi'), _msg('m2', 'yo')]);
      final loaded = await store.load('s1');
      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded[0].content, 'hi');
      expect(loaded[1].content, 'yo');
    });

    test('load 未存过的 session 返回 null', () async {
      expect(await store.load('nope'), isNull);
    });

    test('save 覆盖旧内容', () async {
      await store.save('s1', [_msg('m1', 'old')]);
      await store.save('s1', [_msg('m1', 'new')]);
      final loaded = await store.load('s1');
      expect(loaded!.length, 1);
      expect(loaded[0].content, 'new');
    });
  });

  group('ForkRef 持久化', () {
    test('saveFork + listForks 按时间倒序', () async {
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p1', mainSessionId: 's1', professorId: 'p1',
        professorName: '李', university: '清华', college: 'cs',
        createdAt: DateTime(2026, 6, 27, 10),
      ));
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p2', mainSessionId: 's1', professorId: 'p2',
        professorName: '王', university: '北大', college: null,
        createdAt: DateTime(2026, 6, 27, 14),
      ));
      final forks = await store.listForks('s1');
      expect(forks.length, 2);
      expect(forks[0].forkId, 'f_s1_p2'); // 14:00 在前
      expect(forks[1].forkId, 'f_s1_p1');
    });

    test('findFork 命中已有', () async {
      final ref = ForkRef(
        forkId: 'f_s1_p1', mainSessionId: 's1', professorId: 'p1',
        professorName: '李', university: '清华', college: 'cs',
        createdAt: DateTime(2026, 6, 27),
      );
      await store.saveFork(ref);
      expect(await store.findFork('s1', 'p1'), isNotNull);
      expect(await store.findFork('s1', 'pX'), isNull);
    });

    test('deleteFork 仅删指定 fork', () async {
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p1', mainSessionId: 's1', professorId: 'p1',
        professorName: '李', university: '清华', college: null,
        createdAt: DateTime(2026, 6, 27),
      ));
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p2', mainSessionId: 's1', professorId: 'p2',
        professorName: '王', university: '北大', college: null,
        createdAt: DateTime(2026, 6, 27),
      ));
      await store.deleteFork('f_s1_p1');
      final forks = await store.listForks('s1');
      expect(forks.length, 1);
      expect(forks[0].forkId, 'f_s1_p2');
    });

    test('listForks 隔离不同主 session', () async {
      await store.saveFork(ForkRef(
        forkId: 'f_s1_p1', mainSessionId: 's1', professorId: 'p1',
        professorName: '李', university: '清华', college: null,
        createdAt: DateTime(2026, 6, 27),
      ));
      await store.saveFork(ForkRef(
        forkId: 'f_s2_p1', mainSessionId: 's2', professorId: 'p1',
        professorName: '李', university: '清华', college: null,
        createdAt: DateTime(2026, 6, 27),
      ));
      expect((await store.listForks('s1')).length, 1);
      expect((await store.listForks('s2')).length, 1);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/local/local_chat_history_store_test.dart`
Expected: FAIL — `chat_history_store.dart`/`local_chat_history_store.dart` 不存在。

- [ ] **Step 3: 写 ChatHistoryStore 抽象**

`lib/data/local/chat_history_store.dart`：

```dart
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/fork_ref.dart';

/// 会话历史与 fork 元数据的持久化抽象。
///
/// mock/llm 数据源下用 [LocalChatHistoryStore]（SharedPreferences/JSON）；
/// 未来 http 数据源对接真后端时换实现。读方法异步（LocalStore 写异步）。
abstract class ChatHistoryStore {
  Future<List<ChatMessage>?> load(String sessionId);
  Future<void> save(String sessionId, List<ChatMessage> messages);

  Future<List<ForkRef>> listForks(String mainSessionId);
  Future<ForkRef?> findFork(String mainSessionId, String professorId);
  Future<void> saveFork(ForkRef ref);
  Future<void> deleteFork(String forkId);
}
```

- [ ] **Step 4: 写 LocalChatHistoryStore**

`lib/data/local/local_chat_history_store.dart`：

```dart
import '../../core/storage/local_store.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/fork_ref.dart';
import '../dto/chat_message_dto.dart';
import 'chat_history_store.dart';

class LocalChatHistoryStore implements ChatHistoryStore {
  LocalChatHistoryStore(this._store);

  final LocalStore _store;

  static const _forksKey = 'chat_forks';

  static String _historyKey(String sessionId) => 'chat_history_$sessionId';

  @override
  Future<List<ChatMessage>?> load(String sessionId) async {
    final raw = _store.getJsonList(_historyKey(sessionId));
    if (raw == null) return null;
    var i = 0;
    return raw
        .map((e) =>
            ChatMessageDto.fromJson(e as Map<String, dynamic>).toEntity('m${i++}'))
        .toList();
  }

  @override
  Future<void> save(String sessionId, List<ChatMessage> messages) async {
    await _store.setJsonList(
      _historyKey(sessionId),
      messages.map((m) => ChatMessageDto.fromEntity(m).toJson()).toList(),
    );
  }

  List<ForkRef> _readAllForks() {
    final raw = _store.getJsonList(_forksKey) ?? const [];
    return raw
        .map((e) => _forkFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAllForks(List<ForkRef> forks) async {
    await _store.setJsonList(
      _forksKey,
      forks.map(_forkToJson).toList(),
    );
  }

  @override
  Future<List<ForkRef>> listForks(String mainSessionId) async {
    return _readAllForks()
        .where((f) => f.mainSessionId == mainSessionId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ForkRef?> findFork(
    String mainSessionId,
    String professorId,
  ) async {
    return _readAllForks().cast<ForkRef?>().firstWhere(
          (f) =>
              f!.mainSessionId == mainSessionId &&
              f.professorId == professorId,
          orElse: () => null,
        );
  }

  @override
  Future<void> saveFork(ForkRef ref) async {
    final all = _readAllForks();
    all.removeWhere((f) => f.forkId == ref.forkId);
    all.add(ref);
    await _writeAllForks(all);
  }

  @override
  Future<void> deleteFork(String forkId) async {
    final all = _readAllForks();
    all.removeWhere((f) => f.forkId == forkId);
    await _writeAllForks(all);
    await _store.remove(_historyKey(forkId));
  }

  Map<String, dynamic> _forkToJson(ForkRef f) => <String, dynamic>{
        'fork_id': f.forkId,
        'main_session_id': f.mainSessionId,
        'professor_id': f.professorId,
        'professor_name': f.professorName,
        'university': f.university,
        'college': f.college,
        'created_at': f.createdAt.toIso8601String(),
      };

  ForkRef _forkFromJson(Map<String, dynamic> json) => ForkRef(
        forkId: json['fork_id'] as String? ?? '',
        mainSessionId: json['main_session_id'] as String? ?? '',
        professorId: json['professor_id'] as String? ?? '',
        professorName: json['professor_name'] as String? ?? '',
        university: json['university'] as String? ?? '',
        college: json['college'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
      );
}
```

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/data/local/local_chat_history_store_test.dart`
Expected: PASS

- [ ] **Step 6: 跑 analyze**

Run: `flutter analyze lib/data/local/`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/data/local/chat_history_store.dart lib/data/local/local_chat_history_store.dart test/data/local/local_chat_history_store_test.dart
git commit -m "feat(chat): ChatHistoryStore 抽象 + LocalChatHistoryStore 持久化"
```

---

## Task 5: AiChatRepository 持久化改造 + 4 方法实现

**Files:**
- Modify: `lib/data/ai/ai_chat_repository.dart`
- Modify: `lib/core/di/providers.dart`（AiChatRepository 注入 store）
- Test: `test/data/ai/ai_chat_repository_fork_test.dart`

**Interfaces:**
- Consumes: `ChatHistoryStore`、`MockDb`（取导师信息）、`LlmClient`
- Produces: `AiChatRepository` 实现 4 个新方法；构造加 `ChatHistoryStore` 参数。

- [ ] **Step 1: 写失败测试**

`test/data/ai/ai_chat_repository_fork_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubLlm implements LlmClient {
  _StubLlm(this.reply);
  final String reply;
  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    return Success(reply);
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) async* {
    yield reply;
  }
}

void main() {
  late AiChatRepository repo;
  late LocalChatHistoryStore store;
  late MockDb db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = MockDb();
    store = LocalChatHistoryStore(_MemStore());
    repo = AiChatRepository(llm: _StubLlm('回答'), db: db, historyStore: store);
  });

  group('AiChatRepository 持久化改造（fork 4 方法见 Task 6 mixin）', () {
    test('streamReply 完成后历史写入 store', () async {
      await repo.streamReply(
        sessionId: 's1',
        message: '为什么推荐他',
        professorId: null,
      ).last;
      final saved = await store.load('s1');
      expect(saved, isNotNull);
      expect(saved!.length, greaterThanOrEqualTo 2); // user + assistant
      expect(saved.any((m) => m.content == '回答'), isTrue);
    });

    test('新进程读 store 回填内存历史（_ensureHistoryLoaded）', () async {
      // 先一个 repo 写入
      await repo.streamReply(
        sessionId: 's1',
        message: '问1',
        professorId: null,
      ).last;
      // 模拟新进程：新建 repo（内存 _history 空），再 streamReply 时应从 store 回填
      final repo2 = AiChatRepository(
          llm: _StubLlm('回答2'), db: db, historyStore: store);
      await repo2.streamReply(
        sessionId: 's1',
        message: '问2',
        professorId: null,
      ).last;
      final saved = await store.load('s1');
      // 含「问1」回填 + 「问2」追加
      expect(saved!.any((m) => m.content == '问1'), isTrue);
      expect(saved.any((m) => m.content == '问2'), isTrue);
    });
  });
}

class _MemStore implements scho_navi.LocalStore {
  final Map<String, dynamic> _m = {};
  @override
  String? getString(String key) => _m[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
  @override
  bool? getBool(String key) => _m[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;
  @override
  Map<String, dynamic>? getJson(String key) => _m[key] as Map<String, dynamic>?;
  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      _m[key] = value;
  @override
  List<dynamic>? getJsonList(String key) => _m[key] as List<dynamic>?;
  @override
  Future<void> setJsonList(String key, List<dynamic> value) async =>
      _m[key] = value;
  @override
  bool containsKey(String key) => _m.containsKey(key);
  @override
  Future<void> remove(String key) async => _m.remove(key);
  @override
  Future<void> clear() async => _m.clear();
}
```

> 注：测试 import `scho_navi.LocalStore`——若包名不同，按现有测试文件的 import 风格调整（参考 `test/data/local/...` 现有测试的 import 路径）。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/data/ai/ai_chat_repository_fork_test.dart`
Expected: FAIL — `AiChatRepository` 构造无 `historyStore` 参数、4 方法未实现。

- [ ] **Step 3: 改造 AiChatRepository**

`lib/data/ai/ai_chat_repository.dart`：

构造加 `historyStore`，`_history` 内存 Map 保留作 LLM 调用缓冲（读时优先 store 回填内存）。文件顶部 import 加：

```dart
import '../../core/storage/local_store.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/fork_ref.dart';
import '../local/chat_history_store.dart';
```

构造改为：

```dart
class AiChatRepository implements ChatRepository {
  AiChatRepository({
    required this.llm,
    required this.db,
    required this.historyStore,
  });

  final LlmClient llm;
  final MockDb db;
  final ChatHistoryStore historyStore;
  final Map<String, List<LlmMessage>> _history = {};
```

**不在此 task 写 fork 4 方法**——它们由 Task 6 的 `ChatForkMixin` 提供（AiChatRepository 在 Task 6 接 `with ChatForkMixin`）。本 task 只做：构造加 `historyStore` 字段 + `_history` 读写 store 的持久化改造。

辅助方法（放在 `seedRecommendationTurn` 后、`_summarizeRecommendations` 前）：

```dart
  LlmMessage _toLlmMessage(ChatMessage m) =>
      LlmMessage(m.role == ChatRole.user ? 'user' : 'assistant', m.content);

  Future<void> _ensureHistoryLoaded(String sessionId) async {
    if (_history.containsKey(sessionId)) return;
    final msgs = await historyStore.load(sessionId) ?? const [];
    _history[sessionId] = msgs.map(_toLlmMessage).toList();
  }
```

`_summarizeRecommendations` 内、`streamReply` 的 `onListen` 里读 `_history.putIfAbsent` 处，改为先 `_ensureHistoryLoaded` 再 putIfAbsent。具体：把 `streamReply` onListen 中：

```dart
        final history = _history.putIfAbsent(sessionId, () => []);
```

改为：

```dart
        await _ensureHistoryLoaded(sessionId);
        final history = _history.putIfAbsent(sessionId, () => []);
```

并在 `onDone`/`persistIfNeeded` 后追加持久化（在 `persistIfNeeded` 的 if 体内加 `await historyStore.save(sessionId, [...]);` 不可行因为缺 ChatMessage——改为：在 `onDone` 完成、`persistIfNeeded()` 之后，把当前 `_history[sessionId]` 写回 store）。在 `onDone` 回调里 `persistIfNeeded();` 后加：

```dart
                  await historyStore.save(
                    sessionId,
                    _history[sessionId]!
                        .map((m) => ChatMessage(
                              id: 'm${_history[sessionId]!.indexOf(m)}',
                              role: m.role == 'user'
                                  ? ChatRole.user
                                  : ChatRole.assistant,
                              content: m.content,
                              createdAt: DateTime.now(),
                              relatedRecommendations: const [],
                              status: ChatMessageStatus.done,
                              kind: ChatMessageKind.conversation,
                            ))
                        .toList(),
                  );
```

> 注意：此持久化仅存对话文本，不含推荐卡（推荐卡由 `seedRecommendationTurn` 单独存）。`seedRecommendationTurn` 末尾加持久化：在 `history.add(LlmMessage('assistant', _summarizeRecommendations(result)));` 后加：
> ```dart
>     await historyStore.save(sessionId,
>         [/* user prompt */ LlmMessage('user', userPrompt), ...]
>         .map(...).toList());
> ```
> 实现时按现有 `_history` 写回同一 key 的方式合并——若复杂可简化为：`seedRecommendationTurn` 后调 `historyStore.save(sessionId, <从_history映射>)`。保持测试通过即可。

- [ ] **Step 4: 更新 providers.dart 注入 store**

`lib/core/di/providers.dart`，`chatRepositoryProvider` 的 `DataSource.llm` 分支改为：

```dart
    case DataSource.llm:
      return AiChatRepository(
        llm: ref.watch(llmClientProvider),
        db: ref.watch(mockDbProvider),
        historyStore: LocalChatHistoryStore(ref.watch(localStoreProvider)),
      );
```

文件顶部 import 加：

```dart
import '../../data/local/chat_history_store.dart';
import '../../data/local/local_chat_history_store.dart';
```

> 注：`chatRepositoryProvider` 当前非 autoDispose，store 随 provider 单例存活；fork 持久化数据存于 SharedPreferences，跨 provider 生命周期不丢。

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/data/ai/ai_chat_repository_fork_test.dart`
Expected: PASS

- [ ] **Step 6: 跑现有 ai_chat_repository_test 确认无回归**

Run: `flutter test test/data/ai/ai_chat_repository_test.dart`
Expected: PASS（构造改了参数，若旧测试直接 `AiChatRepository(llm:, db:)` 构造会编译失败——需在旧测试补 `historyStore:` 参数。若有失败，按报错给旧测试构造补 `historyStore: LocalChatHistoryStore(...)`）。

- [ ] **Step 7: 跑 analyze + chat 相关测试**

Run: `flutter analyze lib/data/ai/ai_chat_repository.dart lib/core/di/providers.dart`
Run: `flutter test test/features/chat/ test/data/ai/`
Expected: analyze No issues；测试全绿。

- [ ] **Step 8: Commit**

```bash
git add lib/data/ai/ai_chat_repository.dart lib/core/di/providers.dart test/data/ai/ai_chat_repository_fork_test.dart test/data/ai/ai_chat_repository_test.dart
git commit -m "feat(chat): AiChatRepository 持久化 + forkSession/loadHistory/listForks/deleteFork"
```

---

## Task 6: ChatForkMixin + MockChatRepository + HttpChatRepository 实现 4 方法

**Files:**
- Create: `lib/data/chat_fork_mixin.dart`
- Modify: `lib/data/ai/ai_chat_repository.dart`（with ChatForkMixin，删自身 4 方法）
- Modify: `lib/data/mock/mock_chat_repository.dart`（with ChatForkMixin，构造加 store）
- Modify: `lib/data/http/http_chat_repository.dart`（抛 UnimplementedError，不走 mixin）
- Test: `test/data/mock/mock_chat_repository_fork_test.dart`

**Interfaces:**
- Consumes: `ChatHistoryStore`、`MockDb`（mixin 取导师信息用 abstract getter）
- Produces: `ChatForkMixin`（封装 4 方法 store 委托），AiChatRepository/MockChatRepository 复用，消除 verbatim duplication。

> **设计决策（pre-flight 调整）**：原 plan 让两个 repository 各自复制 4 方法逻辑——但 verbatim duplication 是 review 会拦的 Important 项。改为抽 `ChatForkMixin`，AiChatRepository 和 MockChatRepository 都 `with ChatForkMixin` 复用。HttpChatRepository 不走 mixin（抛 UnimplementedError）。

- [ ] **Step 1: 写 ChatForkMixin**

`lib/data/chat_fork_mixin.dart`：

```dart
import '../core/error/app_exception.dart';
import '../core/result/result.dart';
import '../domain/entities/chat_message.dart';
import '../domain/entities/fork_ref.dart';
import '../domain/repositories/chat_repository.dart';
import 'local/chat_history_store.dart';
import 'mock/mock_db.dart';

/// 封装 forkSession/loadHistory/listForks/deleteFork 四个方法的 store 委托逻辑。
///
/// 同时被 [AiChatRepository] 与 [MockChatRepository] 复用，消除 verbatim
/// duplication。Http 实现不接 store，不使用本 mixin。
mixin ChatForkMixin on ChatRepository {
  ChatHistoryStore get historyStore;
  MockDb get db;

  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) async {
    try {
      final existing =
          await historyStore.findFork(sourceSessionId, professorId);
      if (existing != null) return Success(existing.forkId);
      final forkId = 'f_${sourceSessionId}_$professorId';
      final source = await historyStore.load(sourceSessionId) ?? const [];
      await historyStore.save(forkId, source);
      final prof = db.getProfessor(professorId);
      await historyStore.saveFork(ForkRef(
        forkId: forkId,
        mainSessionId: sourceSessionId,
        professorId: professorId,
        professorName: prof?.name ?? '该导师',
        university: prof?.university ?? '',
        college: prof?.college,
        createdAt: DateTime.now(),
      ));
      return Success(forkId);
    } catch (_) {
      return Failure(const UnknownException());
    }
  }

  @override
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  }) async {
    try {
      return Success(await historyStore.load(sessionId) ?? const []);
    } catch (_) {
      return Failure(const UnknownException());
    }
  }

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) async {
    try {
      return Success(await historyStore.listForks(mainSessionId));
    } catch (_) {
      return Failure(const UnknownException());
    }
  }

  @override
  Future<Result<void>> deleteFork({required String forkId}) async {
    try {
      await historyStore.deleteFork(forkId);
      return const Success(null);
    } catch (_) {
      return Failure(const UnknownException());
    }
  }
}
```

> 注：`mixin on ChatRepository` 要求宿主类 `implements ChatRepository`——AiChatRepository/MockChatRepository 均满足。`historyStore`/`db` 为 abstract getter，由宿主类提供（AiChatRepository 已有 `db` 字段；MockChatRepository 已有 `_db` 字段——需暴露为 `db` getter）。

- [ ] **Step 2: AiChatRepository 改用 mixin**

`lib/data/ai/ai_chat_repository.dart`：

类声明改为 `class AiChatRepository with ChatForkMixin implements ChatRepository {`。删除 Task 5 里加的 `forkSession`/`loadHistory`/`listForks`/`deleteFork` 四个方法（它们现由 mixin 提供）。保留 `historyStore` 字段（mixin 通过 getter 访问——若字段名是 `historyStore` 则直接可用；若 mixin 需 `db` getter 而 AiChatRepository 字段是 `db`，也直接可用）。

import 加 `import '../chat_fork_mixin.dart';`。

- [ ] **Step 3: 写失败测试**

`test/data/mock/mock_chat_repository_fork_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemStore implements scho_navi.LocalStore {
  final Map<String, dynamic> _m = {};
  @override
  String? getString(String key) => _m[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
  @override
  bool? getBool(String key) => _m[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;
  @override
  Map<String, dynamic>? getJson(String key) => _m[key] as Map<String, dynamic>?;
  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      _m[key] = value;
  @override
  List<dynamic>? getJsonList(String key) => _m[key] as List<dynamic>?;
  @override
  Future<void> setJsonList(String key, List<dynamic> value) async =>
      _m[key] = value;
  @override
  bool containsKey(String key) => _m.containsKey(key);
  @override
  Future<void> remove(String key) async => _m.remove(key);
  @override
  Future<void> clear() async => _m.clear();
}

void main() {
  late MockChatRepository repo;
  late LocalChatHistoryStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = LocalChatHistoryStore(_MemStore());
    repo = MockChatRepository(MockDb(), historyStore: store);
  });

  test('forkSession 复制历史 + 复用', () async {
    await store.save('s1', [
      ChatMessage(
        id: 'm1', role: ChatRole.user, content: '想做CV',
        createdAt: DateTime(2026, 6, 27), relatedRecommendations: const [],
        status: ChatMessageStatus.done,
      ),
    ]);
    final prof = MockDb().professors.first;
    final res = await repo.forkSession(
        sourceSessionId: 's1', professorId: prof.id);
    expect(res, isA<Success<String>>());
    expect((await store.load((res as Success<String>).data))!.length, 1);
  });

  test('listForks 返回 fork', () async {
    await store.save('s1', [
      ChatMessage(
        id: 'm1', role: ChatRole.user, content: '想做CV',
        createdAt: DateTime(2026, 6, 27), relatedRecommendations: const [],
        status: ChatMessageStatus.done,
      ),
    ]);
    final prof = MockDb().professors.first;
    await repo.forkSession(sourceSessionId: 's1', professorId: prof.id);
    final forks = await repo.listForks(mainSessionId: 's1');
    expect(forks.length, 1);
  });
}

// —— AiChatRepository 走同一 mixin，覆盖 fork CRUD 完整用例（从 Task 5 移入）——
class _StubLlm implements LlmClient {
  _StubLlm(this.reply);
  final String reply;
  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    return Success(reply);
  }

  @override
  Stream<String> stream({
    required List<LlmMessage> messages,
    double temperature = 0.7,
  }) async* {
    yield reply;
  }
}

void aiChatForkCases() {
  late AiChatRepository repo;
  late LocalChatHistoryStore store;
  late MockDb db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = MockDb();
    store = LocalChatHistoryStore(_MemStore());
    repo = AiChatRepository(llm: _StubLlm('回答'), db: db, historyStore: store);
  });

  test('forkSession 复制源历史到 forkId', () async {
    await store.save('s1', [
      ChatMessage(
        id: 'm1', role: ChatRole.user, content: '想做CV',
        createdAt: DateTime(2026, 6, 27), relatedRecommendations: const [],
        status: ChatMessageStatus.done,
      ),
      ChatMessage(
        id: 'm2', role: ChatRole.assistant, content: '为你挑了导师',
        createdAt: DateTime(2026, 6, 27), relatedRecommendations: const [],
        status: ChatMessageStatus.done,
      ),
    ]);
    final prof = db.professors.first;
    final res = await repo.forkSession(
        sourceSessionId: 's1', professorId: prof.id);
    expect(res, isA<Success<String>>());
    final forkId = (res as Success<String>).data;
    expect(forkId, 'f_s1_${prof.id}');
    final forkHistory = await store.load(forkId);
    expect(forkHistory!.length, 2);
    expect(forkHistory[0].content, '想做CV');
  });

  test('同导师复用已有 fork 不新建', () async {
    await store.save('s1', [
      ChatMessage(
        id: 'm1', role: ChatRole.user, content: '想做CV',
        createdAt: DateTime(2026, 6, 27), relatedRecommendations: const [],
        status: ChatMessageStatus.done,
      ),
    ]);
    final prof = db.professors.first;
    final id1 = await repo.forkSession(sourceSessionId: 's1', professorId: prof.id);
    final id2 = await repo.forkSession(sourceSessionId: 's1', professorId: prof.id);
    expect((id2 as Success<String>).data, (id1 as Success<String>).data);
    expect((await repo.listForks(mainSessionId: 's1')).length, 1);
  });

  test('ForkRef 含导师信息', () async {
    await store.save('s1', [
      ChatMessage(
        id: 'm1', role: ChatRole.user, content: '想做CV',
        createdAt: DateTime(2026, 6, 27), relatedRecommendations: const [],
        status: ChatMessageStatus.done,
      ),
    ]);
    final prof = db.professors.first;
    await repo.forkSession(sourceSessionId: 's1', professorId: prof.id);
    final forks = await repo.listForks(mainSessionId: 's1');
    expect(forks[0].professorName, prof.name);
    expect(forks[0].university, prof.university);
  });

  test('loadHistory 未知 session 返回空', () async {
    final res = await repo.loadHistory(sessionId: 'unknown');
    expect((res as Success<List<ChatMessage>>).data, isEmpty);
  });

  test('deleteFork 后 listForks 不再含', () async {
    await store.save('s1', [
      ChatMessage(
        id: 'm1', role: ChatRole.user, content: '想做CV',
        createdAt: DateTime(2026, 6, 27), relatedRecommendations: const [],
        status: ChatMessageStatus.done,
      ),
    ]);
    final prof = db.professors.first;
    final forkId = (await repo.forkSession(
        sourceSessionId: 's1', professorId: prof.id) as Success<String>).data;
    await repo.deleteFork(forkId: forkId);
    expect(await repo.listForks(mainSessionId: 's1'), isEmpty);
  });
}
```

> 注：上述 AiChatRepository 用例放在同一测试文件，由 `main()` 末尾调用 `aiChatForkCases()` 或直接合并入 `main()`——实现时按 flutter_test 习惯合并为一个 `main()`，去掉外层 `aiChatForkCases` 包装。需 import `package:scho_navi/core/ai/llm_client.dart`、`data/ai/ai_chat_repository.dart`。

- [ ] **Step 4: 跑测试确认失败**

Run: `flutter test test/data/mock/mock_chat_repository_fork_test.dart`
Expected: FAIL — `MockChatRepository` 构造无 `historyStore`、4 方法未实现（mixin 未接入）。

- [ ] **Step 5: MockChatRepository 接入 mixin**

`lib/data/mock/mock_chat_repository.dart`，构造加 `historyStore`，类声明加 mixin：

```dart
class MockChatRepository with ChatForkMixin implements ChatRepository {
  MockChatRepository(
    this._db, {
    required this.historyStore,
    this.streamChunkDelay = const Duration(milliseconds: 28),
  });

  final MockDb _db;
  final ChatHistoryStore historyStore;
  final Duration streamChunkDelay;

  @override
  MockDb get db => _db;
```

文件顶部 import 加：

```dart
import '../chat_fork_mixin.dart';
import '../local/chat_history_store.dart';
```

（无需再手写 4 方法——mixin 提供。）

- [ ] **Step 6: HttpChatRepository 实现 4 方法（抛 UnimplementedError，不走 mixin）**

`lib/data/http/http_chat_repository.dart`，import 加：

```dart
import '../../core/error/app_exception.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/fork_ref.dart';
```

在 `streamReply` 后追加：

```dart
  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) {
    // 生产对接：POST /api/v1/chat/fork
    throw UnimplementedError('forkSession 未在 http 数据源实现');
  }

  @override
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  }) {
    // 生产对接：GET /api/v1/chat/{id}/history
    throw UnimplementedError('loadHistory 未在 http 数据源实现');
  }

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) {
    // 生产对接：GET /api/v1/chat/sessions/{id}/forks
    throw UnimplementedError('listForks 未在 http 数据源实现');
  }

  @override
  Future<Result<void>> deleteFork({required String forkId}) {
    // 生产对接：DELETE /api/v1/chat/forks/{forkId}
    throw UnimplementedError('deleteFork 未在 http 数据源实现');
  }
```

- [ ] **Step 7: 更新所有测试中 MockChatRepository 构造点**

全局搜 `MockChatRepository(` 构造调用，给每处补 `historyStore:` 参数。Run:

```bash
grep -rn "MockChatRepository(" test/ lib/
```

对每处构造补 `historyStore: LocalChatHistoryStore(<store>)`。测试中通常用 `SharedPreferences.setMockInitialValues({})` + `LocalChatHistoryStore(_MemStore())`。

- [ ] **Step 8: 跑测试确认通过 + 无回归**

Run: `flutter test test/data/mock/mock_chat_repository_fork_test.dart`
Run: `flutter test test/features/chat/`
Expected: PASS

- [ ] **Step 9: 跑 analyze**

Run: `flutter analyze lib/data/mock/ lib/data/http/ lib/data/chat_fork_mixin.dart lib/data/ai/`
Expected: No issues（`HttpChatRepository` 抛 UnimplementedError 不影响 analyze）。

- [ ] **Step 10: Commit**

```bash
git add lib/data/chat_fork_mixin.dart lib/data/ai/ai_chat_repository.dart lib/data/mock/mock_chat_repository.dart lib/data/http/http_chat_repository.dart test/data/mock/mock_chat_repository_fork_test.dart
git commit -m "feat(chat): ChatForkMixin 复用 + Mock/Http 实现 fork 4 方法"
```

> 注：Task 5 不再让 AiChatRepository 手写 4 方法（改为 Task 6 Step 2 接 mixin）。Task 5 仍负责 AiChatRepository 的持久化改造（_history 读写 store）+ historyStore 字段注入。执行 Task 5 时只做持久化，4 方法留给 Task 6 的 mixin。

---

## Task 7: ChatState + ChatNotifier fork 支持（startFork/resume + send 拦截）

**Files:**
- Modify: `lib/features/chat/providers/chat_provider.dart`
- Test: `test/features/chat/chat_fork_test.dart`

**Interfaces:**
- Consumes: `ChatRepository.forkSession/loadHistory/listForks`、`ForkRef`
- Produces: `ChatState.forkAnchor`、`ChatNotifier.startFork`、`ChatNotifier.resume`、fork 内 send 走重路由。

- [ ] **Step 1: 写失败测试**

`test/features/chat/chat_fork_test.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:scho_navi/features/chat/providers/chat_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemStore implements scho_navi.LocalStore {
  final Map<String, dynamic> _m = {};
  @override
  String? getString(String key) => _m[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
  @override
  bool? getBool(String key) => _m[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;
  @override
  Map<String, dynamic>? getJson(String key) => _m[key] as Map<String, dynamic>?;
  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      _m[key] = value;
  @override
  List<dynamic>? getJsonList(String key) => _m[key] as List<dynamic>?;
  @override
  Future<void> setJsonList(String key, List<dynamic> value) async =>
      _m[key] = value;
  @override
  bool containsKey(String key) => _m.containsKey(key);
  @override
  Future<void> remove(String key) async => _m.remove(key);
  @override
  Future<void> clear() async => _m.clear();
}

MockChatRepository _repo() {
  SharedPreferences.setMockInitialValues({});
  return MockChatRepository(MockDb(),
      historyStore: LocalChatHistoryStore(_MemStore()));
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(_repo()),
    ]);
  });
  tearDown(() => container.dispose());

  test('startFork 回填历史 + 设 forkAnchor', () async {
    final repo = _repo();
    // 预置主 session 历史
    await repo.seedRecommendationTurn(
      sessionId: 's1',
      userPrompt: '想做CV',
      result: _recResult('s1'),
    );
    container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    final notifier = container.read(chatProvider(Object()).notifier);
    await notifier.startFork(
        sourceSessionId: 's1', professorId: _firstProfId());
    await Future.delayed(Duration.zero);
    final state = container.read(chatProvider(Object()));
    expect(state.forkAnchor, isNotNull);
    expect(state.sessionId, startsWith('f_s1_'));
    expect(state.messages, isNotEmpty);
  });

  test('fork 内 send 触发再推荐意图 → forkReroute 消息', () async {
    final repo = _repo();
    await repo.seedRecommendationTurn(
      sessionId: 's1', userPrompt: '想做CV', result: _recResult('s1'),
    );
    container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      recommendationNeedClassifierProvider.overrideWithValue(
        _AlwaysNeedClassifier()),
    ]);
    final notifier = container.read(chatProvider(Object()).notifier);
    await notifier.startFork(
        sourceSessionId: 's1', professorId: _firstProfId());
    await Future.delayed(Duration.zero);
    await notifier.send('换一批导师');
    await Future.delayed(const Duration(milliseconds: 50));
    final state = container.read(chatProvider(Object()));
    final reroute = state.messages
        .where((m) => m.kind == ChatMessageKind.forkReroute)
        .toList();
    expect(reroute, isNotEmpty);
  });
}

String _firstProfId() => MockDb().professors.first.id;

RecommendationResult _recResult(String sid) => RecommendationResult(
      sessionId: sid,
      queryUnderstanding: const QueryUnderstanding(
        researchInterests: [], preferredLocations: [],
        preferredUniversities: [], uncertainties: [],
      ),
      recommendations: const [],
      followUpQuestions: const [],
    );

class _AlwaysNeedClassifier implements RecommendationNeedClassifier {
  @override
  Future<bool> needRecommendations(String followUp,
      {RecommendationResult? lastResult}) async => true;
}
```

> 注：import 需补 `recommendation_need_classifier.dart`、`recommendation_result.dart`、`query_understanding.dart`、`recommendation.dart` 等，按编译错误补齐。

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/chat/chat_fork_test.dart`
Expected: FAIL — `startFork`/`forkAnchor` 不存在。

- [ ] **Step 3: 改 ChatState**

`lib/features/chat/providers/chat_provider.dart`，`ChatState` 加字段：

```dart
class ChatState {
  const ChatState({
    required this.sessionId,
    required this.professorId,
    required this.messages,
    required this.activity,
    required this.followUpQuestions,
    this.forkAnchor,
  });

  const ChatState.initial()
    : sessionId = null,
      professorId = null,
      messages = const [],
      activity = ChatActivity.idle,
      followUpQuestions = const [],
      forkAnchor = null;

  final String? sessionId;
  final String? professorId;
  final List<ChatMessage> messages;
  final ChatActivity activity;
  final List<String> followUpQuestions;

  /// fork 追问锚点：非 null 表示当前是 fork 分支，渲染顶部教授条。
  final ForkRef? forkAnchor;
```

`copyWith` 加 `ForkRef? forkAnchor` 参数（注意 nullable 用 sentinel 或 `??` 语义——因 ForkRef 本身可空，直接 `forkAnchor ?? this.forkAnchor`）：

```dart
  ChatState copyWith({
    String? sessionId,
    String? professorId,
    List<ChatMessage>? messages,
    ChatActivity? activity,
    List<String>? followUpQuestions,
    Object? forkAnchor = _sentinel,
  }) => ChatState(
    sessionId: sessionId ?? this.sessionId,
    professorId: professorId ?? this.professorId,
    messages: messages ?? this.messages,
    activity: activity ?? this.activity,
    followUpQuestions: followUpQuestions ?? this.followUpQuestions,
    forkAnchor: identical(forkAnchor, _sentinel)
        ? this.forkAnchor
        : forkAnchor as ForkRef?,
  );
```

文件顶部加：

```dart
class _Sentinel {}
const _sentinel = _Sentinel();
```

- [ ] **Step 4: 加 startFork + resume 方法**

在 `ChatNotifier` 的 `bootstrapRecommendations` 后追加：

```dart
  Future<void> startFork({
    required String sourceSessionId,
    required String professorId,
  }) async {
    final token = _beginOperation();
    final sub = _sub;
    _sub = null;
    _activeAssistantId = null;
    if (sub != null) unawaited(sub.cancel());
    _completeTurn();

    state = state.copyWith(
      sessionId: null,
      professorId: professorId,
      messages: const [],
      activity: ChatActivity.idle,
      forkAnchor: null,
    );

    final forkRes = await ref
        .read(chatRepositoryProvider)
        .forkSession(sourceSessionId: sourceSessionId, professorId: professorId);
    if (!_isCurrent(token)) return;

    switch (forkRes) {
      case Success<String>(:final data):
        final forkId = data;
        final historyRes =
            await ref.read(chatRepositoryProvider).loadHistory(sessionId: forkId);
        if (!_isCurrent(token)) return;
        final msgs = historyRes is Success<List<ChatMessage>>
            ? historyRes.data
            : const <ChatMessage>[];
        final forksRes = await ref
            .read(chatRepositoryProvider)
            .listForks(mainSessionId: sourceSessionId);
        ForkRef? anchor;
        if (forksRes is Success<List<ForkRef>>) {
          anchor = forksRes.data
              .cast<ForkRef?>()
              .firstWhere((f) => f?.forkId == forkId, orElse: () => null);
        }
        _seq = msgs.length;
        state = ChatState(
          sessionId: forkId,
          professorId: professorId,
          messages: msgs,
          activity: ChatActivity.idle,
          followUpQuestions: const [],
          forkAnchor: anchor,
        );
        unawaited(_refreshQuickActions(followUp: '', token: token));
      case Failure<String>():
        state = state.copyWith(activity: ChatActivity.idle);
    }
  }

  Future<void> resume({
    required String sessionId,
    required bool isFork,
  }) async {
    final token = _beginOperation();
    final sub = _sub;
    _sub = null;
    if (sub != null) unawaited(sub.cancel());
    _completeTurn();

    final historyRes =
        await ref.read(chatRepositoryProvider).loadHistory(sessionId: sessionId);
    if (!_isCurrent(token)) return;
    final msgs = historyRes is Success<List<ChatMessage>>
        ? historyRes.data
        : const <ChatMessage>[];
    ForkRef? anchor;
    if (isFork) {
      final forksRes =
          await ref.read(chatRepositoryProvider).listForks(mainSessionId: '');
      // fid 形如 f_<mainSid>_<pid>，反解 mainSid
      final mainSid = sessionId.startsWith('f_')
          ? sessionId.substring(2).split('_').first
          : '';
      final forksRes2 = await ref
          .read(chatRepositoryProvider)
          .listForks(mainSessionId: mainSid);
      if (forksRes2 is Success<List<ForkRef>>) {
        anchor = forksRes2.data
            .cast<ForkRef?>()
            .firstWhere((f) => f?.forkId == sessionId, orElse: () => null);
      }
    }
    _seq = msgs.length;
    state = ChatState(
      sessionId: sessionId,
      professorId: anchor?.professorId,
      messages: msgs,
      activity: ChatActivity.idle,
      followUpQuestions: const [],
      forkAnchor: anchor,
    );
    unawaited(_refreshQuickActions(followUp: '', token: token));
  }
```

> 注：`resume` 内有一处冗余 listForks 调用，实现时精简为一次。

- [ ] **Step 5: send 拦截 fork 再产卡**

在 `send` 方法里，`if (needsRecommendations) {` 分支开头加 fork 拦截：

```dart
    if (needsRecommendations) {
      if (state.forkAnchor != null) {
        await _emitForkReroute(content, token: token);
        return;
      }
      final placeholderId = _nextId();
      // ... 现有产卡逻辑不变
```

新增 `_emitForkReroute` 方法（放 `_streamConversation` 前）：

```dart
  Future<void> _emitForkReroute(String userPrompt, {required int token}) async {
    if (!_isCurrent(token)) return;
    final anchor = state.forkAnchor;
    final name = anchor?.professorName ?? '这位导师';
    final msg = ChatMessage(
      id: _nextId(),
      role: ChatRole.assistant,
      content: '这里咱们专注聊$name教授。想看新的导师推荐，回首页重挑一组吧～',
      createdAt: DateTime.now(),
      relatedRecommendations: const [],
      status: ChatMessageStatus.done,
      kind: ChatMessageKind.forkReroute,
    );
    state = state.copyWith(
      messages: [...state.messages, msg],
      activity: ChatActivity.idle,
    );
  }
```

import 顶部加 `import '../../../domain/entities/fork_ref.dart';`（已在 chat_provider 用到 ForkRef）。

- [ ] **Step 6: 跑测试确认通过**

Run: `flutter test test/features/chat/chat_fork_test.dart`
Expected: PASS

- [ ] **Step 7: 跑现有 chat 测试无回归**

Run: `flutter test test/features/chat/`
Expected: PASS（`canRegenerate` 检查 `kind == conversation`，forkReroute 自然被排除；现有测试不涉及 fork）。

- [ ] **Step 8: 跑 analyze**

Run: `flutter analyze lib/features/chat/providers/`
Expected: No issues.

- [ ] **Step 9: Commit**

```bash
git add lib/features/chat/providers/chat_provider.dart test/features/chat/chat_fork_test.dart
git commit -m "feat(chat): ChatState.forkAnchor + startFork/resume + fork 内再产卡拦截重路由"
```

---

## Task 8: ProfessorAnchorBar widget

**Files:**
- Create: `lib/features/chat/widgets/professor_anchor_bar.dart`
- Test: `test/features/chat/professor_anchor_bar_test.dart`

**Interfaces:**
- Consumes: `ForkRef`
- Produces: `ProfessorAnchorBar` widget（sticky 顶部教授条）。

- [ ] **Step 1: 写失败测试**

`test/features/chat/professor_anchor_bar_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:scho_navi/features/chat/widgets/professor_anchor_bar.dart';

ForkRef _ref() => ForkRef(
      forkId: 'f_s1_p1',
      mainSessionId: 's1',
      professorId: 'p1',
      professorName: '李卫国',
      university: '清华大学',
      college: '计算机系',
      createdAt: DateTime(2026, 6, 27),
    );

void main() {
  testWidgets('渲染头像姓氏 + 姓名 + 学校', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfessorAnchorBar(anchor: _ref(), onTap: () {}),
      ),
    ));
    expect(find.text('李'), findsOneWidget);
    expect(find.text('李卫国 教授'), findsOneWidget);
    expect(find.text('清华大学 · 计算机系'), findsOneWidget);
    expect(find.text('追问中'), findsOneWidget);
  });

  testWidgets('点击触发 onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfessorAnchorBar(anchor: _ref(), onTap: () => tapped = true),
      ),
    ));
    await tester.tap(find.byType(ProfessorAnchorBar));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/chat/professor_anchor_bar_test.dart`
Expected: FAIL — widget 不存在。

- [ ] **Step 3: 写 widget**

`lib/features/chat/widgets/professor_anchor_bar.dart`：

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/fork_ref.dart';

/// fork 追问页顶部常驻的教授锚点条（方案 A，sticky）。
///
/// 仅在 [ChatState.forkAnchor] 非 null 时渲染。点击回详情页。
class ProfessorAnchorBar extends StatelessWidget {
  const ProfessorAnchorBar({
    super.key,
    required this.anchor,
    required this.onTap,
  });

  final ForkRef anchor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle =
        anchor.college == null || anchor.college!.isEmpty
            ? anchor.university
            : '${anchor.university} · ${anchor.college}';
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.indigo,
                child: Text(
                  anchor.avatarLabel,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${anchor.professorName} 教授',
                      style: textTheme.titleSmall,
                    ),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '追问中',
                  style: textTheme.labelSmall?.copyWith(color: AppColors.indigo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

> 注：`AppColors.indigo` 确认存在（home_page/professor_page 已用）。`titleSmall`/`bodySmall`/`labelSmall` 为 Material 默认 TextTheme 字段，可用。

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/chat/professor_anchor_bar_test.dart`
Expected: PASS

- [ ] **Step 5: 跑 analyze**

Run: `flutter analyze lib/features/chat/widgets/professor_anchor_bar.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/widgets/professor_anchor_bar.dart test/features/chat/professor_anchor_bar_test.dart
git commit -m "feat(chat): ProfessorAnchorBar sticky 教授锚点条"
```

---

## Task 9: ChatMessageBubble 重路由双选项渲染

**Files:**
- Modify: `lib/features/chat/widgets/chat_message_bubble.dart`
- Test: `test/features/chat/chat_message_bubble_reroute_test.dart`

**Interfaces:**
- Consumes: `ChatMessageKind.forkReroute`
- Produces: `ChatMessageBubble` 新增 `onRerouteHome` 回调，forkReroute 消息渲染双选项按钮。

- [ ] **Step 1: 写失败测试**

`test/features/chat/chat_message_bubble_reroute_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/features/chat/widgets/chat_message_bubble.dart';

ChatMessage _reroute() => ChatMessage(
      id: 'r1',
      role: ChatRole.assistant,
      content: '这里咱们专注聊李卫国教授。想看新的导师推荐，回首页重挑一组吧～',
      createdAt: DateTime(2026, 6, 27),
      relatedRecommendations: const [],
      status: ChatMessageStatus.done,
      kind: ChatMessageKind.forkReroute,
    );

void main() {
  testWidgets('forkReroute 渲染双选项按钮', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatMessageBubble(
          message: _reroute(),
          onTapRecommendation: (_) {},
          onRerouteHome: () {},
        ),
      ),
    ));
    expect(find.textContaining('专注聊'), findsOneWidget);
    expect(find.text('继续问李卫国'), findsOneWidget);
    expect(find.textContaining('回首页重挑'), findsOneWidget);
  });

  testWidgets('点回首页触发 onRerouteHome', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatMessageBubble(
          message: _reroute(),
          onTapRecommendation: (_) {},
          onRerouteHome: () => tapped = true,
        ),
      ),
    ));
    await tester.tap(find.textContaining('回首页重挑'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/chat/chat_message_bubble_reroute_test.dart`
Expected: FAIL — `onRerouteHome` 参数不存在。

- [ ] **Step 3: 改 ChatMessageBubble**

`lib/features/chat/widgets/chat_message_bubble.dart`，构造加参数：

```dart
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.onTapRecommendation,
    this.onOpenHomepage,
    this.onRetryRecommendation,
    this.onRegenerate,
    this.onFeedback,
    this.onRerouteHome,
  });

  final void Function(String professorId) onTapRecommendation;
  final void Function(Recommendation recommendation)? onOpenHomepage;
  final void Function(String messageId)? onRetryRecommendation;
  final void Function(String messageId)? onRegenerate;
  final void Function(String messageId, ChatMessageFeedback feedback)? onFeedback;
  final VoidCallback? onRerouteHome;
```

在 `build` 返回的 `Column` children 末尾（`_showActions` 块后）加：

```dart
        if (message.kind == ChatMessageKind.forkReroute &&
            message.status == ChatMessageStatus.done &&
            onRerouteHome != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('继续问这位'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onRerouteHome,
                    child: const Text('回首页重挑 ›'),
                  ),
                ),
              ],
            ),
          ),
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/chat/chat_message_bubble_reroute_test.dart`
Expected: PASS

- [ ] **Step 5: 跑现有 chat_message_bubble_test 无回归**

Run: `flutter test test/features/chat/chat_message_bubble_test.dart`
Expected: PASS（新参数可选，既有构造不传 onRerouteHome 不受影响）。

- [ ] **Step 6: 跑 analyze**

Run: `flutter analyze lib/features/chat/widgets/chat_message_bubble.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/chat/widgets/chat_message_bubble.dart test/features/chat/chat_message_bubble_reroute_test.dart
git commit -m "feat(chat): ChatMessageBubble forkReroute 双选项渲染"
```

---

## Task 10: 路由 + ChatPage fork 分发 + 锚点条挂载

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/chat/pages/chat_page.dart`
- Test: `test/core/router/chat_route_test.dart`（更新）、`test/features/chat/chat_page_fork_test.dart`（新增）

**Interfaces:**
- Consumes: `ChatNotifier.startFork/resume`、`ProfessorAnchorBar`
- Produces: `/chat?fork&msid=&pid=`、`/chat?fork&fid=` 路由解析；ChatPage fork 分发 + 锚点条。

- [ ] **Step 1: 更新路由测试**

`test/core/router/chat_route_test.dart`，在现有断言基础上加（若文件已有 `/chat?sid=` 测试则保留，新增 fork 用例）：

```dart
    test('/chat?fork&msid=&pid= 解析 fork 参数', () {
      router.go('/chat?fork&msid=s1&pid=p1');
      // 断言 ChatPage 挂载（参考现有 sid 测试的断言风格）
      expect(find.byType(ChatPage), findsOneWidget);
    });
```

- [ ] **Step 2: 跑测试确认失败/行为**

Run: `flutter test test/core/router/chat_route_test.dart`
Expected: 当前可能 PASS（路由仅透传 query，ChatPage 接收）。若 fork 参数未解析则补。

- [ ] **Step 3: 改路由解析 fork 参数**

`lib/core/router/app_router.dart`，`/chat` 路由 builder：

```dart
      GoRoute(
        path: '/chat',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: ChatPage(
            sessionId: state.uri.queryParameters['sid'],
            professorId: state.uri.queryParameters['pid'],
            initialPrompt: state.uri.queryParameters['q'],
            forkMode: state.uri.queryParameters['fork'] == 'true',
            mainSessionId: state.uri.queryParameters['msid'],
            forkId: state.uri.queryParameters['fid'],
          ),
        ),
      ),
```

`/professor/:id` 路由透传 msid（ProfessorPage 加 `mainSessionId` 参数）：

```dart
      GoRoute(
        path: '/professor/:id',
        pageBuilder: (_, state) => sharedAxisPage(
          state: state,
          child: ProfessorPage(
            professorId: state.pathParameters['id']!,
            mainSessionId: state.uri.queryParameters['msid'],
          ),
        ),
      ),
```

- [ ] **Step 4: 改 ChatPage 分发 + 锚点条**

`lib/features/chat/pages/chat_page.dart`，构造加参数：

```dart
  const ChatPage({
    super.key,
    this.sessionId,
    this.professorId,
    this.initialPrompt,
    this.forkMode = false,
    this.mainSessionId,
    this.forkId,
  });

  final String? sessionId;
  final String? professorId;
  final String? initialPrompt;
  final bool forkMode;
  final String? mainSessionId;
  final String? forkId;
```

`initState` 的 `addPostFrameCallback` 内分发：

```dart
      if (_configurationBlocked) return;
      final notifier = ref.read(_provider.notifier);
      if (widget.forkMode && widget.forkId != null) {
        await notifier.resume(sessionId: widget.forkId!, isFork: true);
        return;
      }
      if (widget.forkMode) {
        await notifier.startFork(
          sourceSessionId: widget.mainSessionId ?? '',
          professorId: widget.professorId ?? '',
        );
        return;
      }
      final sessionId = widget.sessionId?.trim();
      notifier.start(
        sessionId: sessionId == null || sessionId.isEmpty
            ? _newSessionId()
            : sessionId,
        professorId: widget.professorId,
      );
      if (widget.initialPrompt != null &&
          widget.initialPrompt!.trim().isNotEmpty) {
        notifier.bootstrapRecommendations(widget.initialPrompt!);
      }
```

> 注：`initState` 内 `await` 需包在 async——把 callback 改为 `() async { ... }`。

锚点条挂载：在 `build` 的 `Stack` children 里、`CoolScaffoldBackground` 之后、`SafeArea` 之前或 Column 顶部加（sticky 常驻）：

```dart
          if (state.forkAnchor != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: ProfessorAnchorBar(
                  anchor: state.forkAnchor!,
                  onTap: () => context.push(
                      '/professor/${state.forkAnchor!.professorId}'),
                ),
              ),
            ),
```

import 加 `import '../widgets/professor_anchor_bar.dart';`。`ListView` 顶部 padding 加避让（fork 模式下 `padding: EdgeInsets.fromLTRB(20, 108, 20, 12)` 让出锚点条高度；非 fork 维持 56）——用 `state.forkAnchor != null ? 108.0 : 56.0`。

`ChatMessageBubble` 调用处加 `onRerouteHome`：

```dart
                            onRerouteHome: () => context.go('/home'),
```

- [ ] **Step 5: 写 ChatPage fork 测试**

`test/features/chat/chat_page_fork_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/features/chat/pages/chat_page.dart';
import 'package:scho_navi/features/chat/widgets/professor_anchor_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('fork 模式渲染锚点条', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = MockChatRepository(MockDb(),
        historyStore: LocalChatHistoryStore(_MemStore()));
    // 预置 fork
    await repo.seedRecommendationTurn(
      sessionId: 's1',
      userPrompt: '想做CV',
      result: /* 构造一个非空 RecommendationResult，含 db 第一位教授 */,
    );
    await repo.forkSession(sourceSessionId: 's1', professorId: MockDb().professors.first.id);

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(
        path: '/chat',
        builder: (_, __) => UncontrolledProviderScope(
          container: container,
          child: const ChatPage(forkMode: true, mainSessionId: 's1', professorId: /* first prof id */),
        ),
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(ProfessorAnchorBar), findsOneWidget);
  });
}
```

> 注：`_MemStore` 同前 task。`/* ... */` 处需补真实值，参考前 task 测试构造。

- [ ] **Step 6: 跑测试确认通过**

Run: `flutter test test/features/chat/chat_page_fork_test.dart test/core/router/chat_route_test.dart`
Expected: PASS

- [ ] **Step 7: 跑 analyze + 现有 chat_page_test 无回归**

Run: `flutter analyze lib/features/chat/pages/chat_page.dart lib/core/router/app_router.dart`
Run: `flutter test test/features/chat/chat_page_test.dart`
Expected: analyze No issues；测试全绿。

- [ ] **Step 8: Commit**

```bash
git add lib/core/router/app_router.dart lib/features/chat/pages/chat_page.dart test/core/router/chat_route_test.dart test/features/chat/chat_page_fork_test.dart
git commit -m "feat(chat): 路由 fork 参数 + ChatPage 分发 + 锚点条挂载"
```

---

## Task 11: 入口接线（详情页 FAB + 首页透传 msid + 推荐页移除 FAB）

**Files:**
- Modify: `lib/features/professor/pages/professor_page.dart`
- Modify: `lib/features/home/pages/home_page.dart`
- Modify: `lib/features/recommendation/pages/recommendation_page.dart`
- Test: `test/features/chat/chat_entry_points_test.dart`（更新）

**Interfaces:**
- Consumes: `/chat?fork&msid=&pid=` 路由、`/professor/:id?msid=` 透传
- Produces: 详情页 FAB fork、首页卡片透传 msid、推荐页 FAB 移除。

- [ ] **Step 1: 更新入口测试**

`test/features/chat/chat_entry_points_test.dart`，把详情页「继续追问」断言改为 fork 参数：

```dart
  testWidgets('详情页「继续追问」fork 跳 /chat 携带 msid+pid', (tester) async {
    // 参考现有 chat_entry_points_test 构造详情页
    await tester.tap(find.text('继续追问'));
    await tester.pumpAndSettle();
    // 断言路由跳转到 /chat?fork&msid=...&pid=...
  });

  testWidgets('推荐页不再有「继续追问」FAB', (tester) async {
    // 构造推荐页，断言 find.text('继续追问') findsNothing
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/chat/chat_entry_points_test.dart`
Expected: FAIL——详情页 FAB 参数未改、推荐页 FAB 仍在。

- [ ] **Step 3: 详情页 FAB 改 fork + ProfessorPage 加 mainSessionId**

`lib/features/professor/pages/professor_page.dart`，构造加参数：

```dart
class ProfessorPage extends ConsumerWidget {
  const ProfessorPage({super.key, required this.professorId, this.mainSessionId});
  final String professorId;
  final String? mainSessionId;
```

`floatingActionButton` 的 `onPressed`：

```dart
        onPressed: () => context.push(
          '/chat?fork=true&msid=${Uri.encodeComponent(mainSessionId ?? '')}'
          '&pid=${Uri.encodeComponent(p.id)}',
        ),
```

- [ ] **Step 4: 首页卡片点击透传 msid**

`lib/features/home/pages/home_page.dart`，卡片 `onTapRecommendation`：

```dart
                  onTapRecommendation: (id) {
                    final mainSid = ref.read(_chatProvider).sessionId ?? '';
                    context.push('/professor/$id?msid=${Uri.encodeComponent(mainSid)}');
                  },
```

（原 `(id) => context.push('/professor/$id')` 改为上述。）

- [ ] **Step 5: 推荐页移除 FAB**

`lib/features/recommendation/pages/recommendation_page.dart`，删掉 `floatingActionButton` 整段（第 34-45 行的 `floatingActionButton: async.maybeWhen(...)`），改为 `floatingActionButton: null` 或直接删除该属性。

- [ ] **Step 6: 跑测试确认通过**

Run: `flutter test test/features/chat/chat_entry_points_test.dart`
Expected: PASS

- [ ] **Step 7: 跑 analyze + 回归**

Run: `flutter analyze lib/features/professor/ lib/features/home/ lib/features/recommendation/`
Run: `flutter test test/features/home/ test/features/professor/ test/features/chat/`
Expected: analyze No issues；测试全绿。

- [ ] **Step 8: Commit**

```bash
git add lib/features/professor/pages/professor_page.dart lib/features/home/pages/home_page.dart lib/features/recommendation/pages/recommendation_page.dart test/features/chat/chat_entry_points_test.dart
git commit -m "feat(chat): 入口接线 fork（详情页）+ 透传 msid（首页）+ 移除推荐页 FAB"
```

---

## Task 12: 历史页折叠展开 v3

**Files:**
- Modify: `lib/features/history/pages/history_page.dart`
- Test: `test/features/history/history_tile_fork_test.dart`

**Interfaces:**
- Consumes: `ChatRepository.listForks/deleteFork`、`ForkRef`、`/chat?fork&fid=` 路由
- Produces: `_HistoryTile` 改有状态折叠展开（加号旋转 + 子项 + 空状态 + 级联删除）。

- [ ] **Step 1: 写失败测试**

`test/features/history/history_tile_fork_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/search_history_item.dart';
import 'package:scho_navi/features/history/pages/history_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('主条目仅标题 + 加号，点击展开子项', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = MockChatRepository(MockDb(),
        historyStore: LocalChatHistoryStore(_MemStore()));
    await repo.seedRecommendationTurn(
      sessionId: 's1', userPrompt: '想做CV', result: /* 非空 result */);
    await repo.forkSession(
        sourceSessionId: 's1', professorId: MockDb().professors.first.id);

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      historyRepositoryProvider.overrideWithValue(_FakeHistoryRepo([
        SearchHistoryItem(
          sessionId: 's1', prompt: '想做CV，想去北京',
          createdAt: DateTime(2026, 6, 27),
          summary: '', researchInterests: const [],
          preferredLocations: const [], recommendationCount: 4,
        ),
      ])),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('想做CV，想去北京'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget); // 加号
    // 无摘要句
    expect(find.textContaining('为你挑了'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    // 展开后子项
    expect(find.text(MockDb().professors.first.name), findsOneWidget);
  });

  testWidgets('无 fork 展开显示「暂无追问历史」', (tester) async {
    // 同上构造，但不 fork
    // ...
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('暂无追问历史'), findsOneWidget);
  });
}

GoRouter _router() => GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const HistoryPage()),
      GoRoute(path: '/chat', builder: (_, __) => const SizedBox()),
    ]);

class _FakeHistoryRepo implements HistoryRepository {
  // 实现必要方法，watch() 返回 Stream.fromIterable([items])
  // ...
}

class _MemStore implements scho_navi.LocalStore { /* 同前 */ }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/history/history_tile_fork_test.dart`
Expected: FAIL——`_HistoryTile` 仍是 ConsumerWidget 无展开、加号不存在。

- [ ] **Step 3: 改 _HistoryTile 为有状态折叠展开**

`lib/features/history/pages/history_page.dart`：

顶部 import 加：

```dart
import '../../../domain/entities/fork_ref.dart';
import '../../../core/di/providers.dart';
```

把 `_HistoryTile` 从 `ConsumerWidget` 改为 `ConsumerStatefulWidget`：

```dart
class _HistoryTile extends ConsumerStatefulWidget {
  const _HistoryTile({required this.item});
  final SearchHistoryItem item;
  @override
  ConsumerState<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends ConsumerState<_HistoryTile> {
  bool _expanded = false;
  List<ForkRef>? _forks;
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && _forks == null && !_loading) {
      setState(() => _loading = true);
      final res = await ref
          .read(chatRepositoryProvider)
          .listForks(mainSessionId: widget.item.sessionId);
      if (mounted) {
        setState(() {
          _forks = res is Success<List<ForkRef>> ? res.data : const [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.prompt,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.add, size: 18, color: Color(0xFF6A6385)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildForks(),
          ),
        ],
      ),
    );
  }

  Widget _buildForks() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final forks = _forks ?? const <ForkRef>[];
    if (forks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Text('暂无追问历史',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          const Divider(height: 1),
          for (final f in forks) _ForkSubTile(fork: f, item: widget.item),
        ],
      ),
    );
  }
}
```

新增 `_ForkSubTile`：

```dart
class _ForkSubTile extends ConsumerWidget {
  const _ForkSubTile({required this.fork, required this.item});
  final ForkRef fork;
  final SearchHistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = (fork.college == null || fork.college!.isEmpty)
        ? fork.university
        : '${fork.university} · ${fork.college}';
    return Dismissible(
      key: ValueKey(fork.forkId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(chatRepositoryProvider).deleteFork(forkId: fork.forkId);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除追问')));
      },
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.indigo,
          child: Text(fork.avatarLabel,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        title: Text(fork.professorName, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: textTheme.bodySmall),
        trailing: Text(_formatTime(fork.createdAt), style: textTheme.bodySmall),
        onTap: () => context.push('/chat?fork=true&fid=${Uri.encodeComponent(fork.forkId)}'),
      ),
    );
  }
}

String _formatTime(DateTime v) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(v.hour)}:${two(v.minute)}';
}
```

import 加 `import '../../../core/theme/app_colors.dart';`。

`_HistoryTile` 原主条目内的删除 IconButton（删除主历史）保留，但点击时改为级联删 fork：

原 `onPressed: () => ref.read(historyRepositoryProvider).remove(item.sessionId)` 改为：

```dart
                    onPressed: () async {
                      // 级联删 fork
                      final forksRes = await ref
                          .read(chatRepositoryProvider)
                          .listForks(mainSessionId: item.sessionId);
                      if (forksRes is Success<List<ForkRef>>) {
                        for (final f in forksRes.data) {
                          await ref.read(chatRepositoryProvider).deleteFork(forkId: f.forkId);
                        }
                      }
                      ref.read(historyRepositoryProvider).remove(item.sessionId);
                    },
```

> 注：原 `_HistoryTile` 顶部的 Dismissible（主条目左滑删）`onDismissed` 也需加同样级联逻辑。

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/features/history/history_tile_fork_test.dart`
Expected: PASS

- [ ] **Step 5: 跑 analyze + 现有历史测试无回归**

Run: `flutter analyze lib/features/history/`
Run: `flutter test test/features/history/`
Expected: analyze No issues；测试全绿。

- [ ] **Step 6: Commit**

```bash
git add lib/features/history/pages/history_page.dart test/features/history/history_tile_fork_test.dart
git commit -m "feat(history): 折叠展开 v3（加号旋转+子项+空状态+级联删除）"
```

---

## Task 13: 全量回归 + analyze

**Files:** 无（验证 task）

- [ ] **Step 1: 跑全量测试**

Run: `flutter test`
Expected: 全绿（基线 ~442 + 新增 fork 相关测试）。

- [ ] **Step 2: 跑全量 analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 3: 冒烟（可选，需 DeepSeek key）**

Run: `flutter run --dart-define=LLM_API_KEY=...`
手动验证：
- 首页输入「想做CV，想去北京」→ 产卡 → 点横滑卡进详情页 → 「继续追问」→ 进 fork 追问页，顶部出现教授锚点条，历史回填（含主对话上下文）。
- 追问「为什么推荐他」→ 流式回答含该导师（接地）。
- 追问「换一批」→ 出现 forkReroute 双选项，点「回首页重挑」回首页。
- 回首页 → 历史页 → 主条目加号点击展开 → 看到子项（导师头像+姓名+学校）→ 点子项恢复 fork 对话 → 可继续追问。
- 无 fork 的主条目展开显示「暂无追问历史」。
- 主条目左滑删 → 其下 fork 一并删除。

- [ ] **Step 4: 更新 memory**

更新 `C:\Users\xc150\.claude\projects\d--Androidprj-AIGC-LXJH-scho-navi\memory\` 下相关 memory（`schonavi-conversational-recommendation.md` 追加 fork 章节，或新建 `schonavi-chat-fork-session.md` + 更新 MEMORY.md 索引）。

- [ ] **Step 5: Commit**

```bash
git add <memory files 若在 repo 内> 
git commit -m "docs(memory): fork 式追问会话实现记录"
```

> 若 memory 在 repo 外（用户 home 目录），跳过此 commit。

---

## Self-Review 结果

**1. Spec coverage**：
- §1-§3 架构/数据模型/仓储 → Task 1-6 ✓
- §4 ChatNotifier/路由 → Task 7, 10 ✓
- §5 历史页 → Task 12 ✓
- §6 待决（forkId 去重、再产卡拦截、主 sid 透传、推荐页移除）→ Task 5/6/7/10/11 ✓
- §7 UI（锚点条、重路由双选项）→ Task 8, 9 ✓
- §8 错误处理 → Task 5/7/12 内 Failure 分支 ✓
- §9 测试策略 → 各 task 测试 ✓
- §11 影响文件 → 全覆盖 ✓

**2. Placeholder scan**：Task 5/10/12 测试中有 `/* 非空 result */`、`/* first prof id */`、`/* ... */` 注释占位——这些是「按前 task 测试构造补真实值」的指引，已给出参考来源，非空 placeholder。`_FakeHistoryRepo` 的 `// ...` 同理（实现必要方法）。已尽量给真实代码；个别构造复杂处标注参考来源。

**3. Type consistency**：
- `forkSession` 返回 `Future<Result<String>>`（Task 3 定义，Task 5/6/7 使用一致）✓
- `loadHistory` 返回 `Future<Result<List<ChatMessage>>>` ✓
- `listForks` 返回 `Future<Result<List<ForkRef>>>` ✓
- `deleteFork` 返回 `Future<Result<void>>` ✓
- `ChatState.forkAnchor` 类型 `ForkRef?`（Task 7 定义，Task 10 使用一致）✓
- `ProfessorAnchorBar` 参数 `anchor: ForkRef`（Task 8 定义，Task 10 使用一致）✓
- `ChatMessage.kind` 含 `forkReroute`（Task 2 定义，Task 7/9 使用一致）✓
- `resume` 方法内冗余 listForks 调用已在 Step 4 标注精简 ✓

**注意事项**（实现时关注）：
- Task 5 的 `streamReply`/`seedRecommendationTurn` 持久化改动较复杂，实现时保持现有测试（ai_chat_repository_test）通过为前提，增量持久化。
- Task 6 全局 `MockChatRepository(` 构造点需逐一补 `historyStore`，可能涉及多个测试文件。
- Task 7 `resume` 的 mainSid 反解依赖 forkId 格式 `f_<mainSid>_<pid>`，若 mainSid 含 `_` 会反解错——实现时考虑用 store 的 findFork 替代字符串反解（更稳）。建议实现时改为：`listForks` 所有 → find forkId 匹配 → 取其 mainSessionId。Task 7 Step 4 已留冗余调用供此优化。
- 各 `_MemStore` 测试 helper 重复出现 4 次，实现时若 review 建议可抽 `test/helpers/mem_local_store.dart` 公共 helper（YAGNI，本次保留重复）。
