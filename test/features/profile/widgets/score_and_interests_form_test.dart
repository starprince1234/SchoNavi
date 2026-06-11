import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/features/profile/widgets/score_and_interests_form.dart';

void main() {
  testWidgets('添加研究兴趣回调更新', (tester) async {
    UserProfile? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScoreAndInterestsForm(
              value: const UserProfile(),
              onChanged: (p) => out = p,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('interest-input')), '人工智能');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(out?.researchInterests, contains('人工智能'));
  });
}
