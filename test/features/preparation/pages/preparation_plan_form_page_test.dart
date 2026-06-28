import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/preparation_plan.dart';
import 'package:scho_navi/features/preparation/pages/preparation_plan_form_page.dart';

CompetitionSnapshot _comp() => CompetitionSnapshot(
      id: 'comp_icpc',
      name: 'ACM-ICPC',
      category: '计算机类',
      rulesSummary: CompetitionRulesSummary(
        signupTime: '',
        contestTime: '',
        teamSize: '',
        format: '',
        organizer: '',
        officialUrl: null,
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ProviderContainer> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('渲染三字段 + AI 提示 + 创建按钮', (tester) async {
    final container = await bootstrap();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanFormPage(competition: _comp())),
      ),
    );
    await tester.pump();
    expect(find.text('目标日期'), findsOneWidget);
    expect(find.text('每周投入'), findsOneWidget);
    expect(find.text('当前水平'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '创建备赛计划'), findsOneWidget);
  });

  testWidgets('未选目标日期时创建按钮提示请选择', (tester) async {
    final container = await bootstrap();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanFormPage(competition: _comp())),
      ),
    );
    await tester.pump();
    // 初始无日期，点击创建应弹校验
    await tester.tap(find.widgetWithText(FilledButton, '创建备赛计划'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请选择'), findsOneWidget);
  });
}
