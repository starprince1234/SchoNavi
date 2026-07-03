import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_exception.dart';

class ReportedAppError {
  const ReportedAppError({required this.source, required this.error});

  final String source;
  final AppException error;
}

class ApiErrorReporter extends Notifier<ReportedAppError?> {
  @override
  ReportedAppError? build() => null;

  void report(String source, Object error, [StackTrace? stackTrace]) {
    state = ReportedAppError(
      source: source,
      error: normalizeAppException(error, stackTrace),
    );
  }

  void clear() => state = null;
}

final apiErrorReporterProvider =
    NotifierProvider<ApiErrorReporter, ReportedAppError?>(ApiErrorReporter.new);
