import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_extraction_repository.dart';
import 'package:scho_navi/features/profile/widgets/achievements_editor.dart';

class _FakeExtract implements ProfileExtractionRepository {
  @override
  Future<Result<AchievementDraft>> extract({required String rawText}) async =>
      const Success(
        AchievementDraft(competitions: [Competition(name: '挑战杯', award: '一等奖')]),
      );
}

void main() {
  testWidgets('AI 整理把抽取结果合并进 profile', (tester) async {
    UserProfile current = const UserProfile();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileExtractionRepositoryProvider.overrideWithValue(_FakeExtract()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: AchievementsEditor(
                  value: current,
                  onChanged: (p) => setState(() => current = p),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('achievements-raw')),
      '挑战杯一等奖',
    );
    await tester.tap(find.text('AI 整理成条目'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(current.competitions.any((c) => c.name == '挑战杯'), isTrue);
  });
}
