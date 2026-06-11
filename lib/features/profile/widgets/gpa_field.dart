import 'package:flutter/material.dart';

import '../../../domain/entities/academic_score.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../../../shared/widgets/labeled_text_field.dart';

class GpaField extends StatelessWidget {
  const GpaField({super.key, required this.value, required this.onChanged});

  final AcademicScore value;
  final ValueChanged<AcademicScore> onChanged;

  static const List<(double, String)> _scales = [
    (4.0, '4.0'),
    (4.3, '4.3'),
    (4.5, '4.5'),
    (5.0, '5.0'),
    (100, '百分制'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledTextField(
          label: 'GPA / 平均分',
          fieldKey: const Key('gpa-value'),
          initialValue: value.gpa?.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hintText: '例 3.8',
          onChanged: (v) {
            final parsed = double.tryParse(v.trim());
            onChanged(AcademicScore(
              gpa: parsed,
              scale: value.scale,
              rank: value.rank,
            ));
          },
        ),
        const SizedBox(height: 12),
        const Text(
          '量纲',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ChoiceChipGroup<double>(
          options: _scales,
          selected: value.scale,
          onSelected: (s) => onChanged(AcademicScore(
            gpa: value.gpa,
            scale: s,
            rank: value.rank,
          )),
        ),
        const SizedBox(height: 12),
        LabeledTextField(
          label: '专业排名（可选）',
          initialValue: value.rank,
          hintText: '例 前 5% / 3/120',
          onChanged: (v) => onChanged(AcademicScore(
            gpa: value.gpa,
            scale: value.scale,
            rank: v.trim().isEmpty ? null : v.trim(),
          )),
        ),
      ],
    );
  }
}
