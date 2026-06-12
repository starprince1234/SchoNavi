import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/ai/deepseek_llm_client.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/ai/ai_recommendation_repository.dart';

void main() {
  test('dataSource=ai wires AI repositories and DeepSeekLlmClient', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(recommendationRepositoryProvider),
      isA<AiRecommendationRepository>(),
    );
    expect(container.read(chatRepositoryProvider), isA<AiChatRepository>());
    expect(container.read(llmClientProvider), isA<DeepSeekLlmClient>());
  });

  test('default config still wires mock repositories', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(recommendationRepositoryProvider), isNotNull);
    expect(container.read(chatRepositoryProvider), isNotNull);
  });
}
