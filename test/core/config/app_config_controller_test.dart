import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';

ProviderContainer _c(AppConfig initial) => ProviderContainer(
  overrides: [initialAppConfigProvider.overrideWithValue(initial)],
);

void main() {
  test('默认初值 → mock', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).dataSource, DataSource.mock);
  });

  test('初值有 key → ai', () {
    final c = _c(AppConfig.resolve(apiKey: 'sk-test'));
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).dataSource, DataSource.ai);
  });

  test('无 key 时切 ai 被拒（保持 mock）', () {
    final c = _c(AppConfig.resolve(apiKey: ''));
    addTearDown(c.dispose);
    c.read(appConfigProvider.notifier).setDataSource(DataSource.ai);
    expect(c.read(appConfigProvider).dataSource, DataSource.mock);
  });

  test('有 key 时可在 ai/mock 间切换', () {
    final c = _c(AppConfig.resolve(apiKey: 'sk-test'));
    addTearDown(c.dispose);
    final ctrl = c.read(appConfigProvider.notifier);
    ctrl.setDataSource(DataSource.mock);
    expect(c.read(appConfigProvider).dataSource, DataSource.mock);
    ctrl.setDataSource(DataSource.ai);
    expect(c.read(appConfigProvider).dataSource, DataSource.ai);
  });

  test('setShowAiTrace 开关演示模式', () {
    final c = _c(const AppConfig());
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).featureFlags.showAiTrace, isFalse);
    c.read(appConfigProvider.notifier).setShowAiTrace(true);
    expect(c.read(appConfigProvider).featureFlags.showAiTrace, isTrue);
  });
}
