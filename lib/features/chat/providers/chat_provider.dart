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
  String? _activeAssistantId;

  @override
  ChatState build() {
    ref.onDispose(() {
      final sub = _sub;
      if (sub != null) unawaited(sub.cancel());
    });
    return const ChatState.initial();
  }

  void start({required String sessionId, String? professorId}) {
    if (state.sessionId == sessionId && state.professorId == professorId) {
      return;
    }
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

    await _respondTo(content);
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
    await _respondTo(lastUserText);
  }

  Future<void> regenerateMessage(String assistantMessageId) async {
    if (state.isResponding || state.sessionId == null) return;

    final messages = state.messages;
    final assistantIndex = messages.indexWhere((m) => m.id == assistantMessageId);
    if (assistantIndex == -1) return;

    final lastUserIndex = messages.lastIndexWhere(
      (m) => m.role == ChatRole.user,
      assistantIndex - 1,
    );
    if (lastUserIndex == -1) return;

    final lastUserText = messages[lastUserIndex].content;
    state = state.copyWith(messages: messages.sublist(0, lastUserIndex + 1));
    await _respondTo(lastUserText);
  }

  void setFeedback(String messageId, ChatMessageFeedback feedback) {
    final messages = [...state.messages];
    final i = messages.indexWhere((m) => m.id == messageId);
    if (i == -1) return;

    final message = messages[i];
    if (message.role != ChatRole.assistant || message.status != ChatMessageStatus.done) {
      return;
    }

    messages[i] = message.copyWith(feedback: feedback);
    state = state.copyWith(messages: messages);
  }

  Future<void> _respondTo(String content) async {
    final placeholder = ChatMessage(
      id: _nextId(),
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      relatedRecommendations: const [],
      status: ChatMessageStatus.sending,
    );
    state = state.copyWith(
      messages: [...state.messages, placeholder],
      isResponding: true,
    );

    final assistantId = placeholder.id;
    final buffer = StringBuffer();
    final turn = Completer<void>();
    _turn = turn;
    _activeAssistantId = assistantId;

    try {
      _sub =
          ref
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
                  _activeAssistantId = null;
                  state = state.copyWith(isResponding: false);
                  _completeTurn();
                },
                onDone: () {
                  _setAssistant(
                    assistantId,
                    buffer.toString(),
                    ChatMessageStatus.done,
                  );
                  _sub = null;
                  _activeAssistantId = null;
                  state = state.copyWith(isResponding: false);
                  _completeTurn();
                },
                cancelOnError: true,
              );
    } catch (error) {
      final message = error is AppException
          ? error.message
          : const UnknownException().message;
      _setAssistant(assistantId, message, ChatMessageStatus.error);
      _sub = null;
      _activeAssistantId = null;
      state = state.copyWith(isResponding: false);
      _completeTurn();
    }

    await turn.future;
  }

  Future<void> stop() async {
    if (!state.isResponding) return;

    final assistantId = _activeAssistantId;
    final sub = _sub;
    _sub = null;
    _activeAssistantId = null;

    if (assistantId != null) {
      final i = state.messages.indexWhere((m) => m.id == assistantId);
      if (i != -1) {
        _setAssistant(
          assistantId,
          state.messages[i].content,
          ChatMessageStatus.done,
        );
      }
    }

    state = state.copyWith(isResponding: false);
    _completeTurn();
    if (sub != null) await sub.cancel();
  }

  void _setAssistant(String id, String content, ChatMessageStatus status) {
    final messages = [...state.messages];
    final i = messages.indexWhere((m) => m.id == id);
    if (i == -1) return;
    messages[i] = messages[i].copyWith(content: content, status: status);
    state = state.copyWith(messages: messages);
  }

  void _completeTurn() {
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
  }

  String _nextId() => 'm_${_seq++}';
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
