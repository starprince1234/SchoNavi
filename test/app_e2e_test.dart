import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/app.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/shared/utils/recommendation_intent_router.dart';

class _FakeIntentClassifier implements RecommendationIntentClassifier {
  @override
  Future<RecommendationIntent> classify(String prompt) async {
    return RecommendationIntent.mentor;
  }
}

class _FakeRecommendationRepository implements RecommendationRepository {
  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async {
    return const Success(
      RecommendationResult(
        sessionId: 's_1',
        queryUnderstanding: QueryUnderstanding(
          researchInterests: ['医学影像', '计算机视觉'],
          preferredLocations: ['上海'],
          preferredUniversities: [],
          degreeStage: '硕士',
          uncertainties: [],
        ),
        recommendations: [
          Recommendation(
            professorId: 'p_001',
            name: '张三',
            university: '上海交通大学',
            college: '电子信息与电气工程学院',
            title: '教授',
            researchFields: ['医学影像', '计算机视觉'],
            matchLevel: MatchLevel.high,
            reason: '方向相关。',
            limitations: [],
            homepageUrl: 'https://example.edu.cn/zhangsan',
          ),
        ],
        followUpQuestions: [],
      ),
    );
  }
}

Future<ProviderScope> _wrap() async {
  SharedPreferences.setMockInitialValues(
    <String, Object>{
      'seenOnboarding': true,
      'profile_prompt_dismissed': true,
    },
  );
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      recommendationIntentClassifierProvider.overrideWithValue(
        _FakeIntentClassifier(),
      ),
      recommendationRepositoryProvider.overrideWithValue(
        _FakeRecommendationRepository(),
      ),
    ],
    child: const SchoNaviApp(),
  );
}

void main() {
  testWidgets('input -> recommend -> favorite -> detail -> favorites/history', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '我想找医学影像和计算机视觉方向的导师，最好在上海');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('推荐结果'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);

    await tester.tap(find.byTooltip('收藏导师').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消收藏'), findsOneWidget);

    await tester.tap(find.text('张三').first);
    await tester.pumpAndSettle();
    expect(find.text('导师详情'), findsOneWidget);
    expect(find.text('研究方向'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('我的收藏'));
    await tester.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('菜单'));
    await tester.pumpAndSettle();

    final historyTexts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => t.contains('医学影像和计算机视觉'));
    expect(historyTexts, isNotEmpty);
  });
}
