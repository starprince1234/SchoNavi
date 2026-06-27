import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/competition_query_understanding.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/features/history/pages/history_page.dart';

Future<Widget> _wrap({bool withHistory = false, bool withCompetition = false}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HistoryPage()),
      GoRoute(
        path: '/recommendation',
        builder: (_, state) =>
            Text('重推：${state.uri.queryParameters['q'] ?? ''}'),
      ),
      GoRoute(
        path: '/competition-recommendation',
        builder: (_, state) => Text('竞赛重推：${state.uri.queryParameters['q'] ?? ''}'),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(dataSource: DataSource.llm),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  if (withHistory) {
    await container.read(historyRepositoryProvider).addFromResult(
      prompt: '医学影像 上海',
      result: _result(),
    );
  }
  if (withCompetition) {
    await container.read(historyRepositoryProvider).addFromCompetitionResult(
      prompt: '数学建模 团队赛',
      result: _competitionResult(),
    );
  }

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

RecommendationResult _result() => RecommendationResult(
  sessionId: 's_1',
  queryUnderstanding: const QueryUnderstanding(
    researchInterests: ['医学影像'],
    preferredLocations: ['上海'],
    preferredUniversities: [],
    degreeStage: '硕士',
    uncertainties: [],
  ),
  recommendations: const [
    Recommendation(
      professorId: 'p_001',
      name: '张三',
      university: '上海交通大学',
      college: '电子信息与电气工程学院',
      title: '教授',
      researchFields: ['医学影像'],
      matchLevel: MatchLevel.high,
      reason: '方向相关。',
      limitations: [],
    ),
  ],
  followUpQuestions: const [],
);

CompetitionRecommendationResult _competitionResult() =>
    const CompetitionRecommendationResult(
      sessionId: 'c_1',
      understanding: CompetitionQueryUnderstanding(
        directions: ['数学建模'],
        categories: ['理学类'],
        timingPreferences: ['秋季/下半年'],
        teamPreferences: ['团队赛'],
        uncertainties: [],
      ),
      recommendations: [_competition],
      followUpQuestions: [],
    );

const _competition = RecommendedCompetition(
  id: 'comp_math_modeling',
  name: '全国大学生数学建模竞赛',
  category: '理学类',
  level: '国家级',
  tags: ['数学建模', '团队赛'],
  teamSize: '3 人团队',
  signupTime: '以官网通知为准',
  contestTime: '通常每年 9 月',
  format: '建模、编程和论文写作',
  organizer: '中国工业与应用数学学会',
  officialUrl: 'http://www.mcm.edu.cn/',
  reason: '方向匹配。',
  preparationTips: ['训练论文写作'],
  limitations: ['以官网通知为准。'],
  matchScore: 0.91,
);

void main() {
  testWidgets('shows empty state when no history', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    expect(find.text('暂无搜索历史'), findsOneWidget);
  });

  testWidgets('mentor history item expands to show empty fork state', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap(withHistory: true));
    await tester.pumpAndSettle();

    expect(find.text('医学影像 上海'), findsOneWidget);
    expect(find.textContaining('位导师'), findsNothing);

    await tester.tap(find.text('医学影像 上海'));
    await tester.pumpAndSettle();

    expect(find.text('暂无追问历史'), findsOneWidget);
  });

  testWidgets('competition history item expands to show empty fork state', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap(withCompetition: true));
    await tester.pumpAndSettle();

    expect(find.text('数学建模 团队赛'), findsOneWidget);
    expect(find.textContaining('项竞赛'), findsNothing);

    await tester.tap(find.text('数学建模 团队赛'));
    await tester.pumpAndSettle();

    expect(find.text('暂无追问历史'), findsOneWidget);
  });

  testWidgets('delete one history updates page to empty state', (tester) async {
    await tester.pumpWidget(await _wrap(withHistory: true));
    await tester.pumpAndSettle();

    await tester.drag(find.text('医学影像 上海'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('暂无搜索历史'), findsOneWidget);
  });

  testWidgets('search filters history items', (tester) async {
    await tester.pumpWidget(await _wrap(withHistory: true));
    await tester.pumpAndSettle();

    expect(find.text('医学影像 上海'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '上海');
    await tester.pumpAndSettle();
    expect(find.text('医学影像 上海'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '北京');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的搜索记录'), findsOneWidget);
    expect(find.text('医学影像 上海'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('医学影像 上海'), findsOneWidget);
    expect(find.text('没有匹配的搜索记录'), findsNothing);
  });

  testWidgets('search filters mentor and competition labels', (tester) async {
    await tester.pumpWidget(
      await _wrap(withHistory: true, withCompetition: true),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '竞赛');
    await tester.pumpAndSettle();

    expect(find.text('数学建模 团队赛'), findsOneWidget);
    expect(find.text('医学影像 上海'), findsNothing);
  });

  testWidgets('clear history asks confirmation and clears list', (tester) async {
    await tester.pumpWidget(await _wrap(withHistory: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('清空历史'));
    await tester.pumpAndSettle();
    expect(find.text('确定清空全部搜索历史吗？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await tester.pumpAndSettle();

    expect(find.text('暂无搜索历史'), findsOneWidget);
  });
}
