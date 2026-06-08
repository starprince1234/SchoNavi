import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../domain/entities/favorite_item.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/field_chips.dart';
import '../../../shared/widgets/loading_view.dart';

class FavoritePage extends ConsumerWidget {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (_, _) => const EmptyView(message: '收藏读取失败，可稍后重试'),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(message: '还没有收藏导师');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => _FavoriteTile(item: items[index]),
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.item});

  final FavoriteItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: () => context.push('/professor/${item.professorId}'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '${item.university} / ${item.college}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '取消收藏',
                    icon: const Icon(Icons.bookmark_remove_outlined),
                    onPressed: () => ref
                        .read(favoriteRepositoryProvider)
                        .remove(item.professorId),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FieldChips(fields: item.researchFields),
              const SizedBox(height: 8),
              Text(
                '收藏时间：${_formatDateTime(item.favoritedAt)}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openHomepage(context, ref, item.homepageUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('访问主页'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHomepage(
    BuildContext context,
    WidgetRef ref,
    String? url,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(linkLauncherProvider).open(url);
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
}

String _formatDateTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
