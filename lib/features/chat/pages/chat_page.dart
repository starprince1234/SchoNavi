import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_message_bubble.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.sessionId, this.professorId});

  final String sessionId;
  final String? professorId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  static const List<String> _quickQuestions = [
    '为什么推荐这位导师？',
    '有没有相似的导师？',
    '只看北京的导师',
    '适合硕士申请吗？',
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(chatProvider.notifier)
          .start(sessionId: widget.sessionId, professorId: widget.professorId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    _controller.clear();
    ref.read(chatProvider.notifier).send(value);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    if (state.messages.length != _messageCount) {
      _messageCount = state.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('继续追问'),
        actions: [
          IconButton(
            tooltip: '重新生成',
            onPressed: state.isResponding
                ? null
                : () => ref.read(chatProvider.notifier).regenerate(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: state.messages.length,
              itemBuilder: (context, index) => AnimatedEntrance(
                index: index,
                slideOffset: const Offset(0, 16),
                child: ChatMessageBubble(
                  message: state.messages[index],
                  onTapRecommendation: (id) => context.push('/professor/$id'),
                ),
              ),
            ),
          ),
          _QuickQuestions(
            questions: _quickQuestions,
            enabled: !state.isResponding,
            onTap: _send,
          ),
          _InputBar(
            controller: _controller,
            isResponding: state.isResponding,
            onSubmit: _send,
            onStop: () => ref.read(chatProvider.notifier).stop(),
          ),
        ],
      ),
    );
  }
}

class _QuickQuestions extends StatelessWidget {
  const _QuickQuestions({
    required this.questions,
    required this.enabled,
    required this.onTap,
  });

  final List<String> questions;
  final bool enabled;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final question = questions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: BentoTile(
                onTap: enabled
                    ? () {
                        Haptics.selection();
                        onTap(question);
                      }
                    : null,
                color: scheme.surfaceContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                borderRadius: 16,
                child: Text(
                  question,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: BentoTile(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: 24,
                  padding: EdgeInsets.zero,
                  child: TextField(
                    controller: controller,
                    enabled: !isResponding,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: isResponding ? null : onSubmit,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintText: '输入你的追问…',
                    ),
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
      ),
    );
  }
}
