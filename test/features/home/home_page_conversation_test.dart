import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/chat/providers/chat_provider.dart';
import 'package:scho_navi/features/home/pages/home_page.dart';

import '../../helpers/fake_conversation_repository.dart';

Future<Widget> _wrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final repo = ControllableConversationRepository();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
      GoRoute(path: '/chat', builder: (_, _) => const Text('chat-route')),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(
          dataSource: DataSource.llm,
          llm: LlmConfig(apiKey: 'test-key'),
        ),
      ),
      conversationRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  testWidgets('首页导师 tab 落地态可输入并保持原地', (tester) async {
    await tester.pumpWidget(await _wrap());
    await _pumpFrames(tester);

    expect(find.text('SchoNavi'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '想做计算机视觉，想去北京');
    await tester.pump();

    expect(find.text('想做计算机视觉，想去北京'), findsOneWidget);
    expect(find.text('chat-route'), findsNothing);
  });

  testWidgets('ChatActivity 枚举可被首页引用（编译期守护）', (tester) async {
    expect(ChatActivity.streaming, ChatActivity.streaming);
    expect(ChatActivity.idle, ChatActivity.idle);
  });
}
