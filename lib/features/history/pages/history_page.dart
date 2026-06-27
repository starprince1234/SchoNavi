import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/result/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/fork_ref.dart';
import '../../../domain/entities/search_history_item.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/empty_view.dart';
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

  Future<void> _deleteSession(SearchHistoryItem item) async {
    final chat = ref.read(chatRepositoryProvider);
    final forksRes = await chat.listForks(mainSessionId: item.sessionId);
    if (forksRes is Success<List<ForkRef>>) {
      for (final f in forksRes.data) {
        await chat.deleteFork(forkId: f.forkId);
      }
    }
    if (!mounted) return;
    await ref.read(historyRepositoryProvider).remove(item.sessionId);
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
                    color: AppColors.indigo,
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
                            onDismissed: (_) async {
                              Haptics.medium();
                              await _deleteSession(item);
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(content: Text('已删除')),
                                );
                              }
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

class _HistoryTile extends ConsumerStatefulWidget {
  const _HistoryTile({required this.item});

  final SearchHistoryItem item;

  @override
  ConsumerState<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends ConsumerState<_HistoryTile> {
  bool _expanded = false;
  List<ForkRef>? _forks;
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() {
      _expanded = !_expanded;
      if (!_expanded) _forks = null;
    });
    if (_expanded && _forks == null && !_loading) {
      setState(() => _loading = true);
      final res = await ref
          .read(chatRepositoryProvider)
          .listForks(mainSessionId: widget.item.sessionId);
      if (mounted) {
        setState(() {
          _forks = res is Success<List<ForkRef>> ? res.data : const [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.prompt,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.add,
                      size: 16,
                      color: Color(0xFF6A6385),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildForks(context),
          ),
        ],
      ),
    );
  }

  Widget _buildForks(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final forks = _forks ?? const <ForkRef>[];
    if (forks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Text('暂无追问历史',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          for (final f in forks)
                _ForkSubTile(
                  fork: f,
                  onDeleted: () => setState(
                    () => _forks?.removeWhere((x) => x.forkId == f.forkId),
                  ),
                ),
        ],
      ),
    );
  }
}

class _ForkSubTile extends ConsumerWidget {
  const _ForkSubTile({required this.fork, required this.onDeleted});

  final ForkRef fork;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = (fork.college == null || fork.college!.isEmpty)
        ? fork.university
        : '${fork.university} · ${fork.college}';
    return Dismissible(
      key: ValueKey(fork.forkId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await ref.read(chatRepositoryProvider).deleteFork(forkId: fork.forkId);
        onDeleted();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除追问')),
          );
        }
      },
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.indigo,
          child: Text(
            fork.avatarLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          fork.professorName,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: textTheme.bodySmall),
        trailing: Text(_formatTime(fork.createdAt), style: textTheme.bodySmall),
        onTap: () => context.push(
          '/chat?fork=true&fid=${Uri.encodeComponent(fork.forkId)}',
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
        child: Row(
          children: [
            Expanded(
              child: ShimmerSkeleton(height: 16, width: double.infinity),
            ),
            SizedBox(width: 8),
            ShimmerSkeleton(height: 16, width: 16),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime v) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(v.hour)}:${two(v.minute)}';
}

String _historyTypeLabel(SearchHistoryType type) => switch (type) {
  SearchHistoryType.competition => '竞赛',
  SearchHistoryType.mentor => '导师',
};
