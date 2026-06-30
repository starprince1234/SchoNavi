import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/feedback.dart';
import 'package:scho_navi/domain/repositories/feedback_repository.dart';
import 'package:scho_navi/features/feedback/providers/feedback_provider.dart';

class _OkRepo implements FeedbackRepository {
  @override
  Future<Result<void>> submit(Feedback feedback) async => const Success(null);
}

class _FailRepo implements FeedbackRepository {
  @override
  Future<Result<void>> submit(Feedback feedback) async =>
      const Failure(ValidationException('boom'));
}

void main() {
  test('submit success transitions to success state', () async {
    final container = ProviderContainer(
      overrides: [feedbackRepositoryProvider.overrideWithValue(_OkRepo())],
    );
    addTearDown(container.dispose);
    final notifier = container.read(feedbackSubmitProvider.notifier);
    expect(container.read(feedbackSubmitProvider).loading, isFalse);
    await notifier.submit(
      type: FeedbackType.bug,
      content: '内容',
      contact: null,
      context: const FeedbackContext(),
    );
    final state = container.read(feedbackSubmitProvider);
    expect(state.success, isTrue);
    expect(state.errorMessage, isNull);
  });

  test('submit failure sets errorMessage', () async {
    final container = ProviderContainer(
      overrides: [feedbackRepositoryProvider.overrideWithValue(_FailRepo())],
    );
    addTearDown(container.dispose);
    final notifier = container.read(feedbackSubmitProvider.notifier);
    await notifier.submit(
      type: FeedbackType.bug,
      content: '内容',
      contact: null,
      context: const FeedbackContext(),
    );
    final state = container.read(feedbackSubmitProvider);
    expect(state.success, isFalse);
    expect(state.errorMessage, 'boom');
  });
}
