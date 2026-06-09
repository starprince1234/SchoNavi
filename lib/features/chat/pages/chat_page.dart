import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              padding: const EdgeInsets.all(12),
              itemCount: state.messages.length,
              itemBuilder: (context, index) => ChatMessageBubble(
                message: state.messages[index],
                onTapRecommendation: (id) => context.push('/professor/$id'),
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
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final question in questions) ...[
            ActionChip(
              label: Text(question),
              onPressed: enabled ? () => onTap(question) : null,
            ),
            const SizedBox(width: 8),
          ],
        ],
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
