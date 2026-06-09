import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/launcher/link_launcher.dart';
import '../../../domain/entities/favorite_item.dart';
import '../../../domain/entities/professor.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/field_chips.dart';
import '../../../shared/widgets/loading_view.dart';
import '../providers/professor_provider.dart';

class ProfessorPage extends ConsumerWidget {
  const ProfessorPage({super.key, required this.professorId});

  final String professorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(professorProvider(professorId));
    return Scaffold(
      appBar: AppBar(title: const Text('导师详情')),
      floatingActionButton: async.maybeWhen(
        data: (p) => FloatingActionButton.extended(
          onPressed: () => context.push(
            '/chat?sid=${Uri.encodeComponent('s_prof_${p.id}')}'
            '&pid=${Uri.encodeComponent(p.id)}',
          ),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('继续追问'),
        ),
        orElse: () => null,
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : '出错了，请稍后重试',
          onRetry: () => ref.invalidate(professorProvider(professorId)),
        ),
        data: (p) => _Detail(professor: p),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.professor});

  final Professor professor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = professor;
    final textTheme = Theme.of(context).textTheme;
    final isFavorite = ref
        .watch(favoriteStatusProvider(p.id))
        .maybeWhen(data: (value) => value, orElse: () => false);
    String orNa(String? v) => (v == null || v.isEmpty) ? '暂无信息' : v;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${p.name}  ${p.title}',
                style: textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: isFavorite ? '取消收藏' : '收藏导师',
              icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
              onPressed: () => ref
                  .read(favoriteRepositoryProvider)
                  .toggle(FavoriteItem.fromProfessor(p)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('${p.university} / ${p.college}', style: textTheme.bodyMedium),
        const Divider(height: 28),
        Text('研究方向', style: textTheme.titleMedium),
        const SizedBox(height: 6),
        FieldChips(fields: p.researchFields),
        const SizedBox(height: 16),
        Text('简介', style: textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(orNa(p.bio)),
        const SizedBox(height: 16),
        Text('数据来源', style: textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(orNa(p.sourceUrl)),
        const SizedBox(height: 6),
        Text('更新时间：${orNa(p.updatedAt)}'),
        const SizedBox(height: 16),
        Text('主页', style: textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(orNa(p.homepageUrl)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _openHomepage(context, ref, p.homepageUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('访问主页'),
          ),
        ),
      ],
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
