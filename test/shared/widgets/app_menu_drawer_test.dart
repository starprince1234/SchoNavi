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
import 'package:scho_navi/shared/widgets/app_menu_drawer.dart';

Future<Widget> _pumpDrawer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(dataSource: DataSource.llm),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);

  await container.read(historyRepositoryProvider).addFromResult(
        prompt: '医学影像 上海',
        result: _result(),
      );
  await container.read(historyRepositoryProvider).addFromCompetitionResult(
        prompt: '数学建模 团队赛',
        result: _competitionResult(),
      );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              endDrawer: const AppMenuDrawer(),
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    child: const Text('Open drawer'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/recommendation',
            builder: (_, state) =>
                Text('导师：${state.uri.queryParameters['q'] ?? ''}'),
          ),
          GoRoute(
            path: '/competition-recommendation',
            builder: (_, state) =>
                Text('竞赛：${state.uri.queryParameters['q'] ?? ''}'),
          ),
        ],
      ),
    ),
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
  testWidgets('drawer shows 最近 section and filters items', (tester) async {
    await tester.pumpWidget(await _pumpDrawer());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open drawer'));
    await tester.pumpAndSettle();

    expect(find.text('最近'), findsOneWidget);
    expect(find.text('医学影像 上海'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '上海');
    await tester.pumpAndSettle();
    expect(find.text('医学影像 上海'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '北京');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的最近搜索'), findsOneWidget);
    expect(find.text('医学影像 上海'), findsNothing);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('医学影像 上海'), findsOneWidget);
  });

  testWidgets('recent history routes by item type', (tester) async {
    await tester.pumpWidget(await _pumpDrawer());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open drawer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('数学建模 团队赛'));
    await tester.pumpAndSettle();
    expect(find.text('竞赛：数学建模 团队赛'), findsOneWidget);
  });

  testWidgets('drawer search matches competition label', (tester) async {
    await tester.pumpWidget(await _pumpDrawer());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open drawer'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '竞赛');
    await tester.pumpAndSettle();

    expect(find.text('数学建模 团队赛'), findsOneWidget);
    expect(find.text('医学影像 上海'), findsNothing);
  });
}
