import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/shared/widgets/bento_tile.dart';
import 'package:scho_navi/shared/widgets/stat_tile.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('StatTile shows target number and label after animation', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const StatTile(value: 83, label: '契合度')));
    await tester.pumpAndSettle();

    expect(find.text('83'), findsOneWidget);
    expect(find.text('契合度'), findsOneWidget);
  });

  testWidgets('BentoTile calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(BentoTile(onTap: () => tapped = true, child: const Text('块'))),
    );

    await tester.tap(find.text('块'));

    expect(tapped, isTrue);
  });
}
