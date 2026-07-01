import 'package:flutter/material.dart';

import '../../../domain/entities/user_profile.dart';
import '../../../shared/widgets/choice_chip_group.dart';
import '../../../shared/widgets/labeled_text_field.dart';

class BasicInfoForm extends StatelessWidget {
  const BasicInfoForm({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UserProfile value;
  final ValueChanged<UserProfile> onChanged;

  static const List<(Gender, String)> _genders = [
    (Gender.male, '男'),
    (Gender.female, '女'),
    (Gender.other, '其他'),
    (Gender.undisclosed, '不愿透露'),
  ];

  static const List<(String, String)> _stages = [
    ('本科在读', '本科在读'),
    ('硕士在读', '硕士在读'),
    ('已毕业', '已毕业'),
  ];

  static const List<(String, String)> _targets = [
    ('申请硕士', '申请硕士'),
    ('申请博士', '申请博士'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledTextField(
          label: '姓名 / 称呼',
          initialValue: value.name,
          onChanged: (v) => onChanged(
            value.copyWith(name: v.trim().isEmpty ? null : v.trim()),
          ),
        ),
        const SizedBox(height: 14),
        const _Label('性别'),
        ChoiceChipGroup<Gender>(
          options: _genders,
          selected: value.gender,
          onSelected: (g) => onChanged(value.copyWith(gender: g)),
        ),
        const SizedBox(height: 14),
        LabeledTextField(
          label: '现就读学校',
          initialValue: value.school,
          onChanged: (v) => onChanged(
            value.copyWith(school: v.trim().isEmpty ? null : v.trim()),
          ),
        ),
        const SizedBox(height: 14),
        LabeledTextField(
          label: '专业',
          initialValue: value.major,
          onChanged: (v) => onChanged(
            value.copyWith(major: v.trim().isEmpty ? null : v.trim()),
          ),
        ),
        const SizedBox(height: 14),
        const _Label('当前阶段'),
        ChoiceChipGroup<String>(
          options: _stages,
          selected: value.degreeStage,
          onSelected: (s) => onChanged(value.copyWith(degreeStage: s)),
        ),
        const SizedBox(height: 14),
        const _Label('目标阶段'),
        ChoiceChipGroup<String>(
          options: _targets,
          selected: value.targetDegree,
          onSelected: (t) => onChanged(value.copyWith(targetDegree: t)),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}
