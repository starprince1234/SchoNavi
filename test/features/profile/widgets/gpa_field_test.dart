import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/academic_score.dart';
import 'package:scho_navi/features/profile/widgets/gpa_field.dart';

void main() {
  testWidgets('输入 GPA 回调 AcademicScore', (tester) async {
    AcademicScore? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GpaField(value: const AcademicScore(), onChanged: (s) => out = s),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('gpa-value')), '3.8');
    expect(out?.gpa, 3.8);
  });

  testWidgets('GPA 输入后排名字段保留', (tester) async {
    AcademicScore? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GpaField(
              value: const AcademicScore(
                gpa: 3.8,
                rankMode: RankMode.ordinal,
                rankPosition: 3,
                rankTotal: 120,
              ),
              onChanged: (s) => out = s,
            ),
          ),
        ),
      ),
    );
    // 改 GPA 为 3.9
    await tester.enterText(find.byKey(const Key('gpa-value')), '3.9');
    expect(out?.gpa, 3.9);
    expect(out?.rankMode, RankMode.ordinal);
    expect(out?.rankPosition, 3);
    expect(out?.rankTotal, 120);
  });

  testWidgets('排名输入后 GPA 保留', (tester) async {
    AcademicScore? out;
    AcademicScore current = const AcademicScore(gpa: 3.8, scale: 4.0);
    // 受控 widget：用 StatefulBuilder 把 onChanged 回喂为新的 value，
    // 否则切 chip 后父级不重建、rankMode 不变、百分制输入区不挂载。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => GpaField(
                value: current,
                onChanged: (s) {
                  setState(() => current = s);
                  out = s;
                },
              ),
            ),
          ),
        ),
      ),
    );
    // 切百分制并输入 5
    await tester.tap(find.text('百分制').last);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('rank-percent')), '5');
    expect(out?.gpa, 3.8);
    expect(out?.scale, 4.0);
    expect(out?.rankMode, RankMode.percent);
    expect(out?.percent, 5);
  });
}
