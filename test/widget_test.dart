import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/app.dart';
import 'package:scho_navi/core/di/providers.dart';

Future<ProviderScope> _wrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{'seenOnboarding': true});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const SchoNaviApp(),
  );
}

void main() {
  testWidgets('App boots into home page', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();
    expect(find.text('用自然语言找到适合你的导师'), findsOneWidget);
  });
}
