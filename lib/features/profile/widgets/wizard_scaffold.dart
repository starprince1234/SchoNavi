import 'package:flutter/material.dart';

import '../../../core/haptics/haptics.dart';
import '../../../shared/widgets/step_dots.dart';

class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.title,
    required this.index,
    required this.count,
    required this.child,
    required this.onNext,
    required this.nextLabel,
    this.onBack,
  });

  final String title;
  final int index;
  final int count;
  final Widget child;
  final VoidCallback onNext;
  final String nextLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('完善个人档案')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: StepDots(count: count, index: index),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(title, style: textTheme.headlineSmall),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: child,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (onBack != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Haptics.light();
                            onBack!();
                          },
                          child: const Text('上一步'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Haptics.light();
                          onNext();
                        },
                        child: Text(nextLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
