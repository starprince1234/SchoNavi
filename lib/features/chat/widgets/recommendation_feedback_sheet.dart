import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../core/ui/app_bottom_sheet.dart';

/// 长按导师卡片反馈弹层：预设「推荐不准」「信息不准确」单选 + 可选补充说明。
///
/// 返回 (reason, note?)；用户取消返回 null。
Future<(String, String?)?> showRecommendationFeedbackSheet({
  required BuildContext context,
  required String professorName,
}) async {
  return showAppBottomSheet<(String, String?)?>(
    context: context,
    builder: (ctx) => _RecommendationFeedbackSheet(professorName: professorName),
  );
}

class _RecommendationFeedbackSheet extends StatefulWidget {
  const _RecommendationFeedbackSheet({required this.professorName});

  final String professorName;

  @override
  State<_RecommendationFeedbackSheet> createState() =>
      _RecommendationFeedbackSheetState();
}

class _RecommendationFeedbackSheetState
    extends State<_RecommendationFeedbackSheet> {
  String? _reason;
  final TextEditingController _note = TextEditingController();

  static const _reasons = <String>['推荐不准', '信息不准确'];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canSubmit => _reason != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('反馈「${widget.professorName}」的推荐',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _reasons)
                ChoiceChip(
                  label: Text(r),
                  selected: _reason == r,
                  onSelected: (_) {
                    Haptics.selection();
                    setState(() => _reason = _reason == r ? null : r);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '补充说明（可选）',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _canSubmit
                ? () {
                    Haptics.medium();
                    final note = _note.text.trim();
                    Navigator.of(context).pop((_reason!, note.isEmpty ? null : note));
                  }
                : null,
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }
}
