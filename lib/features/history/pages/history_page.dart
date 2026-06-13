import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/search_history_item.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/field_chips.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
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

  List<SearchHistoryItem> _filter(List<SearchHistoryItem> items) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((item) {
      return item.prompt.toLowerCase().contains(query) ||
          item.summary.toLowerCase().contains(query) ||
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
    final async = ref.watch(searchHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史'),
        actions: [
          async.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: '清空历史',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _confirmClear(context, ref),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 3,
          itemBuilder: (_, _) => const _HistoryTileSkeleton(),
        ),
        error: (_, _) => const EmptyView(message: '历史读取失败，可稍后重试'),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(message: '暂无搜索历史');
          }

          final filtered = _filter(items);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: '搜索',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                              },
                            ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                const Expanded(
                  child: EmptyView(message: '没有匹配的搜索记录'),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.coral,
                    onRefresh: () async {
                      ref.invalidate(searchHistoryProvider);
                      await ref.read(searchHistoryProvider.future);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return AnimatedEntrance(
                          index: index,
                          child: Dismissible(
                            key: ValueKey(item.sessionId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              Haptics.medium();
                              ref.read(historyRepositoryProvider).remove(item.sessionId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已删除')),
                              );
                            },
                            child: _HistoryTile(item: item),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定清空全部搜索历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(historyRepositoryProvider).clear();
    }
  }
}


class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.item});

  final SearchHistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: () => context.push(
          '/recommendation?q=${Uri.encodeComponent(item.prompt)}',
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.prompt,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '删除历史',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref
                        .read(historyRepositoryProvider)
                        .remove(item.sessionId),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(item.summary, style: textTheme.bodyMedium),
              if (item.researchInterests.isNotEmpty) ...[
                const SizedBox(height: 8),
                FieldChips(fields: item.researchInterests),
              ],
              const SizedBox(height: 8),
              Text(
                '${_formatDateTime(item.createdAt)} · '
                '${item.recommendationCount} 位导师',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTileSkeleton extends StatelessWidget {
  const _HistoryTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ShimmerSkeleton(height: 16, width: double.infinity),
                ),
                SizedBox(width: 8),
                ShimmerSkeleton(height: 24, width: 24),
              ],
            ),
            SizedBox(height: 6),
            ShimmerSkeleton(height: 14, width: double.infinity),
            SizedBox(height: 8),
            ShimmerSkeleton(height: 12, width: 120),
            SizedBox(height: 8),
            ShimmerSkeleton(height: 12, width: 200),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
