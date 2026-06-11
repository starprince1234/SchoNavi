import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/features/profile/widgets/basic_info_form.dart';

void main() {
  testWidgets('选性别回调更新 profile', (tester) async {
    UserProfile? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BasicInfoForm(
              value: const UserProfile(),
              onChanged: (p) => out = p,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('女'));
    expect(out?.gender, Gender.female);
  });
}
