import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/app_menu_drawer.dart';
import '../../../shared/widgets/bento_grid.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../../../shared/widgets/quick_tag.dart';
import '../../../shared/widgets/right_edge_open_drawer.dart';
import '../../../shared/widgets/scho_navi_app_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const int _maxLen = 1000;
  static const List<String> _examples = [
    '我想找计算机视觉方向的导师，最好在北京。',
    '我想做 AI 和医疗结合的研究，有没有适合的老师？',
    '推荐几个 NLP 和大模型安全方向的导师。',
    '我是自动化背景，想申请机器人方向博士。',
    '我想找江浙沪地区偏应用的人工智能导师。',
  ];
  static const List<String> _tags = [
    '人工智能',
    '计算机视觉',
    '自然语言处理',
    '医学影像',
    '机器人',
    '网络安全',
    '生物信息',
    '材料计算',
    '北京',
    '上海',
    '江浙沪',
    '博士申请',
    '硕士申请',
  ];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

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
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;
    if (prompt.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('可补充研究方向或地区，描述更具体会更准哦')));
    }

    context.push('/recommendation?q=${Uri.encodeComponent(prompt)}');
  }

  void _appendTag(String tag) {
    final text = _controller.text;
    _controller.text = text.isEmpty ? tag : '$text $tag';
  }

  Color _tagColor(String tag, ColorScheme scheme) {
    if (tag == '北京' || tag == '上海' || tag == '江浙沪') {
      return AppColors.matchSoft;
    }
    if (tag == '博士申请' || tag == '硕士申请') {
      return AppColors.coralSoft;
    }
    return scheme.surfaceContainer;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      endDrawer: const AppMenuDrawer(),
      drawerEdgeDragWidth: 0,
      appBar: const SchoNaviAppBar(),
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
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 16),
                                AnimatedEntrance(
                                  index: 0,
                                  child: Text(
                                    '用自然语言找到适合你的导师',
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: AppColors.inkSoft,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                AnimatedEntrance(
                                  index: 1,
                                  child: BentoGrid(
                                    crossAxisCount: 2,
                                    spacing: 12,
                                    runSpacing: 12,
                                    animateEntrance: false,
                                    children: _examples.take(4).map((e) {
                                      return BentoTile(
                                        onTap: () {
                                          Haptics.light();
                                          _controller.text = e;
                                        },
                                        color: scheme.surface,
                                        height: 120,
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              e,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: textTheme.bodyMedium,
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
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                        AnimatedEntrance(
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
                                        ? Border.all(
                                            color: AppColors.coral,
                                            width: 2,
                                          )
                                        : Border.all(
                                            color: scheme.outline.withValues(
                                              alpha: 0.4,
                                            ),
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
                                          controller: _controller,
                                          focusNode: _focusNode,
                                          maxLines: 5,
                                          minLines: 1,
                                          maxLength: _maxLen,
                                          textInputAction: TextInputAction.send,
                                          onSubmitted: (_) {
                                            if (_canSubmit) _submit();
                                          },
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            errorBorder: InputBorder.none,
                                            focusedErrorBorder:
                                                InputBorder.none,
                                            filled: false,
                                            fillColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            counterText: '',
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                            hintText: '给 SchoNavi 发送消息',
                                            suffixIcon: _controller.text.isEmpty
                                                ? null
                                                : IconButton(
                                                    icon: const Icon(
                                                      Icons.clear,
                                                      size: 18,
                                                    ),
                                                    onPressed: () {
                                                      Haptics.light();
                                                      _controller.clear();
                                                    },
                                                  ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Material(
                                          color: _canSubmit
                                              ? AppColors.coral
                                              : scheme.surfaceContainer,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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
                                                color: _canSubmit
                                                    ? Colors.white
                                                    : AppColors.inkSoft,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: _tags.map((tag) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
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
                        ),
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
}
