import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/settings/pages/settings_page.dart';

Future<Widget> _wrap(AppConfig initial) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialAppConfigProvider.overrideWithValue(initial),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

void main() {
  testWidgets('无 key 时展示 LLM 模式和配置缺失提示', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: '')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-data-source')), findsOneWidget);
    expect(find.textContaining('LLM 模式'), findsOneWidget);
    expect(find.textContaining('未配置 LLM_API_KEY'), findsOneWidget);
    expect(find.textContaining('离线 Mock'), findsNothing);
  });

  testWidgets('有 key 时展示当前模型', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: 'sk-test')));
    await tester.pumpAndSettle();

    expect(find.textContaining('LLM 模式'), findsOneWidget);
    expect(find.text('deepseek-chat'), findsOneWidget);
  });

  testWidgets('演示模式开关 -> showAiTrace', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: 'sk-test')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-demo-switch')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(appConfigProvider).featureFlags.showAiTrace, isTrue);
  });
}
