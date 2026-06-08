import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
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

class _Detail extends StatelessWidget {
  const _Detail({required this.professor});

  final Professor professor;

  @override
  Widget build(BuildContext context) {
    final p = professor;
    final textTheme = Theme.of(context).textTheme;
    String orNa(String? v) => (v == null || v.isEmpty) ? '暂无信息' : v;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${p.name}  ${p.title}', style: textTheme.headlineSmall),
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
      ],
    );
  }
}
