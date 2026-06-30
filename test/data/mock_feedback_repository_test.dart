import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_feedback_repository.dart';
import 'package:scho_navi/domain/entities/feedback.dart';

Feedback _feedback() => Feedback(
  id: 'id1',
  type: FeedbackType.bug,
  content: '崩溃了',
  contact: null,
  context: const FeedbackContext(),
  createdAt: DateTime.utc(2026, 6, 30),
);

void main() {
  test('returns Success after simulated delay', () async {
    final repo = MockFeedbackRepository();
    final sw = Stopwatch()..start();
    final result = await repo.submit(_feedback());
    sw.stop();
    expect(result, isA<Success<void>>());
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(500));
  });
}
