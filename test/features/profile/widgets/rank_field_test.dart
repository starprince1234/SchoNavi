import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';
import 'package:scho_navi/features/profile/widgets/rank_field.dart';

void main() {
  // 受控 widget 测试脚手架：用 StatefulBuilder 把 onChanged 回调的值回喂为新的 value，
  // 否则切 chip 后父级不重建、value.rankMode 不变、输入区不会挂载，enterText 找不到框。
  Future<void> pumpRank(
    WidgetTester tester, {
    required AcademicScore value,
    required ValueChanged<AcademicScore> onChanged,
  }) async {
    AcademicScore current = value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => RankField(
                value: current,
                onChanged: (s) {
                  setState(() => current = s);
                  onChanged(s);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('初始 none 不显示输入区', (tester) async {
    await pumpRank(tester, value: const AcademicScore(), onChanged: (_) {});
    expect(find.text('不填'), findsOneWidget);
    expect(find.byKey(const Key('rank-percent')), findsNothing);
    expect(find.byKey(const Key('rank-position')), findsNothing);
    expect(find.byKey(const Key('rank-total')), findsNothing);
  });

  testWidgets('切到百分制并输入 5 -> 回调 percent=5', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(),
      onChanged: (s) => out = s,
    );
    await tester.tap(find.text('百分制'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rank-percent')), '5');
    expect(out?.rankMode, RankMode.percent);
    expect(out?.percent, 5);
    expect(out?.rank, '前 5%');
  });

  // 以下非法输入测试直接以目标模式起步（不切 chip），避免 chip tap 触发 onChanged
  // 使 out 非空，从而能断言「非法输入不回调」。

  testWidgets('百分制输入 0 -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.percent),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-percent')), '0');
    await tester.pump(); // 刷新 setState 触发的 errorText 重建
    expect(out, isNull); // 不回调
    expect(find.text('请输入 1–100'), findsOneWidget);
  });

  testWidgets('百分制输入 101 -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.percent),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-percent')), '101');
    await tester.pump();
    expect(out, isNull);
    expect(find.text('请输入 1–100'), findsOneWidget);
  });

  testWidgets('百分制输入非数字 -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.percent),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-percent')), 'abc');
    await tester.pump();
    expect(out, isNull);
    expect(find.text('请输入 1–100'), findsOneWidget);
  });

  testWidgets('切到名次并输入 3/120 -> 回调 ordinal', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(),
      onChanged: (s) => out = s,
    );
    await tester.tap(find.text('名次'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rank-position')), '3');
    await tester.enterText(find.byKey(const Key('rank-total')), '120');
    await tester.pump();
    expect(out?.rankMode, RankMode.ordinal);
    expect(out?.rankPosition, 3);
    expect(out?.rankTotal, 120);
    expect(out?.rank, '3/120');
  });

  testWidgets('名次只填名次 -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.ordinal),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-position')), '3');
    await tester.pump();
    expect(out, isNull);
    expect(find.text('请补全名次和总人数'), findsOneWidget);
  });

  testWidgets('名次 position>total -> 标红不回调', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.ordinal),
      onChanged: (s) => out = s,
    );
    await tester.enterText(find.byKey(const Key('rank-position')), '150');
    await tester.enterText(find.byKey(const Key('rank-total')), '120');
    await tester.pump();
    expect(out, isNull);
    expect(find.text('名次不能大于总人数'), findsOneWidget);
  });

  testWidgets('从名次切回不填 -> 回调 none 且清空', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(
        rankMode: RankMode.ordinal,
        rankPosition: 3,
        rankTotal: 120,
      ),
      onChanged: (s) => out = s,
    );
    await tester.tap(find.text('不填'));
    await tester.pump();
    expect(out?.rankMode, RankMode.none);
    expect(out?.rankPosition, isNull);
    expect(out?.rankTotal, isNull);
    expect(out?.rank, isNull);
  });

  testWidgets('已有 percent 值时百分制框回填', (tester) async {
    await pumpRank(
      tester,
      value: const AcademicScore(rankMode: RankMode.percent, percent: 5),
      onChanged: (_) {},
    );
    expect(find.byKey(const Key('rank-percent')), findsOneWidget);
    // 输入框初始值 5
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('rank-percent')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, '5');
  });

  testWidgets('GPA/scale 在回调中保留', (tester) async {
    AcademicScore? out;
    await pumpRank(
      tester,
      value: const AcademicScore(gpa: 3.8, scale: 4.0),
      onChanged: (s) => out = s,
    );
    await tester.tap(find.text('百分制'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rank-percent')), '5');
    expect(out?.gpa, 3.8);
    expect(out?.scale, 4.0);
  });
}
