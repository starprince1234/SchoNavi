import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calendar_date.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/fixtures/competition_timeline_defaults.dart';
import '../../../domain/entities/preparation_plan.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../shared/widgets/bento_tile.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/preparation_providers.dart';
import '../widgets/preparation_date_picker.dart';

/// 备赛计划创建表单（spec §8 / D11 / P2.6）。
///
/// 时间模型 SegmentedButton（窗口型/提交型）按 [CompetitionTimelineDefaults]
/// 预选；日期入口调用 [showPreparationDatePicker]，窗口型用 range 选比赛起止，
/// 提交型用 multiAnchor 选 DDL + 可选答辩。提交校验通过后传全字段生成。
class PreparationPlanFormPage extends ConsumerStatefulWidget {
  const PreparationPlanFormPage({super.key, required this.competition});

  final CompetitionSnapshot competition;

  @override
  ConsumerState<PreparationPlanFormPage> createState() =>
      _PreparationPlanFormPageState();
}

class _PreparationPlanFormPageState
    extends ConsumerState<PreparationPlanFormPage> {
  late CompetitionTimelineType _timelineType;
  DateTime? _targetDate;
  DateTime? _eventEndDate;
  DateTime? _defenseDate;
  WeeklyCommitment _weeklyCommitment = WeeklyCommitment.hours6to10;
  late ExperienceLevel _experienceLevel;
  bool _submitting = false;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    _timelineType = CompetitionTimelineDefaults.defaultFor(widget.competition.id) ??
        CompetitionTimelineType.submission;
    _experienceLevel = _experienceFromProfile(ref.read(profileProvider));
  }

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

  String get _dateRowLabel => _timelineType == CompetitionTimelineType.eventWindow
      ? '选择比赛起止日期'
      : '选择提交 DDL 与答辩';

  String get _dateRowValue {
    if (_targetDate == null) return '';
    if (_timelineType == CompetitionTimelineType.eventWindow) {
      if (_eventEndDate == null) return _fmt(_targetDate!);
      return '${_fmt(_targetDate!)} – ${_fmt(_eventEndDate!)}';
    }
    if (_defenseDate == null) return 'DDL ${_fmt(_targetDate!)}';
    return 'DDL ${_fmt(_targetDate!)} · 答辩 ${_fmt(_defenseDate!)}';
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = CalendarDate.normalize(now);
    final mode = _timelineType == CompetitionTimelineType.eventWindow
        ? PreparationDatePickerMode.range
        : PreparationDatePickerMode.multiAnchor;
    final picked = await showPreparationDatePicker(
      context: context,
      mode: mode,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 3)),
      initial: _initialSelection(),
    );
    if (picked == null) return;
    setState(() {
      if (_timelineType == CompetitionTimelineType.eventWindow) {
        _targetDate = picked.rangeStart;
        _eventEndDate = picked.rangeEnd;
        _defenseDate = null;
      } else {
        _targetDate = picked.deadline;
        _eventEndDate = null;
        _defenseDate = picked.defense;
      }
      _dateError = _validate(today);
    });
  }

  PreparationDateSelection _initialSelection() {
    if (_timelineType == CompetitionTimelineType.eventWindow) {
      return PreparationDateSelection(
        rangeStart: _targetDate,
        rangeEnd: _eventEndDate,
      );
    }
    return PreparationDateSelection(
      deadline: _targetDate,
      defense: _defenseDate,
    );
  }

  String? _validate(DateTime today) {
    if (_timelineType == CompetitionTimelineType.eventWindow) {
      final start = _targetDate;
      final end = _eventEndDate;
      if (start == null || end == null) return '请选择比赛起止日期';
      if (end.isBefore(start)) return '结束日期不能早于开始日期';
      if (!start.isAfter(today)) return '比赛开始日期必须晚于今天';
      return null;
    }
    final deadline = _targetDate;
    if (deadline == null) return '请选择提交截止日期';
    if (!deadline.isAfter(today)) return '提交截止日期必须晚于今天';
    if (_defenseDate != null && !_defenseDate!.isAfter(deadline)) {
      return '答辩日期必须晚于提交截止日期';
    }
    return null;
  }

  Future<void> _submit() async {
    final today = CalendarDate.normalize(DateTime.now());
    final err = _validate(today);
    if (err != null) {
      setState(() => _dateError = err);
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
            timelineType: _timelineType,
            targetDate: _targetDate!,
            eventEndDate: _eventEndDate,
            defenseDate: _defenseDate,
            weeklyCommitment: _weeklyCommitment,
            experienceLevel: _experienceLevel,
            calendarToday: CalendarDate.normalize(DateTime.now()),
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
          _sectionLabel('时间模型'),
          _timelineSelector(cs),
          const SizedBox(height: 16),
          _sectionLabel('比赛日期'),
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
                    _dateRowValue.isEmpty ? _dateRowLabel : _dateRowValue,
                    style: TextStyle(
                      color: _dateRowValue.isEmpty
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

  Widget _timelineSelector(ColorScheme cs) {
    return SegmentedButton<CompetitionTimelineType>(
      selected: {_timelineType},
      onSelectionChanged: _submitting
          ? null
          : (s) => setState(() {
                _timelineType = s.first;
                _targetDate = null;
                _eventEndDate = null;
                _defenseDate = null;
                _dateError = null;
              }),
      segments: const [
        ButtonSegment(
          value: CompetitionTimelineType.eventWindow,
          label: Text('窗口型'),
        ),
        ButtonSegment(
          value: CompetitionTimelineType.submission,
          label: Text('提交型'),
        ),
      ],
    );
  }

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
