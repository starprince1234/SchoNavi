import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/preparation/widgets/preparation_deadline_card.dart';

void main() {
  testWidgets('date 为 null 时显示未设置，无加入日历按钮，有设置入口', (t) async {
    var editCalled = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationDeadlineCard(
            label: '报名截止',
            date: null,
            onEditDate: () => editCalled++,
          ),
        ),
      ),
    );
    expect(find.text('未设置'), findsOneWidget);
    expect(find.byKey(const Key('deadline-add-calendar')), findsNothing);
    await t.tap(find.text('设置'));
    expect(editCalled, 1);
  });

  testWidgets('date 有值时点加入日历触发回调', (t) async {
    var addCalled = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationDeadlineCard(
            label: '提交截止',
            date: DateTime(2026, 9, 1),
            onAddToCalendar: () => addCalled++,
          ),
        ),
      ),
    );
    expect(find.text('2026-09-01'), findsOneWidget);
    await t.tap(find.byKey(const Key('deadline-add-calendar')));
    expect(addCalled, 1);
  });

  testWidgets('adding=true 时加入日历按钮禁用', (t) async {
    var addCalled = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationDeadlineCard(
            label: '提交截止',
            date: DateTime(2026, 9, 1),
            adding: true,
            onAddToCalendar: () => addCalled++,
          ),
        ),
      ),
    );
    final btn = t.widget<IconButton>(find.byKey(const Key('deadline-add-calendar')));
    expect(btn.onPressed, isNull);
  });
}
