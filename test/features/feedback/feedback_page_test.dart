import 'package:flutter/material.dart' hide Feedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/feedback.dart';
import 'package:scho_navi/domain/repositories/feedback_repository.dart';
import 'package:scho_navi/features/feedback/pages/feedback_page.dart';

class _OkRepo implements FeedbackRepository {
  @override
  Future<Result<void>> submit(Feedback feedback) async => const Success(null); // 以项目惯用法为准
}

void main() {
  testWidgets('disables submit until content length >= 5', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedbackRepositoryProvider.overrideWithValue(_OkRepo())],
        child: const MaterialApp(home: FeedbackPage()),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );
    await tester.enterText(find.byType(TextField).first, 'ab');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      false,
    );
    await tester.enterText(find.byType(TextField).first, '12345');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      true,
    );
  });

  testWidgets('preselects type from constructor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedbackRepositoryProvider.overrideWithValue(_OkRepo())],
        child: const MaterialApp(home: FeedbackPage(type: FeedbackType.bug)),
      ),
    );
    await tester.pump();
    final bugChip = find.text('Bug / 异常');
    expect(bugChip, findsOneWidget);
  });
}
