import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../domain/entities/comparison_report.dart';
import '../../../domain/entities/professor.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../providers/compare_provider.dart';

class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key, required this.ids});

  final List<String> ids;

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(compareProvider.notifier).load(widget.ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(compareProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('导师对比')),
      body: switch (state.status) {
        CompareStatus.loading => const LoadingView(label: '正在生成对比...'),
        CompareStatus.error => ErrorView(
          message: state.message ?? '生成对比失败，请重试',
          onRetry: () => ref.read(compareProvider.notifier).load(widget.ids),
        ),
        CompareStatus.ready => _ReportView(
          professors: state.professors,
          report: state.report!,
        ),
      },
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.professors, required this.report});

  final List<Professor> professors;
  final ComparisonReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final byId = {for (final p in professors) p.id: p};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final id in report.professorIds)
              Expanded(
                child: InkWell(
                  key: Key('compare-header-$id'),
                  onTap: () => context.push('/professor/$id'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          byId[id]?.name ?? id,
                          style: textTheme.titleSmall,
                        ),
                        Text(
                          byId[id]?.university ?? '',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 24),
        for (final row in report.rows) ...[
          Text(row.dimension, style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final id in report.professorIds)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(row.cells[id] ?? '-'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const Divider(height: 24),
        Text('总体小结', style: textTheme.titleMedium),
        const SizedBox(height: 6),
        GptMarkdown(report.summary),
        const SizedBox(height: 16),
        Text('选择建议', style: textTheme.titleMedium),
        const SizedBox(height: 6),
        GptMarkdown(report.suggestion),
        const SizedBox(height: 16),
        const Text(
          '提示：对比为 AI 生成，招生等信息请以学校官网与导师主页为准。',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
