import 'package:flutter/material.dart';

import '../../core/error/app_exception.dart';
import 'error_details_sheet.dart';

class ApiErrorNotice extends StatelessWidget {
  const ApiErrorNotice({
    super.key,
    required this.message,
    this.error,
    this.showProgress = false,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String message;
  final AppException? error;
  final bool showProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = error?.diagnostics;
    final requestId = details?.requestId;
    final showDetails = apiErrorDetailsEnabled(context);
    final content = Material(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (showProgress) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  if (requestId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '错误编号：$requestId',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                if (showDetails && details != null && !details.isEmpty)
                  TextButton(
                    onPressed: () => showErrorDetailsSheet(context, error!),
                    child: const Text('联调详情'),
                  ),
                if (secondaryLabel != null)
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                if (primaryLabel != null)
                  FilledButton.tonal(
                    onPressed: onPrimary,
                    child: Text(primaryLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (error == null) return content;
    return Semantics(liveRegion: true, label: '发生错误：$message', child: content);
  }
}
