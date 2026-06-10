import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FieldChips extends StatelessWidget {
  const FieldChips({super.key, required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const Text('暂无信息');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: fields
          .map(
            (field) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                field,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
