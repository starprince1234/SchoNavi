import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/llm_recommendation_need_classifier.dart';
import 'package:scho_navi/data/http/http_recommendation_need_classifier.dart';

void main() {
  test('dataSource=llm 接 LlmRecommendationNeedClassifier', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(recommendationNeedClassifierProvider),
      isA<LlmRecommendationNeedClassifier>(),
    );
  });

  test('dataSource=http 接 HttpRecommendationNeedClassifier', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: '', apiBaseUrl: 'https://api.example.com'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(recommendationNeedClassifierProvider),
      isA<HttpRecommendationNeedClassifier>(),
    );
  });
}
