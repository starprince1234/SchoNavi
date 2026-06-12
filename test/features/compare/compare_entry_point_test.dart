import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/favorite_item.dart';
import 'package:scho_navi/features/favorite/pages/favorite_page.dart';

FavoriteItem _favorite(String id, String name) => FavoriteItem(
  professorId: id,
  name: name,
  university: 'U',
  college: 'C',
  title: '教授',
  researchFields: const ['方向'],
  favoritedAt: DateTime(2026, 6, 8, 10),
);

void main() {
  testWidgets('多选 2 位 -> 生成对比跳 /compare?ids=', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const FavoritePage()),
        GoRoute(
          path: '/compare',
          builder: (_, state) =>
              Text('compare:${state.uri.queryParameters['ids']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesProvider.overrideWith(
            (ref) => Stream.value([
              _favorite('p_001', '张三'),
              _favorite('p_002', '李娜'),
            ]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.compare_arrows));
    await tester.pumpAndSettle();

    await tester.tap(find.text('张三'));
    await tester.tap(find.text('李娜'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('生成对比 (2)'));
    await tester.pumpAndSettle();

    expect(find.text('compare:p_001,p_002'), findsOneWidget);
  });
}
