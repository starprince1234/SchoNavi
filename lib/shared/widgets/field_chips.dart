import 'package:flutter/material.dart';

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
            (f) => Chip(
              label: Text(f, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(),
    );
  }
}
