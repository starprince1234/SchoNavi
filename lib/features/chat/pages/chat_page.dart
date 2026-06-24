import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/recommendation.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../../../shared/widgets/error_view.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_message_bubble.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    this.sessionId,
    this.professorId,
    this.initialPrompt,
  });

  /// 旧入口（从推荐页 FAB / 详情页「继续追问」）：携带已有会话 id 进纯追问。
  final String? sessionId;
  final String? professorId;

  /// 新入口（首页提交）：把提问作为首条用户消息，触发首轮推荐产卡。
  /// 非空时走对话式推荐首轮，隐藏欢迎卡。
  final String? initialPrompt;

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
  late final _provider = chatProvider(Object());
  int _messageCount = 0;

  bool get _configurationBlocked {
    final config = ref.read(appConfigProvider);
    return config.dataSource == DataSource.llm && !config.llm.isConfigured;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_configurationBlocked) return;
      final notifier = ref.read(_provider.notifier);
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
    ref.read(_provider.notifier).send(value);
  }

  Future<void> _openHomepage(Recommendation recommendation) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(linkLauncherProvider)
        .open(recommendation.homepageUrl);
    switch (result) {
      case LaunchResult.success:
        return;
      case LaunchResult.noUrl:
        messenger.showSnackBar(const SnackBar(content: Text('暂无主页信息')));
      case LaunchResult.failed:
        messenger.showSnackBar(
          const SnackBar(content: Text('主页可能已失效，可通过学校官网确认')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final blocked =
        config.dataSource == DataSource.llm && !config.llm.isConfigured;
    final state = ref.watch(_provider);
    final showWelcome = widget.initialPrompt == null;
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
            onPressed: state.canRegenerate
                ? () => ref.read(_provider.notifier).regenerate()
                : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: blocked
          ? ErrorView(message: const MissingLlmConfigurationException().message)
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      itemCount: state.messages.length + (showWelcome ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (showWelcome && index == 0) {
                          return const AnimatedEntrance(
                            index: 0,
                            slideOffset: Offset(0, 12),
                            duration: Duration(milliseconds: 300),
                            child: _WelcomeCard(),
                          );
                        }
                        final messageIndex = showWelcome ? index - 1 : index;
                        return AnimatedEntrance(
                          index: index,
                          slideOffset: const Offset(0, 12),
                          duration: const Duration(milliseconds: 300),
                          child: ChatMessageBubble(
                            key: ValueKey(state.messages[messageIndex].id),
                            message: state.messages[messageIndex],
                            onTapRecommendation: (id) =>
                                context.push('/professor/$id'),
                            onOpenHomepage: _openHomepage,
                            onRetryRecommendation: (id) => ref
                                .read(_provider.notifier)
                                .retryRecommendation(id),
                            onRegenerate: (id) => ref
                                .read(_provider.notifier)
                                .regenerateMessage(id),
                            onFeedback: (id, feedback) => ref
                                .read(_provider.notifier)
                                .setFeedback(id, feedback),
                          ),
                        );
                      },
                    ),
                  ),
                  _QuickQuestions(
                    questions: state.followUpQuestions.isEmpty
                        ? _quickQuestions
                        : state.followUpQuestions,
                    enabled: !state.isBusy,
                    onTap: _send,
                  ),
                  _InputBar(
                    controller: _controller,
                    isBusy: state.isBusy,
                    canStop: state.activity == ChatActivity.streaming,
                    onSubmit: _send,
                    onStop: () => ref.read(_provider.notifier).stop(),
                  ),
                ],
              ),
            ),
    );
  }

  String _newSessionId() =>
      's_chat_${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(this)}';
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
              const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.coral,
                size: 20,
              ),
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
                    Text(question, style: textTheme.labelSmall),
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
    required this.isBusy,
    required this.canStop,
    required this.onSubmit,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isBusy;
  final bool canStop;
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
                  enabled: !widget.isBusy,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: widget.isBusy ? null : widget.onSubmit,
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
                child: widget.canStop
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
                    : widget.isBusy
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Tooltip(
                        message: '发送',
                        child: Material(
                          color: _canSubmit
                              ? AppColors.coral
                              : scheme.surfaceContainer,
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
                                color: _canSubmit
                                    ? Colors.white
                                    : AppColors.inkSoft,
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
