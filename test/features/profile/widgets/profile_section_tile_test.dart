import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/profile/widgets/profile_section_tile.dart';

void main() {
  testWidgets('显示标题与摘要；点按回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSectionTile(
            title: '竞赛成果',
            summary: '2 项',
            done: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('竞赛成果'), findsOneWidget);
    expect(find.text('2 项'), findsOneWidget);
    await tester.tap(find.text('竞赛成果'));
    expect(tapped, isTrue);
  });
}
