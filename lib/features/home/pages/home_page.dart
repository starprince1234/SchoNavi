import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/inline_tag_input.dart';

import '../../../core/di/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/home_prompt.dart';
import '../../../domain/entities/recommendation.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/widgets/chat_message_bubble.dart';
import '../../chat/widgets/chat_quick_actions.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/app_menu_drawer.dart';
import '../../../shared/widgets/bento_grid.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../../../shared/widgets/quick_tag.dart';
import '../../../shared/widgets/right_edge_open_drawer.dart';
import '../../../shared/widgets/rotating_subtitle.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/sliding_pill_switch.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

enum _HomeTab { mentor, competition }

/// 首页副标题动效。后期可替换为 FadeSlideStrategy() / CrossfadeStrategy()。
const SubtitleAnimationStrategy _kSubtitleStrategy = TypewriterStrategy();

class _TabConfig {
  const _TabConfig({required this.taglines, required this.quickTags});

  final List<String> taglines;
  final List<String> quickTags;
}

class _HomePageState extends ConsumerState<HomePage> {
  static const int _maxLen = 1000;
  static const Map<_HomeTab, _TabConfig> _tabConfigs = {
    _HomeTab.mentor: _TabConfig(
      taglines: [
        '说说你想研究的方向，我帮你找到合适的导师',
        '想做哪个方向的研究？我来帮你找导师',
        '不知道选谁？告诉我你的兴趣就好',
        '地区、方向、阶段，想到什么都可以说',
      ],
      quickTags: [
        '计算机视觉',
        '自然语言处理',
        '机器人',
        '北京',
        '上海',
        '江浙沪',
        '博士申请',
        '硕士申请',
        '人工智能',
        '推荐系统',
      ],
    ),
    _HomeTab.competition: _TabConfig(
      taglines: [
        '说说你的兴趣，我帮你找到适合的竞赛',
        '想参加什么样的比赛？我来帮你找',
        '还在纠结报哪个？告诉我你擅长什么',
        '时间、方向、组队，想到什么都可以说',
      ],
      quickTags: [
        '人工智能竞赛',
        '算法竞赛',
        '数学建模',
        '创新创业',
        '挑战杯',
        '互联网+',
        '电子设计',
        '信息安全',
        '智能车',
        '蓝桥杯',
        '团队赛',
        '个人赛',
        '近期可报名',
      ],
    ),
  };

  final InlineTagController _controller = InlineTagController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _conversationScrollController = ScrollController();
  late final _chatProvider = chatProvider(Object());
  bool _focused = false;
  bool _submitting = false;
  bool _inConversation = false;
  bool _inConversationStarted = false;
  int _messageCount = 0;
  _HomeTab _currentTab = _HomeTab.mentor;

  _TabConfig get _currentConfig => _tabConfigs[_currentTab]!;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _conversationScrollController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _controller.plainText.trim().isNotEmpty && !_submitting;

  /// 导师 tab：首页原地进入对话态——对齐 ChatGPT App，发送后不跳路由，
  /// 消息在首页上方展开、输入框沉底。竞赛 tab 仍跳静态结果页（无对话能力）。
  Future<void> _submit() async {
    final prompt = _controller.plainText.trim();
    if (prompt.isEmpty || _submitting) return;
    final config = ref.read(appConfigProvider);
    final isMentor = _currentTab == _HomeTab.mentor;
    if (isMentor &&
        config.dataSource == DataSource.llm &&
        !config.llm.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(const MissingLlmConfigurationException().message),
        ),
      );
      return;
    }
    if (prompt.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('可补充研究方向或地区，描述更具体会更准哦')));
    }

    if (!isMentor) {
      // 竞赛 tab：保留既有跳转。
      setState(() => _submitting = true);
      if (!mounted) return;
      await context.push(
        '/competition-recommendation?q=${Uri.encodeComponent(prompt)}',
      );
      if (!mounted) return;
      _controller.clear();
      setState(() => _submitting = false);
      return;
    }

    // 导师 tab：原地启动对话。已有对话态则走追问 send；否则开局首推产卡。
    // autoDispose provider：落地态无人 watch，必须先 setState 进对话态让
    // _buildConversationContent 订阅，再在下一帧启动 notifier，否则 notifier
    // 会在 read 结束后被自动释放、状态丢失。
    setState(() {
      _submitting = true;
      _inConversation = true;
    });
    final promptValue = prompt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(_chatProvider.notifier);
      if (!_inConversationStarted) {
        _inConversationStarted = true;
        notifier.start(sessionId: _newSessionId(), professorId: null);
        notifier.bootstrapRecommendations(promptValue);
      } else {
        notifier.send(promptValue);
      }
    });
    _controller.clear();
    setState(() => _submitting = false);
  }

  void _sendFollowUp(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    ref.read(_chatProvider.notifier).send(value);
  }

  void _stopGeneration() => ref.read(_chatProvider.notifier).stop();

  void _startNewConversation() {
    setState(() {
      _inConversation = false;
      _inConversationStarted = false;
      _messageCount = 0;
    });
    ref.invalidate(_chatProvider);
    _controller.clear();
  }

  String _newSessionId() =>
      's_chat_${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(this)}';

  void _scrollConversationToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_conversationScrollController.hasClients) {
        _conversationScrollController.animateTo(
          _conversationScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

  void _appendTag(String tag) {
    _controller.addTag(tag);
    Haptics.selection();
  }

  Color _tagColor(String tag, ColorScheme scheme) {
    if (tag == '北京' || tag == '上海' || tag == '江浙沪') {
      return AppColors.matchSoft;
    }
    if (tag == '博士申请' || tag == '硕士申请') {
      return AppColors.coralSoft;
    }
    if (tag == '计算机视觉' ||
        tag == '自然语言处理' ||
        tag == '机器人' ||
        tag == '人工智能' ||
        tag == '推荐系统') {
      return AppColors.coralSoft;
    }
    if (tag.contains('竞赛') ||
        tag == '挑战杯' ||
        tag == '互联网+' ||
        tag == '蓝桥杯' ||
        tag == '近期可报名') {
      return AppColors.coralSoft;
    }
    return scheme.surfaceContainer;
  }

  BentoTile _buildPromptTile(HomePrompt prompt) {
    return BentoTile(
      onTap: () {
        Haptics.light();
        _controller.value = TextEditingValue(
          text: prompt.text,
          selection: TextSelection.collapsed(offset: prompt.text.length),
        );
      },
      color: Theme.of(context).colorScheme.surface,
      height: 120,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            prompt.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              Icons.lightbulb_outline,
              color: AppColors.coral,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptGridSkeleton() {
    return BentoGrid(
      crossAxisCount: 2,
      spacing: 12,
      runSpacing: 12,
      animateEntrance: false,
      children: List.generate(
        4,
        (_) => BentoTile(
          color: Theme.of(context).colorScheme.surface,
          height: 120,
          padding: const EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(height: 12, width: double.infinity),
              SizedBox(height: 8),
              Skeleton(height: 12, width: 80),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final promptsAsync = ref.watch(homePromptsProvider(_currentTab.name));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      endDrawer: const AppMenuDrawer(),
      drawerEdgeDragWidth: 0,
      body: Builder(
        builder: (context) {
          return Stack(
            children: [
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        // Fixed top bar: 对话态左侧是新会话入口，菜单常驻右上。
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: Row(
                              children: [
                                if (_inConversation)
                                  IconButton(
                                    tooltip: '新对话',
                                    icon: const Icon(Icons.edit_square),
                                    onPressed: _startNewConversation,
                                  )
                                else
                                  const SizedBox(width: 12),
                                const Spacer(),
                                const _HomeMenuButton(),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: _inConversation
                              ? _buildConversationContent(textTheme, scheme)
                              : _buildLandingContent(
                                  textTheme,
                                  scheme,
                                  promptsAsync,
                                ),
                        ),
                        _buildBottomInput(scheme),
                      ],
                    ),
                  ),
                ),
              ),
              // Right-edge swipe area. It stops 120 logical pixels above the
              // bottom of the screen so it does not steal horizontal scroll
              // gestures from the tag row.
              Positioned(
                top: 0,
                right: 0,
                bottom: 120,
                child: RightEdgeOpenDrawer(
                  onSwipe: () {
                    Haptics.light();
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 落地态：品牌字标 + 模式开关 + 动态副标题 + prompt 网格。
  Widget _buildLandingContent(
    TextTheme textTheme,
    ColorScheme scheme,
    AsyncValue<List<HomePrompt>> promptsAsync,
  ) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedEntrance(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  // 品牌字标，居中 Hero。
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SchoNavi',
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.coral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 模式切换器，居中放大。
                  SizedBox(
                    width: 200,
                    child: SlidingPillSwitch<_HomeTab>(
                      values: const [_HomeTab.mentor, _HomeTab.competition],
                      selected: _currentTab,
                      labels: const ['导师', '竞赛'],
                      onChanged: (value) {
                        setState(() => _currentTab = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 随模式轮播的动态副标题（固定高度防跳动）。
                  SizedBox(
                    height: 44,
                    child: Center(
                      child: RotatingSubtitle(
                        phrases: _currentConfig.taglines,
                        strategy: _kSubtitleStrategy,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedEntrance(
            index: 1,
            child: promptsAsync.when(
              data: (prompts) {
                return BentoGrid(
                  crossAxisCount: 2,
                  spacing: 12,
                  runSpacing: 12,
                  animateEntrance: false,
                  children: prompts.take(4).map(_buildPromptTile).toList(),
                );
              },
              loading: () => _buildPromptGridSkeleton(),
              error: (e, st) => _buildPromptGridSkeleton(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 对话态：消息流（复用 ChatMessageBubble）+ 快捷操作横滑条。
  Widget _buildConversationContent(TextTheme textTheme, ColorScheme scheme) {
    final state = ref.watch(_chatProvider);
    if (state.messages.length != _messageCount) {
      _messageCount = state.messages.length;
      _scrollConversationToBottom();
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _conversationScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: state.messages.length,
            itemBuilder: (context, index) {
              final message = state.messages[index];
              return AnimatedEntrance(
                index: index,
                slideOffset: const Offset(0, 12),
                duration: const Duration(milliseconds: 300),
                child: ChatMessageBubble(
                  key: ValueKey(message.id),
                  message: message,
                  onTapRecommendation: (id) => context.push('/professor/$id'),
                  onOpenHomepage: _openHomepage,
                  onRetryRecommendation: (id) =>
                      ref.read(_chatProvider.notifier).retryRecommendation(id),
                  onRegenerate: (id) =>
                      ref.read(_chatProvider.notifier).regenerateMessage(id),
                  onFeedback: (id, feedback) => ref
                      .read(_chatProvider.notifier)
                      .setFeedback(id, feedback),
                ),
              );
            },
          ),
        ),
        ChatQuickActions(
          actions: state.followUpQuestions,
          fallback: _quickActions,
          enabled: !state.isBusy,
          onTap: _sendFollowUp,
        ),
      ],
    );
  }

  /// 底部常驻输入区：落地态用 quick tags，对话态用快捷操作；发送键在
  /// 对话态支持 busy→stop 切换。输入框始终用 InlineTagInput（保留标签能力）。
  Widget _buildBottomInput(ColorScheme scheme) {
    final chatState = _inConversation ? ref.watch(_chatProvider) : null;
    final isBusy = chatState?.isBusy ?? false;
    final canStop = chatState?.activity == ChatActivity.streaming;
    final hint = _inConversation ? '继续描述你的需求…' : '给 SchoNavi 发送消息';
    return AnimatedEntrance(
      index: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
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
                    child: InlineTagInput(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 1,
                      maxLength: _maxLen,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (_canSubmit && !isBusy) _submit();
                      },
                      hintText: hint,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _buildSendButton(
                      scheme,
                      isBusy: isBusy,
                      canStop: canStop,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 落地态：quick tags；对话态：快捷操作由上方对话区承载，此处不再重复。
            if (!_inConversation)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _currentConfig.quickTags.map((tag) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: QuickTag(
                        label: tag,
                        onTap: () => _appendTag(tag),
                        haptic: Haptics.selection,
                        color: _tagColor(tag, scheme),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 发送/停止按钮：对话态 streaming 时为停止键，busy 时为 loading 指示，
  /// 否则为发送键。落地态恒为发送键。
  Widget _buildSendButton(
    ColorScheme scheme, {
    required bool isBusy,
    required bool canStop,
  }) {
    if (canStop) {
      return Tooltip(
        message: '停止生成',
        child: Material(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _stopGeneration,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.stop, color: Colors.white, size: 20),
            ),
          ),
        ),
      );
    }
    if (isBusy) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Tooltip(
      message: '发送',
      child: Material(
        color: _canSubmit ? AppColors.coral : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _canSubmit
              ? () {
                  Haptics.medium();
                  _submit();
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
    );
  }
}

/// 对话态快捷操作回退（与 ChatPage 默认操作一致）。
const List<String> _quickActions = ['解释理由', '换一批', '只看北京', '适合硕士'];

class _HomeMenuButton extends StatelessWidget {
  const _HomeMenuButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '菜单',
      icon: const Icon(Icons.menu_outlined),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onPressed: () {
        Haptics.light();
        Scaffold.of(context).openEndDrawer();
      },
    );
  }
}
