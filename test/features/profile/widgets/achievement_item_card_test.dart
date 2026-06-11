import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/profile/widgets/achievement_item_card.dart';

void main() {
  testWidgets('显示标题副标题；点删除回调', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AchievementItemCard(
            icon: Icons.emoji_events_outlined,
            title: 'ACM 区域赛',
            subtitle: '国家级 · 银牌 · 2024',
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.text('ACM 区域赛'), findsOneWidget);
    expect(find.text('国家级 · 银牌 · 2024'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(deleted, isTrue);
  });
}
