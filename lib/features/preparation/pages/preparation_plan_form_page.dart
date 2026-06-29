import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/preparation_providers.dart';

/// 备赛计划创建表单（spec §8 / D11）。
///
/// 三段单选：目标日期（DatePicker，必须晚于当天）、每周投入（4 档）、
/// 当前水平（3 档，从 [UserProfile] 预填不回写）。AI 模式下额外提示
/// 会发送档案用于个性化建议。提交校验通过后调生成器 → 入库 →
/// `context.pushReplacement('/preparation-plans/${plan.id}')`。
class PreparationPlanFormPage extends ConsumerStatefulWidget {
  const PreparationPlanFormPage({super.key, required this.competition});

  final CompetitionSnapshot competition;

  @override
  ConsumerState<PreparationPlanFormPage> createState() =>
      _PreparationPlanFormPageState();
}

class _PreparationPlanFormPageState
    extends ConsumerState<PreparationPlanFormPage> {
  DateTime? _targetDate;
  WeeklyCommitment _weeklyCommitment = WeeklyCommitment.hours6to10;
  late ExperienceLevel _experienceLevel;
  bool _submitting = false;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _experienceLevel = _experienceFromProfile(ref.read(profileProvider));
  }

  /// 从 [UserProfile] 推断经验等级；信息不足时退回 beginner。
  ///
  /// 当前 UserProfile 无显式等级字段，这里以「竞赛成果条目数量 + 是否有
  /// 获奖」做粗略映射：>=2 条且有 award → experienced；>=1 条 → intermediate；
  /// 否则 beginner。映射不清晰时一律 beginner。
  ExperienceLevel _experienceFromProfile(UserProfile profile) {
    try {
      final comps = profile.competitions;
      if (comps.length >= 2 && comps.any((c) => (c.award ?? '').isNotEmpty)) {
        return ExperienceLevel.experienced;
      }
      if (comps.isNotEmpty) {
        return ExperienceLevel.intermediate;
      }
    } catch (_) {
      // 防御：任何意外都退回默认。
    }
    return ExperienceLevel.beginner;
  }

  bool get _isAiMode {
    final cfg = ref.watch(appConfigProvider);
    return cfg.dataSource == DataSource.llm && cfg.llm.isConfigured;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      _targetDate = picked;
      // 必须严格晚于当天（spec §8：targetDate > today）。
      _dateError = picked.isAfter(today) ? null : '目标日期必须晚于今天';
    });
  }

  Future<void> _submit() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_targetDate == null || !_targetDate!.isAfter(today)) {
      setState(() => _dateError = '请选择目标日期');
      return;
    }
    setState(() {
      _submitting = true;
      _dateError = null;
    });
    try {
      final plan = await ref
          .read(preparationPlanGeneratorProvider)
          .generate(
            competition: widget.competition,
            timelineType: CompetitionTimelineType.submission,
            targetDate: _targetDate!,
            eventEndDate: null,
            defenseDate: null,
            weeklyCommitment: _weeklyCommitment,
            experienceLevel: _experienceLevel,
            calendarToday: DateTime.now(),
            profile: ref.read(profileProvider),
          );
      await ref.read(preparationPlanRepositoryProvider).save(plan);
      if (!mounted) return;
      context.pushReplacement('/preparation-plans/${plan.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('生成失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('创建备赛计划')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          BentoTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      size: 20,
                      color: AppColors.indigo,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.competition.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.competition.category,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionLabel('目标日期'),
          BentoTile(
            onTap: _submitting ? null : _pickDate,
            child: Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 20,
                  color: AppColors.indigo,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _targetDate == null
                        ? '点击选择目标日期'
                        : '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _targetDate == null
                          ? AppColors.inkFaint
                          : cs.onSurface,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.inkFaint,
                ),
              ],
            ),
          ),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                _dateError!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          _sectionLabel('每周投入'),
          _commitmentSelector(cs),
          const SizedBox(height: 16),
          _sectionLabel('当前水平'),
          _experienceSelector(cs),
          if (_isAiMode) ...[const SizedBox(height: 16), _aiNotice()],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.rocket_launch_outlined),
            label: const Text('创建备赛计划'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _commitmentSelector(ColorScheme cs) {
    return SegmentedButton<WeeklyCommitment>(
      selected: {_weeklyCommitment},
      onSelectionChanged: _submitting
          ? null
          : (s) => setState(() => _weeklyCommitment = s.first),
      segments: const [
        ButtonSegment(value: WeeklyCommitment.hours3to5, label: Text('3-5h')),
        ButtonSegment(value: WeeklyCommitment.hours6to10, label: Text('6-10h')),
        ButtonSegment(
          value: WeeklyCommitment.hours11to15,
          label: Text('11-15h'),
        ),
        ButtonSegment(value: WeeklyCommitment.hours16plus, label: Text('16h+')),
      ],
    );
  }

  Widget _experienceSelector(ColorScheme cs) {
    return SegmentedButton<ExperienceLevel>(
      selected: {_experienceLevel},
      onSelectionChanged: _submitting
          ? null
          : (s) => setState(() => _experienceLevel = s.first),
      segments: const [
        ButtonSegment(value: ExperienceLevel.beginner, label: Text('新手')),
        ButtonSegment(value: ExperienceLevel.intermediate, label: Text('进阶')),
        ButtonSegment(value: ExperienceLevel.experienced, label: Text('老手')),
      ],
    );
  }

  Widget _aiNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.indigoSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI 模式会发送你的档案用于个性化建议',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.indigo.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
