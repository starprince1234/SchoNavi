import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/favorite_item.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/search_history_item.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/favorite_repository.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/settings/pages/settings_page.dart';

Future<Widget> _wrap(AppConfig initial) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialAppConfigProvider.overrideWithValue(initial),
    ],
    child: const MaterialApp(home: SettingsPage()),
  );
}

class _FakeFavoriteRepo implements FavoriteRepository {
  @override
  List<FavoriteItem> list() => const [];
  @override
  Stream<List<FavoriteItem>> watch() => Stream.value(const []);
  @override
  bool isFavorite(String professorId) => false;
  @override
  Future<void> add(FavoriteItem item) async {}
  @override
  Future<void> remove(String professorId) async {}
  @override
  Future<bool> toggle(FavoriteItem item) async => true;
}

class _FailingHistoryRepo implements HistoryRepository {
  @override
  List<SearchHistoryItem> list() => const [];
  @override
  Stream<List<SearchHistoryItem>> watch() => Stream.value(const []);
  @override
  Future<void> addFromResult({
    required String prompt,
    required RecommendationResult result,
  }) async {}
  @override
  Future<void> addFromCompetitionResult({
    required String prompt,
    required CompetitionRecommendationResult result,
  }) async {}
  @override
  Future<void> remove(String sessionId) async {}
  @override
  Future<void> clear() async => throw const ValidationException('远端删除失败');
}

class _FakeProfileRepo implements ProfileRepository {
  @override
  UserProfile load() => const UserProfile();
  @override
  Future<UserProfile> refresh() async => load();
  @override
  Future<void> save(UserProfile profile) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('无 key 时展示 LLM 模式和配置缺失提示', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: '')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-data-source')), findsOneWidget);
    expect(find.textContaining('LLM 模式'), findsOneWidget);
    expect(find.textContaining('未配置 LLM_API_KEY'), findsOneWidget);
    expect(find.textContaining('离线 Mock'), findsNothing);
  });

  testWidgets('有 key 时展示当前模型', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: 'sk-test')));
    await tester.pumpAndSettle();

    expect(find.textContaining('LLM 模式'), findsOneWidget);
    expect(find.text('deepseek-chat'), findsOneWidget);
  });

  testWidgets('演示模式开关 -> showAiTrace', (tester) async {
    await tester.pumpWidget(await _wrap(AppConfig.resolve(apiKey: 'sk-test')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-demo-switch')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(appConfigProvider).featureFlags.showAiTrace, isTrue);
  });

  testWidgets('HTTP 模式展示远端资料文案', (tester) async {
    await tester.pumpWidget(
      await _wrap(
        AppConfig.resolve(apiKey: '', apiBaseUrl: 'https://api.example.com'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('后端 Origin'), findsOneWidget);
    expect(find.text('删除远端资料'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('会同步到后端'), findsOneWidget);
    expect(find.textContaining('资料仅保存在本机'), findsNothing);
  });

  testWidgets('HTTP 远端清除失败时展示错误', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialAppConfigProvider.overrideWithValue(
            AppConfig.resolve(
              apiKey: '',
              apiBaseUrl: 'https://api.example.com',
            ),
          ),
          favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
          historyRepositoryProvider.overrideWithValue(_FailingHistoryRepo()),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除远端资料'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();

    expect(find.text('远端删除失败'), findsOneWidget);
  });
}
