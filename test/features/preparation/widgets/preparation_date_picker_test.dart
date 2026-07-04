import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/preparation/widgets/preparation_date_picker.dart';

Future<void> _openPicker(
  WidgetTester tester,
  PreparationDatePickerMode mode, {
  required DateTime firstDate,
  required DateTime lastDate,
  PreparationDateSelection? initial,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showPreparationDatePicker(
                context: context,
                mode: mode,
                firstDate: firstDate,
                lastDate: lastDate,
                initial: initial,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tapDay(WidgetTester tester, String day) async {
  await tester.tap(
    find.ancestor(of: find.text(day), matching: find.byType(GestureDetector)),
  );
}

void main() {
  testWidgets('single 模式选一天返回 single', (tester) async {
    await _openPicker(
      tester,
      PreparationDatePickerMode.single,
      firstDate: DateTime(2026, 5, 1),
      lastDate: DateTime(2026, 7, 31),
    );
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
  });

  testWidgets('range 模式未选满禁用确认', (tester) async {
    await _openPicker(
      tester,
      PreparationDatePickerMode.range,
      firstDate: DateTime(2026, 5, 1),
      lastDate: DateTime(2026, 7, 31),
    );
    await tester.tap(find.text('10'));
    await tester.pump();
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认'),
    );
    expect((confirm.onPressed == null), isTrue);
  });

  testWidgets('multiAnchor 答辩可空且需晚于DDL', (tester) async {
    await _openPicker(
      tester,
      PreparationDatePickerMode.multiAnchor,
      firstDate: DateTime(2026, 5, 1),
      lastDate: DateTime(2026, 7, 31),
    );
    await tester.tap(find.text('20'));
    await tester.pump();
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认'),
    );
    expect((confirm.onPressed == null), isFalse);
  });

  testWidgets('multiAnchor 点击已选 DDL 会清空并禁用确认', (tester) async {
    await _openPicker(
      tester,
      PreparationDatePickerMode.multiAnchor,
      firstDate: DateTime(2026, 5, 1),
      lastDate: DateTime(2026, 7, 31),
      initial: PreparationDateSelection(deadline: DateTime(2026, 5, 20)),
    );
    expect(find.text('提交 DDL：2026-05-20 · 答辩：无'), findsOneWidget);

    await _tapDay(tester, '20');
    await tester.pump();

    expect(find.text('提交 DDL：未选 · 答辩：无'), findsOneWidget);
    var confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认'),
    );
    expect(confirm.onPressed, isNull);

    await _tapDay(tester, '21');
    await tester.pump();

    expect(find.text('提交 DDL：2026-05-21 · 答辩：无'), findsOneWidget);
    confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认'),
    );
    expect(confirm.onPressed, isNotNull);
  });

  testWidgets('multiAnchor 点击已选答辩日只清空答辩并保留 DDL', (tester) async {
    late PreparationDateSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showPreparationDatePicker(
                    context: context,
                    mode: PreparationDatePickerMode.multiAnchor,
                    firstDate: DateTime(2026, 5, 1),
                    lastDate: DateTime(2026, 7, 31),
                    initial: PreparationDateSelection(
                      deadline: DateTime(2026, 5, 20),
                      defense: DateTime(2026, 5, 21),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await _tapDay(tester, '21');
    await tester.pump();

    expect(find.text('提交 DDL：2026-05-20 · 答辩：无'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认'),
    );
    expect(confirm.onPressed, isNotNull);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(result?.deadline, DateTime(2026, 5, 20));
    expect(result?.defense, isNull);
  });

  testWidgets('返回值经规范化为本地零点', (tester) async {
    late PreparationDateSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showPreparationDatePicker(
                    context: context,
                    mode: PreparationDatePickerMode.single,
                    firstDate: DateTime(2026, 5, 1),
                    lastDate: DateTime(2026, 7, 31),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result?.single, DateTime(2026, 5, 15));
  });
}
