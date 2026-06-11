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
}
