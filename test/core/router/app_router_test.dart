import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/app.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/features/profile/providers/profile_provider.dart';

Future<Widget> _wrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'seenOnboarding': true,
  });
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Provide a non-empty profile to prevent ProfilePage from redirecting
      // to /profile/privacy during navigation tests.
      profileProvider.overrideWith(
        () => _StubProfileController(const UserProfile(name: 'Test User')),
      ),
    ],
    child: const SchoNaviApp(),
  );
}

class _StubProfileController extends ProfileController {
  _StubProfileController(this._profile);
  final UserProfile _profile;
  @override
  UserProfile build() => _profile;
}

void main() {
  testWidgets('home page shows search intro and menu button', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    expect(find.text('SchoNavi'), findsOneWidget);
    expect(find.byTooltip('菜单'), findsOneWidget);
  });

  testWidgets('drawer opens and shows history with favorites entry', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    final menuButton = find.byTooltip('菜单');
    expect(menuButton, findsOneWidget);

    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    expect(find.text('历史'), findsOneWidget);
    expect(find.byTooltip('我的收藏'), findsOneWidget);
  });

  testWidgets('drawer history entry navigates to history page', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('历史'));
    await tester.pumpAndSettle();

    expect(find.text('历史'), findsWidgets);
  });
}
