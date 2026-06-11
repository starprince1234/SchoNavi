import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/profile/pages/profile_page.dart';

class _Repo implements ProfileRepository {
  _Repo(this._p);
  UserProfile _p;
  @override
  UserProfile load() => _p;
  @override
  Future<void> save(UserProfile profile) async => _p = profile;
}

void main() {
  testWidgets('展示分区卡与完成度', (tester) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfilePage())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            _Repo(const UserProfile(name: '张三', gender: Gender.male)),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('竞赛成果'), findsOneWidget);
  });
}
