import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/result/result.dart';
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

  @override
  ChatState build() => const ChatState.initial();

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

    final result = await ref
        .read(chatRepositoryProvider)
        .sendMessage(
          sessionId: state.sessionId!,
          message: content,
          professorId: state.professorId,
        );

    final resolved = switch (result) {
      Success(:final data) => ChatMessage(
        id: placeholder.id,
        role: ChatRole.assistant,
        content: data.answer,
        createdAt: placeholder.createdAt,
        relatedRecommendations: data.relatedRecommendations,
        status: ChatMessageStatus.done,
      ),
      Failure(:final error) => ChatMessage(
        id: placeholder.id,
        role: ChatRole.assistant,
        content: error.message,
        createdAt: placeholder.createdAt,
        relatedRecommendations: const [],
        status: ChatMessageStatus.error,
      ),
    };

    final updated = [...state.messages];
    updated[updated.length - 1] = resolved;
    state = state.copyWith(messages: updated, isResponding: false);
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
