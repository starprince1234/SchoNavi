import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  testWidgets('无 key 时 AI 开关置灰并提示', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: '')));
    await tester.pumpAndSettle();

    final sw = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings-ai-switch')),
    );
    expect(sw.onChanged, isNull); // 置灰
    expect(find.textContaining('未配置'), findsOneWidget);
  });

  testWidgets('有 key 时切 AI 开关 → 在 ai/mock 间切换', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: 'sk-test')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    // resolve 有 key 初值即 ai，先关到 mock 再开，验证开关生效
    await tester.tap(find.byKey(const Key('settings-ai-switch')));
    await tester.pumpAndSettle();
    expect(container.read(appConfigProvider).dataSource, DataSource.mock);

    await tester.tap(find.byKey(const Key('settings-ai-switch')));
    await tester.pumpAndSettle();
    expect(container.read(appConfigProvider).dataSource, DataSource.ai);
  });

  testWidgets('演示模式开关 → showAiTrace', (tester) async {
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
