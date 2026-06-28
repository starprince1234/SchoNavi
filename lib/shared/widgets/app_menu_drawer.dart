import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/search_history_item.dart';

/// ChatGPT 风格的综合抽屉菜单。
///
/// 从屏幕右侧滑出，顶部展示个人档案入口，下方列出历史、收藏、设置等
/// 核心功能入口。
class AppMenuDrawer extends ConsumerWidget {
  const AppMenuDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              label: '历史',
              onTap: () => _navigate(context, '/history'),
            ),
            _DrawerTile(
              icon: Icons.bookmark_outline,
              label: '我的收藏',
              onTap: () => _navigate(context, '/favorites'),
            ),
            _DrawerTile(
              icon: Icons.flag_outlined,
              label: '我的备赛',
              onTap: () => _navigate(context, '/preparation-plans'),
            ),
            _DrawerTile(
              icon: Icons.settings_outlined,
              label: '设置',
              onTap: () => _navigate(context, '/settings'),
            ),

            Divider(height: 1, color: AppColors.line),

            // ── 最近搜索历史预览 ─────────────────────────────────────────
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    _EmptyHint(icon: Icons.error_outline, message: '历史读取失败'),
                data: (items) {
                  final competitions = items
                      .where(
                        (item) => item.type == SearchHistoryType.competition,
                      )
                      .toList(growable: false);
                  if (competitions.isEmpty) {
                    return _EmptyHint(
                      icon: Icons.manage_search_outlined,
                      message: '暂无竞赛搜索历史',
                    );
                  }
                  return _RecentSearchPanel(
                    items: competitions,
                    onTap: (item) {
                      Haptics.light();
                      Navigator.of(context).pop();
                      context.push(_historyRoute(item));
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
              backgroundColor: AppColors.indigoSoft,
              child: Icon(Icons.person, color: AppColors.indigo, size: 26),
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
            Icon(Icons.chevron_right, color: AppColors.inkSoft),
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
    return Tooltip(
      message: label,
      child: ListTile(
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
      ),
    );
  }
}

// ── Recent search panel with local filtering ─────────────────────────────────

class _RecentSearchPanel extends StatefulWidget {
  const _RecentSearchPanel({required this.items, required this.onTap});

  final List<SearchHistoryItem> items;
  final ValueChanged<SearchHistoryItem> onTap;

  @override
  State<_RecentSearchPanel> createState() => _RecentSearchPanelState();
}

class _RecentSearchPanelState extends State<_RecentSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _query = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<SearchHistoryItem> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items.where((item) {
      final typeLabel = _historyTypeLabel(item.type);
      return item.prompt.toLowerCase().contains(query) ||
          item.summary.toLowerCase().contains(query) ||
          typeLabel.contains(query) ||
          item.researchInterests.any(
            (field) => field.toLowerCase().contains(query),
          ) ||
          item.preferredLocations.any(
            (location) => location.toLowerCase().contains(query),
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
          child: Row(
            children: [
              Text(
                '最近',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    style: textTheme.bodySmall,
                    decoration: InputDecoration(
                      hintText: '搜索',
                      hintStyle: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: _searchController.clear,
                            ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyHint(
                  icon: Icons.manage_search_outlined,
                  message: '没有匹配的最近搜索',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: filtered.length.clamp(0, 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _HistoryTile(
                      item: item,
                      onTap: () => widget.onTap(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── History preview tile ─────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.onTap});

  final SearchHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      SearchHistoryType.competition => Icons.emoji_events_outlined,
      SearchHistoryType.mentor => Icons.chat_bubble_outline,
    };
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
                Icon(icon, size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.prompt,
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

String _historyRoute(SearchHistoryItem item) {
  final path = switch (item.type) {
    SearchHistoryType.competition => '/competition-recommendation',
    SearchHistoryType.mentor => '/recommendation',
  };
  return '$path?q=${Uri.encodeComponent(item.prompt)}';
}

String _historyTypeLabel(SearchHistoryType type) => switch (type) {
  SearchHistoryType.competition => '竞赛',
  SearchHistoryType.mentor => '导师',
};

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
