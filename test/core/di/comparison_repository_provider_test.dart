import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_comparison_repository.dart';
import 'package:scho_navi/data/http/http_comparison_repository.dart';

void main() {
  test('默认接 AiComparisonRepository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(comparisonRepositoryProvider),
      isA<AiComparisonRepository>(),
    );
  });

  test('dataSource=llm 接 AiComparisonRepository', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(comparisonRepositoryProvider),
      isA<AiComparisonRepository>(),
    );
  });

  test('dataSource=http 接 HttpComparisonRepository', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: '', apiBaseUrl: 'https://api.example.com'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(comparisonRepositoryProvider),
      isA<HttpComparisonRepository>(),
    );
  });
}
