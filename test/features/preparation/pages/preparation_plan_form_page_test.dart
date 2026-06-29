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

CompetitionSnapshot _genericComp() => CompetitionSnapshot(
      id: 'comp_unknown',
      name: '某竞赛',
      category: '综合类',
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

  testWidgets('渲染时间模型 + 每周投入 + 当前水平 + 创建按钮', (tester) async {
    final container = await bootstrap();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanFormPage(competition: _comp())),
      ),
    );
    await tester.pump();
    expect(find.text('时间模型'), findsOneWidget);
    expect(find.text('每周投入'), findsOneWidget);
    expect(find.text('当前水平'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '创建备赛计划'), findsOneWidget);
  });

  testWidgets('ICPC 默认预选窗口型并展示区间入口', (tester) async {
    final container = await bootstrap();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanFormPage(competition: _comp())),
      ),
    );
    await tester.pump();
    // 默认 eventWindow → 日期入口文案为「选择比赛起止日期」
    expect(find.text('选择比赛起止日期'), findsOneWidget);
  });

  testWidgets('未知赛事默认预选提交型并展示 DDL/答辩入口', (tester) async {
    final container = await bootstrap();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanFormPage(competition: _genericComp())),
      ),
    );
    await tester.pump();
    expect(find.text('选择提交 DDL 与答辩'), findsOneWidget);
  });

  testWidgets('选窗口型后日期入口变为比赛起止', (tester) async {
    final container = await bootstrap();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanFormPage(competition: _genericComp())),
      ),
    );
    await tester.pump();
    // 默认提交型 → 切到窗口型
    await tester.tap(find.text('窗口型'));
    await tester.pumpAndSettle();
    expect(find.text('选择比赛起止日期'), findsOneWidget);
  });

  testWidgets('选提交型后日期入口变为 DDL 与答辩', (tester) async {
    final container = await bootstrap();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PreparationPlanFormPage(competition: _comp())),
      ),
    );
    await tester.pump();
    // ICPC 默认窗口型 → 切到提交型
    await tester.tap(find.text('提交型'));
    await tester.pumpAndSettle();
    expect(find.text('选择提交 DDL 与答辩'), findsOneWidget);
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
    await tester.tap(find.widgetWithText(FilledButton, '创建备赛计划'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请选择'), findsOneWidget);
  });
}
