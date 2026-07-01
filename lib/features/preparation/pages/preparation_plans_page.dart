import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../shared/widgets/empty_view.dart';
import '../providers/preparation_reminder_providers.dart';
import '../providers/preparation_providers.dart';
import '../widgets/preparation_plan_list_tile.dart';

enum _PlanFilter { active, archived }

/// 我的备赛列表页（spec §7.4）。
///
/// AppBar「我的备赛」。watch [preparationPlanListProvider] → 渲染
/// [PreparationPlanListTile] 行。顶部 SegmentedButton 进行中/已归档筛选，
/// 默认进行中（归档默认隐藏）。列表按 `updatedAt` 倒序。空态 [EmptyView]。
/// 行点击 `context.push('/preparation-plans/${plan.id}')`。
class PreparationPlansPage extends ConsumerStatefulWidget {
  const PreparationPlansPage({super.key});

  @override
  ConsumerState<PreparationPlansPage> createState() =>
      _PreparationPlansPageState();
}

class _PreparationPlansPageState extends ConsumerState<PreparationPlansPage> {
  _PlanFilter _filter = _PlanFilter.active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final asyncList = ref.watch(preparationPlanListProvider);

    final desired = _filter == _PlanFilter.active
        ? PreparationPlanStatus.active
        : PreparationPlanStatus.archived;

    return Scaffold(
      backgroundColor: AppColors.paperOf(isDark),
      appBar: AppBar(
        title: const Text('我的备赛'),
        backgroundColor: AppColors.paperOf(isDark),
        elevation: 0,
        foregroundColor: AppColors.inkOf(isDark),
        actions: [
          IconButton(
            key: const Key('preparation-pin-widget-button'),
            tooltip: '添加桌面小组件',
            icon: const Icon(Icons.widgets_outlined),
            onPressed: _pinWidget,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: SegmentedButton<_PlanFilter>(
              segments: const [
                ButtonSegment(value: _PlanFilter.active, label: Text('进行中')),
                ButtonSegment(value: _PlanFilter.archived, label: Text('已归档')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: asyncList.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyView(message: '加载失败：$e'),
              data: (plans) {
                final filtered =
                    plans.where((p) => p.status == desired).toList()
                      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                if (filtered.isEmpty) {
                  return EmptyView(
                    message: _filter == _PlanFilter.active
                        ? '暂无进行中的备赛计划'
                        : '暂无已归档的备赛计划',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final plan = filtered[i];
                    return PreparationPlanListTile(
                      plan: plan,
                      onTap: () =>
                          context.push('/preparation-plans/${plan.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pinWidget() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final requested = await ref
          .read(preparationReminderPlatformProvider)
          .pinWidget();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            requested
                ? '已向系统发起添加桌面小组件请求'
                : '当前设备不支持一键添加，请从系统桌面长按添加 SchoNavi 小组件',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('添加小组件失败，请稍后重试')));
    }
  }
}
