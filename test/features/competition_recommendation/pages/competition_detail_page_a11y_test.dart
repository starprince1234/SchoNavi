import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/competition_recommendation/pages/competition_detail_page.dart';

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('详情页 375x800 / textScale 1.5 / 深色主题下不溢出', (tester) async {
    addTearDown(() {
      tester.platformDispatcher.clearAllTestValues();
      tester.view.reset();
    });

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;

    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    // 页面内部已有 ListView，不额外包 SingleChildScrollView，确保溢出能暴露。
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: const CompetitionDetailPage(competitionId: 'comp_icpc'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CompetitionDetailPage), findsOneWidget);
    expect(find.textContaining('ACM-ICPC'), findsWidgets);
  });
}
