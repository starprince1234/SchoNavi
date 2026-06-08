import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../domain/entities/search_history_item.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/field_chips.dart';
import '../../../shared/widgets/loading_view.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        loading: () => const LoadingView(),
        error: (_, _) => const EmptyView(message: '历史读取失败，可稍后重试'),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(message: '暂无搜索历史');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => _HistoryTile(item: items[index]),
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

String _formatDateTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
