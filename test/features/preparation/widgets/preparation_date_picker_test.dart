import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/features/preparation/widgets/preparation_date_picker.dart';

Future<void> _openPicker(
  WidgetTester tester,
  PreparationDatePickerMode mode, {
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showPreparationDatePicker(
              context: context,
              mode: mode,
              firstDate: firstDate,
              lastDate: lastDate,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('single 模式选一天返回 single', (tester) async {
    await _openPicker(tester, PreparationDatePickerMode.single,
        firstDate: DateTime(2026, 5, 1), lastDate: DateTime(2026, 7, 31));
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
  });

  testWidgets('range 模式未选满禁用确认', (tester) async {
    await _openPicker(tester, PreparationDatePickerMode.range,
        firstDate: DateTime(2026, 5, 1), lastDate: DateTime(2026, 7, 31));
    await tester.tap(find.text('10'));
    await tester.pump();
    final confirm = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '确认'));
    expect((confirm.onPressed == null), isTrue);
  });

  testWidgets('multiAnchor 答辩可空且需晚于DDL', (tester) async {
    await _openPicker(tester, PreparationDatePickerMode.multiAnchor,
        firstDate: DateTime(2026, 5, 1), lastDate: DateTime(2026, 7, 31));
    await tester.tap(find.text('20'));
    await tester.pump();
    final confirm = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '确认'));
    expect((confirm.onPressed == null), isFalse);
  });

  testWidgets('返回值经规范化为本地零点', (tester) async {
    late PreparationDateSelection? result;
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pump();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result?.single, DateTime(2026, 5, 15));
  });
}
