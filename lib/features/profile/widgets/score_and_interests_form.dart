import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/academic_score.dart';
import '../../../domain/entities/user_profile.dart';
import 'gpa_field.dart';

class ScoreAndInterestsForm extends StatefulWidget {
  const ScoreAndInterestsForm({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UserProfile value;
  final ValueChanged<UserProfile> onChanged;

  @override
  State<ScoreAndInterestsForm> createState() => _ScoreAndInterestsFormState();
}

class _ScoreAndInterestsFormState extends State<ScoreAndInterestsForm> {
  final TextEditingController _interest = TextEditingController();

  @override
  void dispose() {
    _interest.dispose();
    super.dispose();
  }

  void _addInterest() {
    final v = _interest.text.trim();
    if (v.isEmpty || widget.value.researchInterests.contains(v)) return;
    Haptics.selection();
    widget.onChanged(
      widget.value.copyWith(
        researchInterests: [...widget.value.researchInterests, v],
      ),
    );
    _interest.clear();
  }

  void _removeInterest(String v) {
    widget.onChanged(
      widget.value.copyWith(
        researchInterests:
            widget.value.researchInterests.where((e) => e != v).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.value.score ?? const AcademicScore();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GpaField(
          value: score,
          onChanged: (s) => widget.onChanged(widget.value.copyWith(score: s)),
        ),
        const SizedBox(height: 18),
        const Text(
          '研究兴趣',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('interest-input'),
          controller: _interest,
          decoration: InputDecoration(
            hintText: '输入后回车添加，如 计算机视觉',
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addInterest,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onSubmitted: (_) => _addInterest(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in widget.value.researchInterests)
              Chip(
                label: Text(tag),
                onDeleted: () => _removeInterest(tag),
                backgroundColor: AppColors.panel,
              ),
          ],
        ),
      ],
    );
  }
}
