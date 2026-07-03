import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/error/app_exception.dart';
import '../../core/haptics/haptics.dart';
import 'error_details_sheet.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.message, this.error, this.onRetry})
    : assert(message != null || error != null);

  final String? message;
  final AppException? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedError = error ?? ValidationException(message!);
    final details = resolvedError.diagnostics;
    final showDetails = apiErrorDetailsEnabled(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          label: '发生错误：${resolvedError.message}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sentiment_dissatisfied_outlined,
                size: 52,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 14),
              Text(
                resolvedError.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (details?.requestId case final requestId?) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: requestId));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('错误编号已复制')));
                  },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: Text('错误编号：$requestId'),
                ),
              ],
              if (onRetry != null ||
                  (showDetails && details != null && !details.isEmpty)) ...[
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (onRetry != null)
                      FilledButton(
                        onPressed: () {
                          Haptics.warning();
                          onRetry!();
                        },
                        child: const Text('重试'),
                      ),
                    if (showDetails && details != null && !details.isEmpty)
                      OutlinedButton.icon(
                        onPressed: () =>
                            showErrorDetailsSheet(context, resolvedError),
                        icon: const Icon(Icons.bug_report_outlined),
                        label: const Text('联调详情'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
