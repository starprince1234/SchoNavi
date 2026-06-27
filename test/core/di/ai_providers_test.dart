import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/ai/deepseek_llm_client.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_chat_repository.dart';
import 'package:scho_navi/data/ai/ai_competition_recommendation_repository.dart';
import 'package:scho_navi/data/ai/ai_recommendation_repository.dart';

void main() async {
  SharedPreferences.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();

  test('dataSource=llm wires LLM repositories and DeepSeekLlmClient', () {
    final container = ProviderContainer(
      overrides: [
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: 'sk-test'),
        ),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(recommendationRepositoryProvider),
      isA<AiRecommendationRepository>(),
    );
    expect(
      container.read(competitionRecommendationRepositoryProvider),
      isA<AiCompetitionRecommendationRepository>(),
    );
    expect(container.read(chatRepositoryProvider), isA<AiChatRepository>());
    expect(container.read(llmClientProvider), isA<DeepSeekLlmClient>());
  });

  test('default config still wires LLM repositories', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(recommendationRepositoryProvider),
      isA<AiRecommendationRepository>(),
    );
    expect(
      container.read(competitionRecommendationRepositoryProvider),
      isA<AiCompetitionRecommendationRepository>(),
    );
  });
}
