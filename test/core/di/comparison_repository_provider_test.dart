import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_comparison_repository.dart';
import 'package:scho_navi/data/mock/mock_comparison_repository.dart';

void main() {
  test('默认（mock）接 MockComparisonRepository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(comparisonRepositoryProvider),
      isA<MockComparisonRepository>(),
    );
  });

  test('dataSource=ai 接 AiComparisonRepository', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
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
}
