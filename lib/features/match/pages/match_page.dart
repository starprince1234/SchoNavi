import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/ui/app_bottom_sheet.dart';
import '../../../domain/entities/match_analysis.dart';
import '../../../domain/entities/professor.dart';
import '../../../features/professor/providers/professor_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/radar_chart.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../../core/haptics/haptics.dart';
import '../../../shared/widgets/animated_entrance.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/match_provider.dart';

class MatchPage extends ConsumerStatefulWidget {
  const MatchPage({super.key, required this.professorId});

  final String professorId;

  @override
  ConsumerState<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends ConsumerState<MatchPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(matchProvider.notifier).start(widget.professorId);
    });
  }

  Future<void> _analyze(Professor professor) async {
    final profile = ref.read(profileProvider);
    if (profile.isEmpty) {
      final store = ref.read(localStoreProvider);
      final agreed = store.getBool('privacy_agreed') ?? false;
      if (!agreed) {
        context.push('/profile/privacy');
      } else {
        context.push('/profile/intro');
      }
      return;
    }
    await ref
        .read(matchProvider.notifier)
        .analyze(professor: professor, profile: profile);
  }

  @override
  Widget build(BuildContext context) {
    final professorAsync = ref.watch(professorProvider(widget.professorId));
    final match = ref.watch(matchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('匹配分析')),
      body: professorAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is AppException ? error.message : '出错了，请稍后重试',
          onRetry: () => ref.invalidate(professorProvider(widget.professorId)),
        ),
        data: (professor) => _buildBody(professor, match),
      ),
    );
  }

  Widget _buildBody(Professor professor, MatchState match) {
    return switch (match.status) {
      MatchStatus.idle => _IdlePrompt(
        professor: professor,
        onAnalyze: () => _analyze(professor),
      ),
      MatchStatus.analyzing => const LoadingView(label: '正在分析匹配情况...'),
      MatchStatus.error => ErrorView(
        message: match.message ?? '分析失败，请重试',
        onRetry: () => _analyze(professor),
      ),
      MatchStatus.ready => _AnalysisView(
        analysis: match.analysis!,
        onRegenerate: () => _analyze(professor),
      ),
    };
  }
}

class _IdlePrompt extends StatelessWidget {
  const _IdlePrompt({required this.professor, required this.onAnalyze});

  final Professor professor;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              '分析你与 ${professor.name}${professor.title} 的匹配情况',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '将结合导师研究方向与你的背景，给出匹配点、差距与准备建议。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('开始匹配分析'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisView extends StatelessWidget {
  const _AnalysisView({required this.analysis, required this.onRegenerate});

  final MatchAnalysis analysis;
  final VoidCallback onRegenerate;

  void _showDimension(BuildContext context, MatchDimension dimension) {
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dimension.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${dimension.score}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dimension.comment,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overall = analysis.overallScore;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedEntrance(
          index: 0,
          child: BentoTile(
            color: Theme.of(context).colorScheme.surfaceContainer,
            padding: const EdgeInsets.all(12),
            child: const Text('本分析仅供参考，不预测录取概率，请结合实际情况判断。'),
          ),
        ),
        if (analysis.dimensions.isNotEmpty) ...[
          const SizedBox(height: 16),
          AnimatedEntrance(
            index: 1,
            child: BentoTile(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (overall != null)
                    StatTile(value: overall, label: '综合契合度（信息性）'),
                  const SizedBox(height: 8),
                  RadarChart(
                    dimensions: analysis.dimensions,
                    onAxisTap: (index) {
                      Haptics.selection();
                      _showDimension(context, analysis.dimensions[index]);
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '点任一维度查看 AI 解读',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        AnimatedEntrance(
          index: 2,
          child: BentoTile(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('总体匹配'),
                const SizedBox(height: 6),
                Text(analysis.summary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedEntrance(
          index: 3,
          child: _Section(
            icon: Icons.check_circle_outline,
            title: '匹配点',
            items: analysis.strengths,
          ),
        ),
        const SizedBox(height: 18),
        AnimatedEntrance(
          index: 4,
          child: _Section(
            icon: Icons.report_problem_outlined,
            title: '差距与短板',
            items: analysis.gaps,
          ),
        ),
        const SizedBox(height: 18),
        AnimatedEntrance(
          index: 5,
          child: _Section(
            icon: Icons.lightbulb_outline,
            title: '准备建议',
            items: analysis.suggestions,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onRegenerate,
            icon: const Icon(Icons.refresh),
            label: const Text('重新生成'),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return BentoTile(
      color: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 6),
              Text(title, style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('暂无')
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('· '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
