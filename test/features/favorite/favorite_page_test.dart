import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/launcher/link_launcher.dart';
import 'package:scho_navi/domain/entities/favorite_item.dart';
import 'package:scho_navi/features/favorite/pages/favorite_page.dart';

class _FakeLauncher implements LinkLauncher {
  _FakeLauncher(this.result);

  final LaunchResult result;
  String? openedUrl;

  @override
  Future<LaunchResult> open(String? url) async {
    openedUrl = url;
    return result;
  }
}

Future<Widget> _wrap({
  List<FavoriteItem> initialItems = const [],
  LinkLauncher? launcher,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const FavoritePage()),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(dataSource: DataSource.llm),
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (launcher != null) linkLauncherProvider.overrideWithValue(launcher),
    ],
  );
  addTearDown(container.dispose);
  for (final item in initialItems) {
    await container.read(favoriteRepositoryProvider).add(item);
  }

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

FavoriteItem _item({String? homepageUrl}) => FavoriteItem(
  professorId: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: const ['医学影像'],
  homepageUrl: homepageUrl,
  favoritedAt: DateTime(2026, 6, 8, 10),
);

void main() {
  testWidgets('shows empty state when no favorites', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    expect(find.text('还没有收藏导师'), findsOneWidget);
  });

  testWidgets('remove favorite updates page to empty state', (tester) async {
    await tester.pumpWidget(await _wrap(initialItems: [_item()]));
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget);
    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pumpAndSettle();

    expect(find.text('还没有收藏导师'), findsOneWidget);
  });

  testWidgets('homepage button calls launcher', (tester) async {
    final launcher = _FakeLauncher(LaunchResult.success);
    await tester.pumpWidget(
      await _wrap(
        initialItems: [_item(homepageUrl: 'https://example.edu.cn/zhangsan')],
        launcher: launcher,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('访问主页'));
    await tester.pumpAndSettle();

    expect(launcher.openedUrl, 'https://example.edu.cn/zhangsan');
  });

  testWidgets('missing homepage shows noUrl message', (tester) async {
    await tester.pumpWidget(await _wrap(initialItems: [_item()]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('访问主页'));
    await tester.pumpAndSettle();

    expect(find.text('暂无主页信息'), findsOneWidget);
  });

  testWidgets('failed homepage launch shows stale link message', (tester) async {
    await tester.pumpWidget(
      await _wrap(
        initialItems: [_item(homepageUrl: 'https://example.edu.cn/zhangsan')],
        launcher: _FakeLauncher(LaunchResult.failed),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('访问主页'));
    await tester.pumpAndSettle();

    expect(find.text('主页可能已失效，可通过学校官网确认'), findsOneWidget);
  });
}
