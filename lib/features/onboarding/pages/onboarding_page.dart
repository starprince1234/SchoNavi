import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bento_tile.dart';

/// 首启引导：可滑动 PageView 介绍"AI 选导师"卖点 + 圆点指示 + 跳过；
/// 末页「开始使用」或随时「跳过」→ 写 seenOnboarding 后进首页。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  static const String seenKey = 'seenOnboarding';

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingData {
  const _OnboardingData(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _pages = <_OnboardingData>[
  _OnboardingData(
    Icons.chat_bubble_outline,
    '自然语言找导师',
    '用一句话描述你的研究兴趣与目标，大模型理解后接地推荐匹配的导师。',
  ),
  _OnboardingData(
    Icons.auto_awesome,
    '一站式申请助手',
    '推荐理由、追问答疑、套磁邮件、多导师对比、背景匹配雷达——一键生成。',
  ),
  _OnboardingData(
    Icons.verified_outlined,
    '真实可信',
    '事实接地于公开资料、不编造；推荐理解与排序交由大模型或真实后端完成。',
  ),
];

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;
  double _dotScale = 1.0;

  bool get _isLast => _index == _pages.length - 1;

  void _onPageChanged(int i) {
    setState(() {
      _index = i;
      _dotScale = 1.2;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _dotScale = 1.0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(localStoreProvider).setBool(OnboardingPage.seenKey, true);
    if (mounted) context.go('/home');
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: () {
                    Haptics.light();
                    _finish();
                  },
                  child: const Text('跳过'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Center(
                      child: AnimatedEntrance(
                        key: ValueKey(i),
                        slideOffset: const Offset(0, 24),
                        child: BentoTile(
                          color: scheme.surfaceContainerLowest,
                          padding: const EdgeInsets.all(32),
                          width: min(
                            320,
                            MediaQuery.sizeOf(context).width - 64,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                p.icon,
                                size: 48,
                                color: AppColors.coral,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                p.title,
                                style: textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                p.body,
                                style: textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedScale(
                    scale: i == _index ? _dotScale : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? scheme.secondary : scheme.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Haptics.medium();
                    _next();
                  },
                  child: Text(_isLast ? '开始使用' : '下一步'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
