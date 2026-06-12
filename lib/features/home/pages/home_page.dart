import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bento_grid.dart';
import '../../../shared/widgets/bento_tile.dart';

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
      ).showSnackBar(
        const SnackBar(content: Text('可补充研究方向或地区，描述更具体会更准哦')),
      );
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
      appBar: AppBar(
        title: Text('SchoNavi', style: textTheme.displaySmall),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedEntrance(
              index: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '用自然语言找到适合你的导师',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI 驱动的研究生导师推荐',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedEntrance(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: _focused
                          ? Border.all(color: AppColors.coral, width: 2)
                          : Border.all(
                              color: scheme.outline.withValues(alpha: 0.5),
                              width: 1,
                            ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: 5,
                        maxLength: _maxLen,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          filled: false,
                          hintText:
                              '例如：我想找医学影像和计算机视觉方向的导师，最好在上海，适合申请硕士。',
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    Haptics.light();
                                    _controller.clear();
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _canSubmit
                        ? () {
                            Haptics.medium();
                            _submit();
                          }
                        : null,
                    child: const Text('开始推荐'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AnimatedEntrance(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('快捷标签', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  BentoGrid(
                    crossAxisCount: 3,
                    spacing: 8,
                    runSpacing: 8,
                    animateEntrance: false,
                    children: _tags.map((t) {
                      return BentoTile(
                        onTap: () => _appendTag(t),
                        haptic: Haptics.selection,
                        color: _tagColor(t, scheme),
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            t,
                            style: textTheme.labelSmall,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AnimatedEntrance(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('试试这些', style: textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _examples.asMap().entries.map((entry) {
                        final index = entry.key;
                        final e = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == _examples.length - 1 ? 0 : 12,
                          ),
                          child: AnimatedEntrance(
                            index: index,
                            child: BentoTile(
                              onTap: () {
                                _controller.text = e;
                              },
                              width: 240,
                              height: 100,
                              color: scheme.surface,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline,
                                    color: AppColors.coral,
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      e,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
