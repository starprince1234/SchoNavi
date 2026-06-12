import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/professor/pages/professor_page.dart';

void main() {
  testWidgets('详情页「生成套磁邮件」跳 /email?pid=', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ProfessorPage(professorId: 'p_001'),
        ),
        GoRoute(
          path: '/email',
          builder: (_, state) =>
              Text('email:${state.uri.queryParameters['pid']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('生成套磁邮件'));
    await tester.pumpAndSettle();

    expect(find.text('email:p_001'), findsOneWidget);
  });
}
