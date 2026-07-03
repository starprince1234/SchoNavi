import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';

ProviderContainer _c(AppConfig initial) => ProviderContainer(
  overrides: [initialAppConfigProvider.overrideWithValue(initial)],
);

void main() {
  test('默认初值为 llm', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).dataSource, DataSource.llm);
  });

  test('初值无 key 仍为 llm', () {
    final c = _c(AppConfig.resolve(apiKey: ''));
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).dataSource, DataSource.llm);
    expect(c.read(appConfigProvider).llm.isConfigured, isFalse);
  });

  test('可在 llm/http 间切换', () {
    final c = _c(AppConfig.resolve(apiKey: 'sk-test'));
    addTearDown(c.dispose);
    final ctrl = c.read(appConfigProvider.notifier);
    ctrl.setDataSource(DataSource.http);
    expect(c.read(appConfigProvider).dataSource, DataSource.http);
    ctrl.setDataSource(DataSource.llm);
    expect(c.read(appConfigProvider).dataSource, DataSource.llm);
  });

  test('setShowAiTrace 开关演示模式', () {
    final c = _c(const AppConfig());
    addTearDown(c.dispose);
    expect(c.read(appConfigProvider).featureFlags.showAiTrace, isFalse);
    c.read(appConfigProvider.notifier).setShowAiTrace(true);
    expect(c.read(appConfigProvider).featureFlags.showAiTrace, isTrue);
  });

  test('API error details are opt-in through resolved config', () {
    expect(
      AppConfig.resolve(apiKey: '').featureFlags.showApiErrorDetails,
      isFalse,
    );
    expect(
      AppConfig.resolve(
        apiKey: '',
        showApiErrorDetails: true,
      ).featureFlags.showApiErrorDetails,
      isTrue,
    );
  });
}
