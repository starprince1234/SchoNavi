import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bento_tile.dart';

class ProfileIntroPage extends StatelessWidget {
  const ProfileIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Text(
                '完善档案，让推荐更懂你',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _ValueCard(
                index: 0,
                icon: Icons.trending_up,
                title: '精准推荐',
                description: '结合你的成绩和背景，匹配最合适的导师',
                scheme: scheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),
              _ValueCard(
                index: 1,
                icon: Icons.auto_fix_high,
                title: '智能套磁',
                description: '自动生成个性化的 outreach 邮件',
                scheme: scheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),
              _ValueCard(
                index: 2,
                icon: Icons.psychology,
                title: '匹配分析',
                description: '评估你与导师研究方向的契合度',
                scheme: scheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '你的资料将用于个性化推荐、智能套磁与匹配分析',
                      style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Haptics.medium();
                    context.push('/profile/wizard');
                  },
                  child: const Text('开始填写（约 1 分钟）'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Haptics.light();
                    Navigator.of(context).pop();
                  },
                  child: const Text('以后再说'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.description,
    required this.scheme,
    required this.textTheme,
  });

  final int index;
  final IconData icon;
  final String title;
  final String description;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedEntrance(
      index: index,
      child: BentoTile(
        color: scheme.surfaceContainerLowest,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
