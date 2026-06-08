import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/app.dart';

void main() {
  testWidgets('App boots into home page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SchoNaviApp()));
    await tester.pump();
    expect(find.text('用自然语言找到适合你的导师'), findsOneWidget);
  });
}
