import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/recommendation.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../../../shared/widgets/cool_scaffold_background.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/floating_top_button.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_quick_actions.dart';
import '../widgets/professor_anchor_bar.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    this.sessionId,
    this.professorId,
    this.initialPrompt,
    this.forkMode = false,
    this.mainSessionId,
    this.forkId,
  });

  /// 旧入口（从推荐页 FAB / 详情页「继续追问」）：携带已有会话 id 进纯追问。
  final String? sessionId;
  final String? professorId;

  /// 新入口（首页提交）：把提问作为首条用户消息，触发首轮推荐产卡。
  /// 非空时走对话式推荐首轮，隐藏欢迎卡。
  final String? initialPrompt;

  /// fork 追问入口：从教授详情/历史 fork 列表进来。
  final bool forkMode;
  final String? mainSessionId;
  final String? forkId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_configurationBlocked) return;
      final notifier = ref.read(_provider.notifier);
      if (widget.forkMode && widget.forkId != null) {
        await notifier.resume(
          sessionId: widget.forkId!,
          isFork: true,
          mainSessionId: widget.mainSessionId,
        );
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
    // 首页带 initialPrompt 进来是新会话（对话式推荐首轮），不应显示「继续追问」
    // 这种「延续旧会话」的语义——对齐 ChatGPT App：新对话就是新对话页。
    final isNewSession = widget.initialPrompt != null;
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
      body: Stack(
        children: [
          const Positioned.fill(child: CoolScaffoldBackground()),
          blocked
              ? ErrorView(message: const MissingLlmConfigurationException().message)
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            state.forkAnchor != null ? 108.0 : 56.0,
                            20,
                            12,
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
                            onRerouteHome: () => context.go('/home'),
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
                  ChatQuickActions(
                    actions: state.followUpQuestions,
                    enabled: !state.isBusy,
                    onTap: _send,
                  ),
                  ChatInputBar(
                    controller: _controller,
                    isBusy: state.isBusy,
                    canStop: state.activity == ChatActivity.streaming,
                    isNewSession: isNewSession,
                    onSubmit: _send,
                    onStop: () => ref.read(_provider.notifier).stop(),
                  ),
                ],
              ),
            ),
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
                    '/professor/${state.forkAnchor!.professorId}'
                    '?msid=${Uri.encodeComponent(state.forkAnchor!.mainSessionId)}',
                  ),
                  // fork 追问页：把「返回」「重新生成」收进锚点条同一行，
                  // 避免它们作为独立 Positioned 与锚点条在顶部重叠。
                  leading: FloatingTopButton(
                    icon: Icons.arrow_back,
                    tooltip: '返回',
                    onPressed: () => context.pop(),
                  ),
                  trailing: FloatingTopButton(
                    icon: Icons.refresh,
                    tooltip: '重新生成',
                    onPressed: state.canRegenerate
                        ? () => ref.read(_provider.notifier).regenerate()
                        : null,
                  ),
                ),
              ),
            )
          else ...[
            // 左上悬浮：新会话页（initialPrompt 首页提交入口）显示「新对话」
            // 回首页；旧会话追问页（推荐页/详情页「继续追问」push 进来）显示
            // 「返回」，pop 回上一页而非丢弃会话跳首页。
            Positioned(
              top: 8,
              left: 12,
              child: isNewSession
                  ? FloatingTopButton(
                      icon: Icons.edit_square,
                      tooltip: '新对话',
                      onPressed: () => context.go('/home'),
                    )
                  : FloatingTopButton(
                      icon: Icons.arrow_back,
                      tooltip: '返回',
                      onPressed: () => context.pop(),
                    ),
            ),
            // 右上悬浮：「重新生成」；canRegenerate=false 时 disabled。
            Positioned(
              top: 8,
              right: 12,
              child: FloatingTopButton(
                icon: Icons.refresh,
                tooltip: '重新生成',
                onPressed: state.canRegenerate
                    ? () => ref.read(_provider.notifier).regenerate()
                    : null,
              ),
            ),
          ],
        ],
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
    return BentoTile(
      frosted: true,
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
                color: AppColors.indigo,
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
