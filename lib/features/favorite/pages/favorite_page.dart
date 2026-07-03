import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/api_error_reporter.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/favorite_item.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/field_chips.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../../../shared/widgets/error_view.dart';

class FavoritePage extends ConsumerStatefulWidget {
  const FavoritePage({super.key});

  @override
  ConsumerState<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends ConsumerState<FavoritePage> {
  bool _selecting = false;
  final Set<String> _selected = {};

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
  }

  void _toggleSelect(String professorId) {
    setState(() {
      if (_selected.contains(professorId)) {
        _selected.remove(professorId);
      } else if (_selected.length < 3) {
        _selected.add(professorId);
      }
    });
  }

  void _generateCompare() {
    if (_selected.length < 2 || _selected.length > 3) return;
    context.push('/compare?ids=${_selected.join(',')}');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoritesProvider);
    final canCompare = _selected.length >= 2 && _selected.length <= 3;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? '选择 2-3 位对比' : '收藏'),
        actions: [
          async.maybeWhen(
            data: (items) => items.length >= 2
                ? IconButton(
                    tooltip: _selecting ? '退出多选' : '对比导师',
                    icon: Icon(_selecting ? Icons.close : Icons.compare_arrows),
                    onPressed: _toggleSelecting,
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: _selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: canCompare ? _generateCompare : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text('生成对比 (${_selected.length})'),
                ),
              ),
            )
          : null,
      body: async.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 3,
          itemBuilder: (_, _) => const ProfessorCardSkeleton(),
        ),
        error: (error, stackTrace) => ErrorView(
          error: normalizeAppException(error, stackTrace),
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(message: '还没有收藏导师');
          }
          return RefreshIndicator(
            color: AppColors.indigo,
            onRefresh: () async {
              ref.invalidate(favoritesProvider);
              await ref.read(favoritesProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                Widget tile = _FavoriteTile(
                  item: item,
                  selecting: _selecting,
                  selected: _selected.contains(item.professorId),
                  onToggleSelect: () => _toggleSelect(item.professorId),
                );
                if (!_selecting) {
                  tile = Dismissible(
                    key: ValueKey(item.professorId),
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
                    onDismissed: (_) async {
                      Haptics.medium();
                      try {
                        await ref
                            .read(favoriteRepositoryProvider)
                            .remove(item.professorId);
                      } catch (error, stackTrace) {
                        ref
                            .read(apiErrorReporterProvider.notifier)
                            .report('取消收藏失败', error, stackTrace);
                        return;
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('已删除收藏'),
                          action: SnackBarAction(
                            label: '撤销',
                            onPressed: () async {
                              Haptics.success();
                              try {
                                await ref
                                    .read(favoriteRepositoryProvider)
                                    .add(item);
                              } catch (error, stackTrace) {
                                ref
                                    .read(apiErrorReporterProvider.notifier)
                                    .report('恢复收藏失败', error, stackTrace);
                              }
                            },
                          ),
                        ),
                      );
                    },
                    child: tile,
                  );
                }
                return AnimatedEntrance(index: index, child: tile);
              },
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({
    required this.item,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
  });

  final FavoriteItem item;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: selecting
            ? onToggleSelect
            : () => context.push('/professor/${item.professorId}'),
        onLongPress: selecting ? null : () => _showPreview(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selecting)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
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
                  if (!selecting)
                    IconButton(
                      tooltip: '取消收藏',
                      icon: const Icon(Icons.bookmark_remove_outlined),
                      onPressed: () async {
                        try {
                          await ref
                              .read(favoriteRepositoryProvider)
                              .remove(item.professorId);
                        } catch (error, stackTrace) {
                          ref
                              .read(apiErrorReporterProvider.notifier)
                              .report('取消收藏失败', error, stackTrace);
                        }
                      },
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
              if (!selecting) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _openHomepage(context, ref, item.homepageUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('访问主页'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPreview(BuildContext context, WidgetRef ref) {
    Haptics.heavy();
    final textTheme = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${item.university} / ${item.college}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FieldChips(fields: item.researchFields),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/professor/${item.professorId}');
                      },
                      child: const Text('查看详情'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        try {
                          await ref
                              .read(favoriteRepositoryProvider)
                              .remove(item.professorId);
                        } catch (error, stackTrace) {
                          ref
                              .read(apiErrorReporterProvider.notifier)
                              .report('取消收藏失败', error, stackTrace);
                        }
                      },
                      child: const Text('取消收藏'),
                    ),
                  ),
                ],
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
