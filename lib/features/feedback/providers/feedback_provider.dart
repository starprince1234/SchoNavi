import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/error/api_error_reporter.dart';
import '../../../core/ids/uuid_v7.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/feedback.dart';

class FeedbackSubmitState {
  const FeedbackSubmitState({
    this.loading = false,
    this.success = false,
    this.error,
  });

  final bool loading;
  final bool success;
  final AppException? error;
  String? get errorMessage => error?.message;

  FeedbackSubmitState copyWith({
    bool? loading,
    bool? success,
    AppException? error,
    bool clearError = false,
  }) => FeedbackSubmitState(
    loading: loading ?? this.loading,
    success: success ?? this.success,
    error: clearError ? null : error ?? this.error,
  );
}

class FeedbackSubmitNotifier extends Notifier<FeedbackSubmitState> {
  final UuidV7 _ids = UuidV7();

  @override
  FeedbackSubmitState build() => const FeedbackSubmitState();

  Future<bool> submit({
    required FeedbackType type,
    required String content,
    String? contact,
    required FeedbackContext context,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    final feedback = Feedback(
      id: _ids.generate(),
      type: type,
      content: content,
      contact: contact,
      context: context,
      createdAt: DateTime.now(),
    );
    final result = await ref.read(feedbackRepositoryProvider).submit(feedback);
    state = switch (result) {
      Success<void>() => state.copyWith(
        loading: false,
        success: true,
        clearError: true,
      ),
      Failure<void>(:final error) => state.copyWith(
        loading: false,
        error: error,
      ),
    };
    if (state.error != null) {
      ref
          .read(apiErrorReporterProvider.notifier)
          .report('反馈提交失败', state.error!);
    }
    return state.success;
  }
}

final feedbackSubmitProvider =
    NotifierProvider<FeedbackSubmitNotifier, FeedbackSubmitState>(
      FeedbackSubmitNotifier.new,
    );
