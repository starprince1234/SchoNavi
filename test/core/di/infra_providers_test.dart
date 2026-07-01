import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/launcher/link_launcher.dart';
import 'package:scho_navi/core/launcher/url_launcher_link_launcher.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/core/storage/shared_preferences_local_store.dart';

void main() {
  test('未 override 时读取 sharedPreferencesProvider 会抛错并带提示信息', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Object? caught;
    try {
      container.read(sharedPreferencesProvider);
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(caught.toString(), contains('overridden in main()'));
  });

  test(
    'override 后 localStoreProvider 产出 SharedPreferencesLocalStore',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final store = container.read(localStoreProvider);
      expect(store, isA<SharedPreferencesLocalStore>());
      expect(store, isA<LocalStore>());
    },
  );

  test('linkLauncherProvider 产出 UrlLauncherLinkLauncher', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final launcher = container.read(linkLauncherProvider);
    expect(launcher, isA<UrlLauncherLinkLauncher>());
    expect(launcher, isA<LinkLauncher>());
  });
}
