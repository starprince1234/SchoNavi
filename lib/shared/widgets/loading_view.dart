import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.secondary),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(label!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
