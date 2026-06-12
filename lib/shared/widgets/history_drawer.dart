import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/search_history_item.dart';
import 'shimmer_skeleton.dart';

/// 首页左侧抽屉，展示历史搜索 session 列表与收藏入口。
class HistoryDrawer extends ConsumerWidget {
  const HistoryDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: AppColors.paper,
      child: SafeArea(
        child: Column(
          children: [
            _Header(),
            Divider(height: 1, color: AppColors.line),
            Expanded(
              child: async.when(
                loading: () => const _HistorySkeleton(),
                error: (_, _) => Center(
                  child: Text(
                    '历史读取失败，可稍后重试',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                data: (items) => _HistoryList(items: items),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '搜索历史',
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '我的收藏',
            icon: const Icon(Icons.bookmark_outline, size: 20),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.inkSoft,
              backgroundColor: AppColors.panel,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
            ),
            onPressed: () => context.push('/favorites'),
          ),
        ],
      ),
    );
  }
}

// ── History list ─────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items});

  final List<SearchHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_outlined,
              size: 40,
              color: AppColors.line,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无搜索历史',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: items.length,
      itemBuilder: (context, index) => _HistoryCard(item: items[index]),
    );
  }
}

// ── History card ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final SearchHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tags = [
      ...item.researchInterests,
      ...item.preferredLocations,
    ].take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            Navigator.of(context).pop();
            context.push(
              '/recommendation?q=${Uri.encodeComponent(item.prompt)}',
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左侧 coral 细条
                Container(
                  width: 3,
                  color: AppColors.coral.withValues(alpha: 0.7),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // prompt
                        Text(
                          item.prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        // tags row
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: tags.map((tag) => _Tag(label: tag)).toList(),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // meta row
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_outlined,
                              size: 12,
                              color: AppColors.inkSoft,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _relativeTime(item.createdAt),
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.inkSoft,
                              ),
                            ),
                            if (item.recommendationCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.matchSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.recommendationCount} 位导师',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppColors.match,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.coralSoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.coral,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: List.generate(
        5,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.fromLTRB(15, 12, 12, 10),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(
                  height: 14,
                  width: double.infinity,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                SizedBox(height: 6),
                ShimmerSkeleton(
                  height: 14,
                  width: 180,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    ShimmerSkeleton(
                      height: 10,
                      width: 60,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    SizedBox(width: 8),
                    ShimmerSkeleton(
                      height: 10,
                      width: 50,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _relativeTime(DateTime value) {
  final now = DateTime.now();
  final diff = now.difference(value);

  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';

  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.month}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}
