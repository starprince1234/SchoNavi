import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/ai/missing_llm_client.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/ai/ai_competition_recommendation_repository.dart';
import 'package:scho_navi/data/ai/ai_profile_extraction_repository.dart';
import 'package:scho_navi/data/ai/ai_recommendation_repository.dart';
import 'package:scho_navi/data/local/local_favorite_repository.dart';
import 'package:scho_navi/data/local/local_history_repository.dart';
import 'package:scho_navi/data/local/local_profile_repository.dart';
import 'package:scho_navi/data/mock/mock_professor_repository.dart';
import 'package:scho_navi/domain/repositories/competition_recommendation_repository.dart';
import 'package:scho_navi/domain/repositories/favorite_repository.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
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
}
