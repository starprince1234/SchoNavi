import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';

/// 点踩后气泡下内联展开的反馈输入框：可选补充文字 + 提交/收起。
class InlineDislikeFeedback extends StatefulWidget {
  const InlineDislikeFeedback({
    super.key,
    required this.onSubmit,
    required this.onCollapse,
    this.submitting = false,
  });

  final ValueChanged<String> onSubmit;
  final VoidCallback onCollapse;
  final bool submitting;

  @override
  State<InlineDislikeFeedback> createState() => _InlineDislikeFeedbackState();
}

class _InlineDislikeFeedbackState extends State<InlineDislikeFeedback> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '告诉我们要怎么改进（可选）',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(
                onPressed: widget.submitting
                    ? null
                    : () {
                        Haptics.light();
                        widget.onSubmit(_controller.text.trim());
                      },
                child: widget.submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Haptics.light();
                  widget.onCollapse();
                },
                child: const Text('收起'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
