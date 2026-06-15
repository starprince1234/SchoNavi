import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/ai/missing_llm_client.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_competition_recommendation_repository.dart';
import 'package:scho_navi/data/ai/ai_profile_extraction_repository.dart';
import 'package:scho_navi/data/ai/ai_recommendation_repository.dart';
import 'package:scho_navi/data/http/http_chat_repository.dart';
import 'package:scho_navi/data/http/http_comparison_repository.dart';
import 'package:scho_navi/data/http/http_competition_recommendation_repository.dart';
import 'package:scho_navi/data/http/http_favorite_repository.dart';
import 'package:scho_navi/data/http/http_history_repository.dart';
import 'package:scho_navi/data/http/http_match_analysis_repository.dart';
import 'package:scho_navi/data/http/http_outreach_email_repository.dart';
import 'package:scho_navi/data/http/http_professor_repository.dart';
import 'package:scho_navi/data/http/http_profile_extraction_repository.dart';
import 'package:scho_navi/data/http/http_profile_repository.dart';
import 'package:scho_navi/data/http/http_recommendation_repository.dart';
import 'package:scho_navi/data/local/local_favorite_repository.dart';
import 'package:scho_navi/data/local/local_history_repository.dart';
import 'package:scho_navi/data/local/local_profile_repository.dart';
import 'package:scho_navi/data/mock/mock_professor_repository.dart';
import 'package:scho_navi/domain/repositories/competition_recommendation_repository.dart';
import 'package:scho_navi/domain/repositories/comparison_repository.dart';
import 'package:scho_navi/domain/repositories/favorite_repository.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
import 'package:scho_navi/domain/repositories/match_analysis_repository.dart';
import 'package:scho_navi/domain/repositories/outreach_email_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/domain/repositories/profile_extraction_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';

void main() {
  test('default config wires LLM-first repositories', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(llmClientProvider), isA<MissingLlmClient>());
    expect(
      container.read(recommendationRepositoryProvider),
      isA<AiRecommendationRepository>(),
    );
    expect(
      container.read(competitionRecommendationRepositoryProvider),
      isA<AiCompetitionRecommendationRepository>(),
    );
    expect(
      container.read(professorRepositoryProvider),
      isA<MockProfessorRepository>(),
    );
    expect(
      container.read(favoriteRepositoryProvider),
      isA<LocalFavoriteRepository>(),
    );
    expect(
      container.read(historyRepositoryProvider),
      isA<LocalHistoryRepository>(),
    );
    expect(
      container.read(profileRepositoryProvider),
      isA<LocalProfileRepository>(),
    );
    expect(
      container.read(profileExtractionRepositoryProvider),
      isA<AiProfileExtractionRepository>(),
    );
    expect(
      container.read(recommendationRepositoryProvider),
      isA<RecommendationRepository>(),
    );
    expect(
      container.read(competitionRecommendationRepositoryProvider),
      isA<CompetitionRecommendationRepository>(),
    );
    expect(
      container.read(professorRepositoryProvider),
      isA<ProfessorRepository>(),
    );
    expect(
      container.read(favoriteRepositoryProvider),
      isA<FavoriteRepository>(),
    );
    expect(container.read(historyRepositoryProvider), isA<HistoryRepository>());
    expect(container.read(profileRepositoryProvider), isA<ProfileRepository>());
    expect(
      container.read(profileExtractionRepositoryProvider),
      isA<ProfileExtractionRepository>(),
    );
  });

  test('http config wires every contract-backed repository', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialAppConfigProvider.overrideWithValue(
          AppConfig.resolve(apiKey: '', apiBaseUrl: 'https://api.example.com'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(recommendationRepositoryProvider),
      isA<HttpRecommendationRepository>(),
    );
    expect(
      container.read(competitionRecommendationRepositoryProvider),
      isA<HttpCompetitionRecommendationRepository>(),
    );
    expect(container.read(professorRepositoryProvider), isA<HttpProfessorRepository>());
    expect(container.read(chatRepositoryProvider), isA<HttpChatRepository>());
    expect(container.read(comparisonRepositoryProvider), isA<HttpComparisonRepository>());
    expect(
      container.read(matchAnalysisRepositoryProvider),
      isA<HttpMatchAnalysisRepository>(),
    );
    expect(
      container.read(outreachEmailRepositoryProvider),
      isA<HttpOutreachEmailRepository>(),
    );
    expect(container.read(profileRepositoryProvider), isA<HttpProfileRepository>());
    expect(
      container.read(profileExtractionRepositoryProvider),
      isA<HttpProfileExtractionRepository>(),
    );
    expect(container.read(favoriteRepositoryProvider), isA<HttpFavoriteRepository>());
    expect(container.read(historyRepositoryProvider), isA<HttpHistoryRepository>());

    expect(container.read(recommendationRepositoryProvider), isA<RecommendationRepository>());
    expect(
      container.read(competitionRecommendationRepositoryProvider),
      isA<CompetitionRecommendationRepository>(),
    );
    expect(container.read(professorRepositoryProvider), isA<ProfessorRepository>());
    expect(container.read(comparisonRepositoryProvider), isA<ComparisonRepository>());
    expect(
      container.read(matchAnalysisRepositoryProvider),
      isA<MatchAnalysisRepository>(),
    );
    expect(
      container.read(outreachEmailRepositoryProvider),
      isA<OutreachEmailRepository>(),
    );
    expect(container.read(favoriteRepositoryProvider), isA<FavoriteRepository>());
    expect(container.read(historyRepositoryProvider), isA<HistoryRepository>());
    expect(container.read(profileRepositoryProvider), isA<ProfileRepository>());
  });
}
