import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_match_analysis_repository.dart';

void main() {
  test('默认接 AiMatchAnalysisRepository', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(matchAnalysisRepositoryProvider),
      isA<AiMatchAnalysisRepository>(),
    );
  });

  test('dataSource=llm 接 AiMatchAnalysisRepository', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
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
