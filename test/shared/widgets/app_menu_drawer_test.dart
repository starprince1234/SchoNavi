import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
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

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
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
}
