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
        GoRoute(path: '/profile/wizard', builder: (_, _) => const ProfileWizardPage()),
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
}
