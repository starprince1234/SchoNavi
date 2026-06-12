import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/features/profile/widgets/profile_summary_header.dart';

void main() {
  testWidgets('显示完成度环与 CTA', (tester) async {
    var used = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSummaryHeader(
            profile: const UserProfile(name: '张三', gender: Gender.male),
            onUseForReco: () => used = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('用我的档案推荐'), findsOneWidget);
    await tester.tap(find.text('用我的档案推荐'));
    expect(used, isTrue);
  });
}
