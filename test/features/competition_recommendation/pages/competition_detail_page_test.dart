import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/competition_recommendation/pages/competition_detail_page.dart';

void main() {
  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('从目录渲染详情，含赛制信息与官网', (t) async {
    await t.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CompetitionDetailPage(competitionId: 'comp_icpc')),
    ));
    await t.pumpAndSettle();
    expect(find.text('ACM-ICPC 国际大学生程序设计竞赛'), findsWidgets);
    expect(find.text('赛制信息'), findsOneWidget);
    expect(find.text('主办方'), findsOneWidget);
    expect(find.text('访问官网'), findsOneWidget);
  });

  testWidgets('未知 id 显示未找到', (t) async {
    await t.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CompetitionDetailPage(competitionId: 'nope')),
    ));
    await t.pumpAndSettle();
    expect(find.textContaining('未找到'), findsOneWidget);
  });

  testWidgets('传入 recommended 时显示 AI 补充提示', (t) async {
    // 从目录取基底，再 copyWith 注入 AI 字段模拟 recommended 传入
    await t.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CompetitionDetailPage(
        competitionId: 'comp_icpc',
        recommended: null, // 仅目录；AI 区块测试见 widget 测试 B3
      )),
    ));
    await t.pumpAndSettle();
    // 目录基底 limitations 为通用提示，preparationTips 非空 -> AI 区块应显示
    expect(find.text('AI 补充提示'), findsOneWidget);
  });
}
