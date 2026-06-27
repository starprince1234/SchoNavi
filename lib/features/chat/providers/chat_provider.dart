import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../domain/entities/fork_ref.dart';
import '../../../domain/entities/query_understanding.dart';
import '../../../domain/entities/recommendation_result.dart';
import '../../profile/providers/profile_provider.dart';
import '../widgets/chat_quick_actions.dart' show defaultChatQuickActions;

enum ChatActivity { idle, recommending, classifying, streaming }

class _Sentinel {
  const _Sentinel();
}

const _sentinel = _Sentinel();

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

  bool get isBusy => activity != ChatActivity.idle;

  /// 兼容既有 UI/测试命名；现在分类和推荐请求也属于响应中。
  bool get isResponding => isBusy;

  bool get canRegenerate {
    if (isBusy || messages.length < 2) return false;
    final assistant = messages.last;
    final user = messages[messages.length - 2];
    return assistant.role == ChatRole.assistant &&
        assistant.kind == ChatMessageKind.conversation &&
        user.role == ChatRole.user;
  }

  /// [forkAnchor] 用 sentinel 区分「未传」与「显式置 null」，
  /// 因 ForkRef 本身可空，直接 `?? this.forkAnchor` 无法清空锚点。
  /// [professorId] 同样支持显式置 null，避免失败分支留下过期导师绑定。
  ChatState copyWith({
    String? sessionId,
    Object? professorId = _sentinel,
    List<ChatMessage>? messages,
    ChatActivity? activity,
    List<String>? followUpQuestions,
    Object? forkAnchor = _sentinel,
  }) => ChatState(
    sessionId: sessionId ?? this.sessionId,
    professorId: identical(professorId, _sentinel)
        ? this.professorId
        : professorId as String?,
    messages: messages ?? this.messages,
    activity: activity ?? this.activity,
    followUpQuestions: followUpQuestions ?? this.followUpQuestions,
    forkAnchor: identical(forkAnchor, _sentinel)
        ? this.forkAnchor
        : forkAnchor as ForkRef?,
  );
}

class ChatNotifier extends Notifier<ChatState> {
  int _seq = 0;
  int _operation = 0;
  StreamSubscription<String>? _sub;
  Completer<void>? _turn;
  String? _activeAssistantId;

  @override
  ChatState build() {
    ref.onDispose(() {
      _operation++;
      final sub = _sub;
      _sub = null;
      _completeTurn();
      if (sub != null) unawaited(sub.cancel());
    });
    return const ChatState.initial();
  }

  void start({required String sessionId, String? professorId}) {
    if (state.sessionId == sessionId && state.professorId == professorId) {
      return;
    }
    final token = _beginOperation();
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

  Future<void> bootstrapRecommendations(String initialPrompt) async {
    final prompt = initialPrompt.trim();
    if (prompt.isEmpty || state.isBusy || state.messages.isNotEmpty) return;

    final token = _beginOperation();
    final placeholderId = _nextId();
    state = state.copyWith(
      activity: ChatActivity.recommending,
      messages: [
        ChatMessage(
          id: _nextId(),
          role: ChatRole.user,
          content: prompt,
          createdAt: DateTime.now(),
          relatedRecommendations: const [],
          status: ChatMessageStatus.done,
        ),
        _recommendationPlaceholder(placeholderId),
      ],
    );
    await _requestRecommendations(
      prompt,
      token: token,
      placeholderId: placeholderId,
    );
  }

  /// 从 [sourceSessionId] fork 出新分支并载入其历史，绑死 [professorId]。
  ///
  /// 流程：forkSession 拿 forkId → loadHistory 回填消息 → listForks 找到
  /// 匹配 forkId 的 ForkRef 作为锚点。每次 await 后用 [_isCurrent] 丢弃过期回调。
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

    final repo = ref.read(chatRepositoryProvider);
    final forkRes = await repo.forkSession(
      sourceSessionId: sourceSessionId,
      professorId: professorId,
    );
    if (!_isCurrent(token)) return;

    switch (forkRes) {
      case Success<String>(:final data):
        final forkId = data;
        final historyRes = await repo.loadHistory(sessionId: forkId);
        if (!_isCurrent(token)) return;
        final msgs = historyRes is Success<List<ChatMessage>>
            ? historyRes.data
            : const <ChatMessage>[];
        final forksRes = await repo.listForks(mainSessionId: sourceSessionId);
        if (!_isCurrent(token)) return;
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
        if (!_isCurrent(token)) return;
        state = state.copyWith(
          activity: ChatActivity.idle,
          professorId: null,
          forkAnchor: null,
        );
    }
  }

  /// 恢复某 session 的历史。fork 模式下用 [mainSessionId] 经 listForks 重建锚点。
  ///
  /// [mainSessionId] 为 null/空 时 fork 锚点降级为 null（顶部条不显示，不崩溃）；
  /// 路由侧（Task 10）从历史页携带 msid 传入，避免从 `f_<mainSid>_<pid>` 反解
  /// mainSid（该格式在 mainSid 含 `_` 时有歧义）。
  Future<void> resume({
    required String sessionId,
    required bool isFork,
    String? mainSessionId,
  }) async {
    final token = _beginOperation();
    final sub = _sub;
    _sub = null;
    _activeAssistantId = null;
    if (sub != null) unawaited(sub.cancel());
    _completeTurn();

    final repo = ref.read(chatRepositoryProvider);
    final historyRes = await repo.loadHistory(sessionId: sessionId);
    if (!_isCurrent(token)) return;
    final msgs = historyRes is Success<List<ChatMessage>>
        ? historyRes.data
        : const <ChatMessage>[];

    ForkRef? anchor;
    String? professorId;
    if (isFork && mainSessionId != null && mainSessionId.isNotEmpty) {
      final forksRes = await repo.listForks(mainSessionId: mainSessionId);
      if (!_isCurrent(token)) return;
      if (forksRes is Success<List<ForkRef>>) {
        anchor = forksRes.data
            .cast<ForkRef?>()
            .firstWhere((f) => f?.forkId == sessionId, orElse: () => null);
        professorId = anchor?.professorId;
      }
    }

    _seq = msgs.length;
    state = ChatState(
      sessionId: sessionId,
      professorId: professorId,
      messages: msgs,
      activity: ChatActivity.idle,
      followUpQuestions: const [],
      forkAnchor: anchor,
    );
    unawaited(_refreshQuickActions(followUp: '', token: token));
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty ||
        state.sessionId == null ||
        state.sessionId!.isEmpty ||
        state.isBusy) {
      return;
    }

    final token = _beginOperation();
    final lastResult = _lastRecommendationResult();
    state = state.copyWith(
      activity: ChatActivity.classifying,
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

    var needsRecommendations = false;
    try {
      needsRecommendations = await ref
          .read(recommendationNeedClassifierProvider)
          .needRecommendations(content, lastResult: lastResult);
    } catch (_) {
      needsRecommendations = false;
    }
    if (!_isCurrent(token)) return;

    if (needsRecommendations) {
      if (state.forkAnchor != null) {
        await _emitForkReroute(content, token: token);
        return;
      }
      final placeholderId = _nextId();
      state = state.copyWith(
        activity: ChatActivity.recommending,
        messages: [
          ...state.messages,
          _recommendationPlaceholder(placeholderId),
        ],
      );
      await _requestRecommendations(
        content,
        token: token,
        placeholderId: placeholderId,
      );
      return;
    }

    await _streamConversation(content, token: token);
  }

  Future<void> retryRecommendation(String assistantMessageId) async {
    if (state.isBusy || state.messages.length < 2) return;
    final assistantIndex = state.messages.indexWhere(
      (message) => message.id == assistantMessageId,
    );
    if (assistantIndex != state.messages.length - 1) return;
    final assistant = state.messages[assistantIndex];
    final user = state.messages[assistantIndex - 1];
    if (assistant.kind != ChatMessageKind.recommendation ||
        assistant.status != ChatMessageStatus.error ||
        user.role != ChatRole.user) {
      return;
    }

    final token = _beginOperation();
    final placeholderId = _nextId();
    state = state.copyWith(
      messages: [
        ...state.messages.sublist(0, assistantIndex),
        _recommendationPlaceholder(placeholderId),
      ],
      activity: ChatActivity.recommending,
    );
    await _requestRecommendations(
      user.content,
      token: token,
      placeholderId: placeholderId,
    );
  }

  Future<void> regenerate() async {
    if (!state.canRegenerate) return;
    await regenerateMessage(state.messages.last.id);
  }

  Future<void> regenerateMessage(String assistantMessageId) async {
    if (!state.canRegenerate || state.messages.last.id != assistantMessageId) {
      return;
    }
    final user = state.messages[state.messages.length - 2];
    final token = _beginOperation();
    state = state.copyWith(
      messages: state.messages.sublist(0, state.messages.length - 1),
    );
    await _streamConversation(user.content, token: token);
  }

  void setFeedback(String messageId, ChatMessageFeedback feedback) {
    final messages = [...state.messages];
    final i = messages.indexWhere((message) => message.id == messageId);
    if (i == -1) return;

    final message = messages[i];
    if (message.role != ChatRole.assistant ||
        message.status != ChatMessageStatus.done) {
      return;
    }

    messages[i] = message.copyWith(feedback: feedback);
    state = state.copyWith(messages: messages);
  }

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

  Future<void> _requestRecommendations(
    String prompt, {
    required int token,
    required String placeholderId,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      _appendRecommendationError(
        token,
        const UnknownException().message,
        placeholderId: placeholderId,
      );
      return;
    }

    try {
      final result = await ref
          .read(recommendationRepositoryProvider)
          .getRecommendations(
            prompt: prompt,
            profile: ref.read(profileProvider),
            sessionId: sessionId,
          );
      if (!_isCurrent(token)) return;

      switch (result) {
        case Success<RecommendationResult>(:final data):
          final resolvedSessionId = data.sessionId.isEmpty
              ? sessionId
              : data.sessionId;
          await ref
              .read(chatRepositoryProvider)
              .seedRecommendationTurn(
                sessionId: resolvedSessionId,
                userPrompt: prompt,
                result: data,
              );
          final placeholder = state.messages.firstWhere(
            (m) => m.id == placeholderId,
            orElse: () => ChatMessage(
              id: placeholderId,
              role: ChatRole.assistant,
              content: '',
              createdAt: DateTime.now(),
              relatedRecommendations: const [],
              status: ChatMessageStatus.done,
              kind: ChatMessageKind.recommendation,
            ),
          );
          state = state.copyWith(
            sessionId: resolvedSessionId,
            activity: ChatActivity.idle,
            followUpQuestions: data.followUpQuestions,
            messages: [
              for (final m in state.messages)
                if (m.id == placeholderId)
                  placeholder.copyWith(
                    content: _openingLine(data),
                    relatedRecommendations: data.recommendations,
                    status: ChatMessageStatus.done,
                    kind: ChatMessageKind.recommendation,
                  )
                else
                  m,
            ],
          );
          unawaited(
            ref
                .read(historyRepositoryProvider)
                .addFromResult(prompt: prompt, result: data),
          );
        case Failure<RecommendationResult>(:final error):
          _appendRecommendationError(
            token,
            error.message,
            placeholderId: placeholderId,
          );
      }
    } catch (error) {
      _appendRecommendationError(
        token,
        _messageFor(error),
        placeholderId: placeholderId,
      );
    }
  }

  ChatMessage _recommendationPlaceholder(String id) => ChatMessage(
        id: id,
        role: ChatRole.assistant,
        content: '',
        createdAt: DateTime.now(),
        relatedRecommendations: const [],
        status: ChatMessageStatus.sending,
        kind: ChatMessageKind.recommendation,
      );

  void _appendRecommendationError(
    int token,
    String message, {
    required String placeholderId,
  }) {
    if (!_isCurrent(token)) return;
    state = state.copyWith(
      activity: ChatActivity.idle,
      messages: [
        for (final m in state.messages)
          if (m.id == placeholderId)
            ChatMessage(
              id: placeholderId,
              role: ChatRole.assistant,
              content: message,
              createdAt: m.createdAt,
              relatedRecommendations: const [],
              status: ChatMessageStatus.error,
              kind: ChatMessageKind.recommendation,
            )
          else
            m,
      ],
    );
  }

  /// fork 内识别到再推荐意图时不走产卡，而是发一条重路由提示消息，
  /// 引导用户回首页重挑一组导师。空推荐卡片、状态 done、不可重新生成。
  Future<void> _emitForkReroute(String userPrompt, {required int token}) async {
    // userPrompt 仅作为触发上下文，重路由文案不引用其内容。
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

  Future<void> _streamConversation(String content, {required int token}) async {
    if (!_isCurrent(token)) return;
    final placeholder = ChatMessage(
      id: _nextId(),
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      relatedRecommendations: const [],
      status: ChatMessageStatus.sending,
      kind: ChatMessageKind.conversation,
    );
    state = state.copyWith(
      messages: [...state.messages, placeholder],
      activity: ChatActivity.streaming,
    );

    final assistantId = placeholder.id;
    final buffer = StringBuffer();
    final turn = Completer<void>();
    _turn = turn;
    _activeAssistantId = assistantId;

    try {
      _sub = ref
          .read(chatRepositoryProvider)
          .streamReply(
            sessionId: state.sessionId!,
            message: content,
            professorId: state.professorId,
          )
          .listen(
            (delta) {
              if (!_isCurrent(token)) return;
              buffer.write(delta);
              _setAssistant(
                assistantId,
                buffer.toString(),
                ChatMessageStatus.streaming,
              );
            },
            onError: (Object error) {
              if (_isCurrent(token)) {
                final detail = _messageFor(error);
                final partial = buffer.toString();
                _setAssistant(
                  assistantId,
                  partial.isEmpty ? detail : '$partial\n\n生成中断：$detail',
                  ChatMessageStatus.error,
                );
                state = state.copyWith(activity: ChatActivity.idle);
              }
              _clearActiveTurn(turn: turn, assistantId: assistantId);
            },
            onDone: () {
              if (_isCurrent(token)) {
                _setAssistant(
                  assistantId,
                  buffer.toString(),
                  ChatMessageStatus.done,
                );
                state = state.copyWith(activity: ChatActivity.idle);
                unawaited(
                  _refreshQuickActions(followUp: content, token: token),
                );
              }
              _clearActiveTurn(turn: turn, assistantId: assistantId);
            },
            cancelOnError: true,
          );
    } catch (error) {
      if (_isCurrent(token)) {
        _setAssistant(assistantId, _messageFor(error), ChatMessageStatus.error);
        state = state.copyWith(activity: ChatActivity.idle);
      }
      _clearActiveTurn(turn: turn, assistantId: assistantId);
    }

    await turn.future;
  }

  Future<void> stop() async {
    if (state.activity != ChatActivity.streaming) return;

    _operation++;
    final assistantId = _activeAssistantId;
    final sub = _sub;
    _sub = null;
    _activeAssistantId = null;

    if (assistantId != null) {
      final i = state.messages.indexWhere(
        (message) => message.id == assistantId,
      );
      if (i != -1) {
        _setAssistant(
          assistantId,
          state.messages[i].content,
          ChatMessageStatus.done,
        );
      }
    }

    state = state.copyWith(activity: ChatActivity.idle);
    _completeTurn();
    if (sub != null) await sub.cancel();
  }

  void _setAssistant(String id, String content, ChatMessageStatus status) {
    final messages = [...state.messages];
    final i = messages.indexWhere((message) => message.id == id);
    if (i == -1) return;
    messages[i] = messages[i].copyWith(content: content, status: status);
    state = state.copyWith(messages: messages);
  }

  void _clearActiveTurn({
    required Completer<void> turn,
    required String assistantId,
  }) {
    if (_turn == turn && _activeAssistantId == assistantId) {
      _turn = null;
      _sub = null;
      _activeAssistantId = null;
    }
    if (!turn.isCompleted) turn.complete();
  }

  int _beginOperation() => ++_operation;

  bool _isCurrent(int token) => token == _operation;

  void _completeTurn() {
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
  }

  String _messageFor(Object error) =>
      error is AppException ? error.message : const UnknownException().message;

  String _nextId() => 'm_${_seq++}';

  String _openingLine(RecommendationResult result) {
    final count = result.recommendations.length;
    if (count == 0) {
      return '暂未找到完全符合条件的导师，可尝试放宽学校、地区或研究方向限制。';
    }
    final interests = result.queryUnderstanding.researchInterests;
    final locations = result.queryUnderstanding.preferredLocations;
    final parts = <String>[
      if (interests.isNotEmpty) '关注${interests.join('、')}',
      if (locations.isNotEmpty) '偏好${locations.join('、')}',
    ];
    final understood = parts.isEmpty ? '' : '我理解你${parts.join('、')}。';
    return '$understood为你挑了 $count 位合适的导师，可左右滑动查看：';
  }

  RecommendationResult? _lastRecommendationResult() {
    for (final message in state.messages.reversed) {
      if (message.role == ChatRole.assistant &&
          message.relatedRecommendations.isNotEmpty) {
        return RecommendationResult(
          sessionId: state.sessionId ?? '',
          queryUnderstanding: const QueryUnderstanding(
            researchInterests: [],
            preferredLocations: [],
            preferredUniversities: [],
            uncertainties: [],
          ),
          recommendations: message.relatedRecommendations,
          followUpQuestions: state.followUpQuestions,
        );
      }
    }
    return null;
  }
}

/// 每个 ChatPage 用自己的作用域对象读取一个实例，页面退出后自动释放。
final chatProvider = NotifierProvider.autoDispose
    .family<ChatNotifier, ChatState, Object>((_) => ChatNotifier());
