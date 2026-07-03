import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/app.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';

import 'helpers/fake_conversation_repository.dart';

Future<ProviderScope> _wrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'seenOnboarding': true,
    'profile_prompt_dismissed': true,
  });
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(
          dataSource: DataSource.llm,
          llm: LlmConfig(apiKey: 'test-key'),
        ),
      ),
      conversationRepositoryProvider.overrideWithValue(
        ControllableConversationRepository(),
      ),
    ],
    child: const SchoNaviApp(),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  testWidgets('app boots to home, accepts input, and exposes menu', (tester) async {
    await tester.pumpWidget(await _wrap());
    await _pumpFrames(tester);

    expect(find.text('SchoNavi'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '我想找医学影像和计算机视觉方向的导师');
    await tester.pump();

    expect(find.text('我想找医学影像和计算机视觉方向的导师'), findsOneWidget);
    expect(find.byTooltip('菜单'), findsOneWidget);

    await tester.tap(find.byTooltip('菜单'));
    await _pumpFrames(tester);

    expect(find.byTooltip('我的收藏'), findsOneWidget);
  });
}
