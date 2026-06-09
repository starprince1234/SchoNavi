import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_match_analysis_repository.dart';
import 'package:scho_navi/data/mock/mock_match_analysis_repository.dart';

void main() {
  test('默认（mock）接 MockMatchAnalysisRepository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(matchAnalysisRepositoryProvider),
      isA<MockMatchAnalysisRepository>(),
    );
  });

  test('dataSource=ai 接 AiMatchAnalysisRepository', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(matchAnalysisRepositoryProvider),
      isA<AiMatchAnalysisRepository>(),
    );
  });
}
