import 'package:flutter/material.dart';

import '../../../domain/entities/academic_score.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../../../shared/widgets/labeled_text_field.dart';

/// 专业排名输入：不填 / 百分制 / 名次 三选一，受限数字输入 + 即时校验。
/// 不合法时不回调 onChanged（外部 state 保持上一个合法值）+ errorText 标红。
class RankField extends StatelessWidget {
  const RankField({super.key, required this.value, required this.onChanged});

  final AcademicScore value;
  final ValueChanged<AcademicScore> onChanged;

  static const List<(RankMode, String)> _modes = [
    (RankMode.none, '不填'),
    (RankMode.percent, '百分制'),
    (RankMode.ordinal, '名次'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '专业排名',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ChoiceChipGroup<RankMode>(
          options: _modes,
          selected: value.rankMode,
          onSelected: (m) => onChanged(value.withRank(mode: m)),
        ),
        const SizedBox(height: 12),
        _buildInput(),
      ],
    );
  }

  Widget _buildInput() {
    switch (value.rankMode) {
      case RankMode.none:
        return const SizedBox.shrink();
      case RankMode.percent:
        return _PercentInput(value: value, onChanged: onChanged);
      case RankMode.ordinal:
        return _OrdinalInput(value: value, onChanged: onChanged);
    }
  }
}

class _PercentInput extends StatefulWidget {
  const _PercentInput({required this.value, required this.onChanged});

  final AcademicScore value;
  final ValueChanged<AcademicScore> onChanged;

  @override
  State<_PercentInput> createState() => _PercentInputState();
}

class _PercentInputState extends State<_PercentInput> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LabeledTextField(
            fieldKey: const Key('rank-percent'),
            label: '前',
            initialValue: widget.value.percent?.toString(),
            keyboardType: TextInputType.number,
            hintText: '1–100',
            errorText: _error,
            onChanged: _onChanged,
          ),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(top: 30),
          child: Text(
            '%',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  void _onChanged(String raw) {
    final v = int.tryParse(raw.trim());
    if (v == null || v < 1 || v > 100) {
      setState(() => _error = '请输入 1–100');
      return; // 不回调
    }
    setState(() => _error = null);
    widget.onChanged(widget.value.withRank(mode: RankMode.percent, percent: v));
  }
}

class _OrdinalInput extends StatefulWidget {
  const _OrdinalInput({required this.value, required this.onChanged});

  final AcademicScore value;
  final ValueChanged<AcademicScore> onChanged;

  @override
  State<_OrdinalInput> createState() => _OrdinalInputState();
}

class _OrdinalInputState extends State<_OrdinalInput> {
  // 跟踪两个框的当前文本（LabeledTextField 自管 controller，onChanged 回传字符串）。
  late String _posText = widget.value.rankPosition?.toString() ?? '';
  late String _totalText = widget.value.rankTotal?.toString() ?? '';
  String? _posError;
  String? _totalError;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LabeledTextField(
            fieldKey: const Key('rank-position'),
            label: '第',
            initialValue: _posText,
            keyboardType: TextInputType.number,
            hintText: '名次',
            errorText: _posError,
            onChanged: (v) {
              _posText = v;
              _validate();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LabeledTextField(
            fieldKey: const Key('rank-total'),
            label: '共',
            initialValue: _totalText,
            keyboardType: TextInputType.number,
            hintText: '总人数',
            errorText: _totalError,
            onChanged: (v) {
              _totalText = v;
              _validate();
            },
          ),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(top: 30),
          child: Text(
            '人',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  void _validate() {
    final posText = _posText.trim();
    final totalText = _totalText.trim();
    final pos = int.tryParse(posText);
    final total = int.tryParse(totalText);

    // 半填：至少一个有输入但不全 -> 提示补全，不回调
    if (posText.isEmpty || totalText.isEmpty) {
      if (posText.isNotEmpty || totalText.isNotEmpty) {
        setState(() {
          _posError = '请补全名次和总人数';
          _totalError = null;
        });
      } else {
        setState(() {
          _posError = null;
          _totalError = null;
        });
      }
      return; // 不回调
    }
    // 非数字 -> 对应框标红，不回调
    if (pos == null || total == null) {
      setState(() {
        _posError = pos == null ? '请输入数字' : null;
        _totalError = total == null ? '请输入数字' : null;
      });
      return; // 不回调
    }
    // 名次 > 总人数 -> 名次框标红，不回调
    if (pos > total) {
      setState(() {
        _posError = '名次不能大于总人数';
        _totalError = null;
      });
      return; // 不回调
    }
    // 合法 -> 清错并回调
    setState(() {
      _posError = null;
      _totalError = null;
    });
    widget.onChanged(
      widget.value.withRank(
        mode: RankMode.ordinal,
        rankPosition: pos,
        rankTotal: total,
      ),
    );
  }
}
