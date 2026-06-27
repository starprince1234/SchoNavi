import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/router/app_router.dart';
import 'package:scho_navi/features/chat/pages/chat_page.dart';

void main() {
  testWidgets('app router 把 /chat 解析为 ChatPage', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'seenOnboarding': true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/chat?sid=s_x');
    await tester.pumpAndSettle();

    // ChatPage 不再有 AppBar；改为断言悬浮按钮存在，验证路由仍落地 ChatPage。
    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.byTooltip('新对话'), findsOneWidget);
  });
}
