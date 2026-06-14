import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text('继续追问', style: Theme.of(context).textTheme.titleLarge),
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: state.messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const AnimatedEntrance(
                      index: 0,
                      slideOffset: Offset(0, 12),
                      duration: Duration(milliseconds: 300),
                      child: _WelcomeCard(),
                    );
                  }
                  final messageIndex = index - 1;
                  return AnimatedEntrance(
                    index: index,
                    slideOffset: const Offset(0, 12),
                    duration: const Duration(milliseconds: 300),
                    child: ChatMessageBubble(
                      message: state.messages[messageIndex],
                      onTapRecommendation: (id) => context.push('/professor/$id'),
                      onRegenerate: (id) => ref.read(chatProvider.notifier).regenerateMessage(id),
                      onFeedback: (id, feedback) => ref.read(chatProvider.notifier).setFeedback(id, feedback),
                    ),
                  );
                },
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
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return BentoTile(
      color: scheme.surfaceContainerLowest,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: AppColors.coral, size: 20),
              const SizedBox(width: 8),
              Text('有什么想追问的？', style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '我可以基于上一步的推荐继续解答。试试问我：为什么推荐、相似导师、只看某地、是否适合硕士 / 博士。',
            style: textTheme.bodyMedium,
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
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  horizontal: 12,
                  vertical: 6,
                ),
                borderRadius: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.coral,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      question,
                      style: textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
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
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit => widget.controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: _focused
                ? Border.all(color: AppColors.coral, width: 2)
                : Border.all(
                    color: scheme.outline.withValues(alpha: 0.4),
                    width: 1,
                  ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: !widget.isResponding,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: widget.isResponding ? null : widget.onSubmit,
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
              Padding(
                padding: const EdgeInsets.all(8),
                child: widget.isResponding
                    ? Tooltip(
                        message: '停止生成',
                        child: Material(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: widget.onStop,
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.stop,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Tooltip(
                        message: '发送',
                        child: Material(
                          color: _canSubmit ? AppColors.coral : scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _canSubmit
                                ? () {
                                    Haptics.medium();
                                    widget.onSubmit(widget.controller.text);
                                  }
                                : null,
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.arrow_upward,
                                color: _canSubmit ? Colors.white : AppColors.inkSoft,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
