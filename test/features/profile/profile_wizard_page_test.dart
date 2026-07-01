import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/profile/pages/profile_wizard_page.dart';

class _MemProfileRepo implements ProfileRepository {
  UserProfile p = const UserProfile();
  @override
  UserProfile load() => p;
  @override
  Future<UserProfile> refresh() async => load();
  @override
  Future<void> save(UserProfile profile) async => p = profile;
  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('填姓名→走到末步→完成，落盘并跳 /profile', (tester) async {
    final repo = _MemProfileRepo();
    final router = GoRouter(
      initialLocation: '/profile/wizard',
      routes: [
        GoRoute(
          path: '/profile/wizard',
          builder: (_, _) => const ProfileWizardPage(),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const Text('hub-marker')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '张三');
    // 步 1 → 2 → 3
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('hub-marker'), findsOneWidget);
    expect(repo.load().name, '张三');
  });

  testWidgets('step>0 点顶栏返回箭头回退上一步（不退出）', (tester) async {
    final repo = _MemProfileRepo();
    final router = GoRouter(
      initialLocation: '/profile/wizard',
      routes: [
        GoRoute(
          path: '/profile/wizard',
          builder: (_, _) => const ProfileWizardPage(),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const Text('hub-marker')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '张三');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 在 step 1：点顶栏返回箭头 → 回到 step 0（标题变回「基本信息」）
    final backButton = find.byTooltip('上一步');
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('成绩 & 方向'), findsNothing);
  });

  testWidgets('step>0 系统返回手势回退上一步（不退出）', (tester) async {
    final repo = _MemProfileRepo();
    final router = GoRouter(
      initialLocation: '/profile/wizard',
      routes: [
        GoRoute(
          path: '/profile/wizard',
          builder: (_, _) => const ProfileWizardPage(),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const Text('hub-marker')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '张三');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 模拟系统返回：PopScope 拦截后调 onSystemBack
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
    expect(find.text('成绩 & 方向'), findsOneWidget);
  });

  testWidgets('step 0 顶栏默认返回箭头 pop 整页', (tester) async {
    final repo = _MemProfileRepo();
    final router = GoRouter(
      initialLocation: '/profile/wizard',
      routes: [
        GoRoute(
          path: '/profile/wizard',
          builder: (_, _) => const ProfileWizardPage(),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const Text('hub-marker')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // step 0：无「上一步」tooltip 的自定义箭头，用默认 BackButton
    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isTrue);
  });
}
