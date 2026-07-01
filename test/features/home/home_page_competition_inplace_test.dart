import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/launcher/link_launcher.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition_query_understanding.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/search_history_item.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/competition_recommendation_repository.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
import 'package:scho_navi/features/home/pages/home_page.dart';

class _FakeCompetitionRepo implements CompetitionRecommendationRepository {
  @override
  Future<Result<CompetitionRecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async => Success(
    CompetitionRecommendationResult(
      sessionId: 's-test',
      understanding: const CompetitionQueryUnderstanding(
        directions: ['算法'],
        categories: [],
        timingPreferences: [],
        teamPreferences: [],
        uncertainties: [],
      ),
      recommendations: [
        RecommendedCompetition(
          id: 'c0',
          name: '原地竞赛卡',
          category: '计算机类',
          level: '国家级',
          tags: const ['算法'],
          teamSize: '个人',
          signupTime: '',
          contestTime: '',
          format: '',
          organizer: '',
          officialUrl: null,
          reason: '契合你的算法方向',
          preparationTips: const [],
          limitations: const [],
          matchScore: 0.75,
        ),
      ],
      followUpQuestions: const [],
    ),
  );
}

class _FakeHistoryRepo implements HistoryRepository {
  @override
  List<SearchHistoryItem> list() => [];

  @override
  Stream<List<SearchHistoryItem>> watch() => Stream.value(const []);

  @override
  Future<void> addFromResult({
    required String prompt,
    required RecommendationResult result,
  }) async {}

  @override
  Future<void> addFromCompetitionResult({
    required String prompt,
    required CompetitionRecommendationResult result,
  }) async {}

  @override
  Future<void> remove(String sessionId) async {}

  @override
  Future<void> clear() async {}
}

class _FakeLinkLauncher implements LinkLauncher {
  @override
  Future<LaunchResult> open(String? url) async => LaunchResult.success;
}

Future<Widget> _wrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/competition-recommendation',
        builder: (_, _) => const Text('competition-marker'),
      ),
      GoRoute(path: '/competition/:id', builder: (_, _) => const Placeholder()),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(llm: LlmConfig(apiKey: 'test-key')),
      ),
      competitionRecommendationRepositoryProvider.overrideWithValue(
        _FakeCompetitionRepo(),
      ),
      historyRepositoryProvider.overrideWithValue(_FakeHistoryRepo()),
      linkLauncherProvider.overrideWithValue(_FakeLinkLauncher()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('竞赛 tab 提交后原地展示推荐卡，不跳路由', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    // 切换到竞赛 tab。
    await tester.tap(find.text('竞赛'));
    await tester.pumpAndSettle();

    // 输入文本并提交。
    await tester.enterText(find.byType(TextField), '我想参加算法竞赛');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    // 原地展示竞赛推荐卡及调整条件按钮，不应出现独立结果页 marker。
    expect(find.text('原地竞赛卡'), findsOneWidget);
    expect(find.text('调整条件'), findsOneWidget);
    expect(find.text('competition-marker'), findsNothing);
  });
}
