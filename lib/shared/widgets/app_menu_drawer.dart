import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';

/// ChatGPT 风格的综合抽屉菜单。
///
/// 从屏幕右侧滑出，顶部展示个人档案入口，下方列出搜索历史、收藏、设置等
/// 核心功能入口。
class AppMenuDrawer extends ConsumerWidget {
  const AppMenuDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final historyAsync = ref.watch(searchHistoryProvider);

    return Drawer(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 顶部档案入口 ─────────────────────────────────────────────
            _ProfileHeader(onTap: () => _navigate(context, '/profile')),
            Divider(height: 1, color: AppColors.line),

            // ── 功能入口 ─────────────────────────────────────────────────
            _DrawerTile(
              icon: Icons.history,
              label: '搜索历史',
              onTap: () => _navigate(context, '/history'),
            ),
            _DrawerTile(
              icon: Icons.bookmark_outline,
              label: '我的收藏',
              onTap: () => _navigate(context, '/favorites'),
            ),
            _DrawerTile(
              icon: Icons.settings_outlined,
              label: '设置',
              onTap: () => _navigate(context, '/settings'),
            ),

            Divider(height: 1, color: AppColors.line),

            // ── 最近搜索历史预览 ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '最近搜索',
                style: textTheme.labelLarge?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _EmptyHint(
                  icon: Icons.error_outline,
                  message: '历史读取失败',
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _EmptyHint(
                      icon: Icons.manage_search_outlined,
                      message: '暂无搜索历史',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: items.length.clamp(0, 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _HistoryTile(
                        prompt: item.prompt,
                        onTap: () {
                          Haptics.light();
                          Navigator.of(context).pop();
                          context.push(
                            '/recommendation?q=${Uri.encodeComponent(item.prompt)}',
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    Haptics.light();
    Navigator.of(context).pop();
    context.push(route);
  }
}

// ── Profile header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.coralSoft,
              child: Icon(
                Icons.person,
                color: AppColors.coral,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '我的档案',
                    style: textTheme.titleMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '查看并编辑个人信息',
                    style: textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.inkSoft,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drawer tile ──────────────────────────────────────────────────────────────

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.inkSoft, size: 22),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
      ),
      minLeadingWidth: 24,
      horizontalTitleGap: 12,
      onTap: onTap,
    );
  }
}

// ── History preview tile ─────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.prompt, required this.onTap});

  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty hint ───────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.line),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
