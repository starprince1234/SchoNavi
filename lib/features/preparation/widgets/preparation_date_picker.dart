import 'package:flutter/material.dart';

import '../../../core/calendar_date.dart';
import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';

enum PreparationDatePickerMode { single, range, multiAnchor }

class PreparationDateSelection {
  const PreparationDateSelection({
    this.single,
    this.rangeStart,
    this.rangeEnd,
    this.deadline,
    this.defense,
  });
  final DateTime? single;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final DateTime? deadline;
  final DateTime? defense;
}

Future<PreparationDateSelection?> showPreparationDatePicker({
  required BuildContext context,
  required PreparationDatePickerMode mode,
  required DateTime firstDate,
  required DateTime lastDate,
  PreparationDateSelection? initial,
}) {
  return showModalBottomSheet<PreparationDateSelection>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PreparationDatePickerSheet(
      mode: mode,
      firstDate: CalendarDate.normalize(firstDate),
      lastDate: CalendarDate.normalize(lastDate),
      initial: initial,
    ),
  );
}

class _PreparationDatePickerSheet extends StatefulWidget {
  const _PreparationDatePickerSheet({
    required this.mode,
    required this.firstDate,
    required this.lastDate,
    this.initial,
  });
  final PreparationDatePickerMode mode;
  final DateTime firstDate;
  final DateTime lastDate;
  final PreparationDateSelection? initial;

  @override
  State<_PreparationDatePickerSheet> createState() =>
      _PreparationDatePickerSheetState();
}

class _PreparationDatePickerSheetState
    extends State<_PreparationDatePickerSheet> {
  late DateTime _focusedMonth;
  DateTime? _single;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime? _deadline;
  DateTime? _defense;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final init = widget.initial;
    if (init != null) {
      _single = init.single;
      _rangeStart = init.rangeStart;
      _rangeEnd = init.rangeEnd;
      _deadline = init.deadline;
      _defense = init.defense;
    }
  }

  bool get _canConfirm {
    switch (widget.mode) {
      case PreparationDatePickerMode.single:
        return _single != null;
      case PreparationDatePickerMode.range:
        return _rangeStart != null && _rangeEnd != null;
      case PreparationDatePickerMode.multiAnchor:
        if (_deadline == null) return false;
        if (_defense != null && !_defense!.isAfter(_deadline!)) return false;
        return true;
    }
  }

  void _selectDay(DateTime day) {
    Haptics.selection();
    setState(() {
      switch (widget.mode) {
        case PreparationDatePickerMode.single:
          _single = day;
          break;
        case PreparationDatePickerMode.range:
          if (_rangeStart == null ||
              (_rangeStart != null && _rangeEnd != null)) {
            _rangeStart = day;
            _rangeEnd = null;
          } else {
            if (!day.isBefore(_rangeStart!)) {
              _rangeEnd = day;
            } else {
              _rangeEnd = _rangeStart;
              _rangeStart = day;
            }
          }
          break;
        case PreparationDatePickerMode.multiAnchor:
          if (_deadline == null || (_defense != null && day == _defense)) {
            if (_defense != null && day == _defense) {
              _defense = null;
            } else {
              _deadline = day;
            }
          } else if (_defense == null && day.isAfter(_deadline!)) {
            _defense = day;
          } else {
            _deadline = day;
            _defense = null;
          }
          break;
      }
    });
  }

  PreparationDateSelection _result() {
    switch (widget.mode) {
      case PreparationDatePickerMode.single:
        return PreparationDateSelection(single: _single);
      case PreparationDatePickerMode.range:
        return PreparationDateSelection(
          rangeStart: _rangeStart,
          rangeEnd: _rangeEnd,
        );
      case PreparationDatePickerMode.multiAnchor:
        return PreparationDateSelection(deadline: _deadline, defense: _defense);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 8),
                    _monthNav(),
                    const SizedBox(height: 4),
                    _weekHeader(),
                    _grid(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _statusText(),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _canConfirm
                  ? () => Navigator.pop(context, _result())
                  : null,
              child: const Align(
                alignment: Alignment.center,
                child: Text('确认'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final title = switch (widget.mode) {
      PreparationDatePickerMode.single => '选择日期',
      PreparationDatePickerMode.range => '选择比赛起止日期',
      PreparationDatePickerMode.multiAnchor => '选择提交 DDL 与答辩',
    };
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _monthNav() {
    final cs = Theme.of(context).colorScheme;
    final label =
        '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';
    final canPrev = !_focusedMonth.isBefore(
      DateTime(widget.firstDate.year, widget.firstDate.month),
    );
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    final canNext = !next.isAfter(widget.lastDate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: canPrev
              ? () => setState(
                  () => _focusedMonth = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month - 1,
                  ),
                )
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          label,
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: canNext
              ? () => setState(() => _focusedMonth = next)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _weekHeader() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: const TextStyle(
                    color: AppColors.inkFaint,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _grid() {
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lead = firstOfMonth.weekday - 1;
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_focusedMonth.year, _focusedMonth.month, d);
      final inRange =
          !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);
      cells.add(_dayCell(day, inRange));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  Widget _dayCell(DateTime day, bool inRange) {
    final cs = Theme.of(context).colorScheme;
    final selected = _isSelected(day);
    final inSpan = _inSelectedSpan(day);
    Color? bg;
    Color fg = cs.onSurface;
    if (selected) {
      bg = AppColors.indigo;
      fg = Colors.white;
    } else if (inSpan) {
      bg = AppColors.indigoSoft;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: inRange ? () => _selectDay(day) : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text('${day.day}', style: TextStyle(color: fg)),
      ),
    );
  }

  bool _isSelected(DateTime day) {
    switch (widget.mode) {
      case PreparationDatePickerMode.single:
        return day == _single;
      case PreparationDatePickerMode.range:
        return day == _rangeStart || day == _rangeEnd;
      case PreparationDatePickerMode.multiAnchor:
        return day == _deadline || day == _defense;
    }
  }

  bool _inSelectedSpan(DateTime day) {
    if (widget.mode != PreparationDatePickerMode.range) return false;
    if (_rangeStart == null || _rangeEnd == null) return false;
    return !day.isBefore(_rangeStart!) &&
        !day.isAfter(_rangeEnd!) &&
        day != _rangeStart &&
        day != _rangeEnd;
  }

  Widget _statusText() {
    String text;
    switch (widget.mode) {
      case PreparationDatePickerMode.single:
        text = _single == null
            ? '请选择日期'
            : '已选 ${CalendarDate.toIsoDay(_single!)}';
        break;
      case PreparationDatePickerMode.range:
        if (_rangeStart == null) {
          text = '请选择比赛开始日';
        } else if (_rangeEnd == null) {
          text = '开始 ${CalendarDate.toIsoDay(_rangeStart!)}，请选结束日';
        } else {
          text =
              '比赛 ${CalendarDate.toIsoDay(_rangeStart!)} – ${CalendarDate.toIsoDay(_rangeEnd!)}';
        }
        break;
      case PreparationDatePickerMode.multiAnchor:
        final dl = _deadline == null ? '未选' : CalendarDate.toIsoDay(_deadline!);
        final df = _defense == null ? '无' : CalendarDate.toIsoDay(_defense!);
        text = '提交 DDL：$dl · 答辩：$df';
        break;
    }
    return Text(
      text,
      style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
    );
  }
}
