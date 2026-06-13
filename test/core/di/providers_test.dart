import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/data/mock/mock_favorite_repository.dart';
import 'package:scho_navi/data/mock/mock_history_repository.dart';
import 'package:scho_navi/data/mock/mock_professor_repository.dart';
import 'package:scho_navi/data/mock/mock_profile_extraction_repository.dart';
import 'package:scho_navi/data/mock/mock_profile_repository.dart';
import 'package:scho_navi/data/mock/mock_recommendation_repository.dart';
import 'package:scho_navi/domain/repositories/favorite_repository.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/domain/repositories/profile_extraction_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';

void main() {
  test('default config wires Mock repositories', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(recommendationRepositoryProvider),
      isA<MockRecommendationRepository>(),
    );
    expect(
      container.read(professorRepositoryProvider),
      isA<MockProfessorRepository>(),
    );
    expect(
      container.read(favoriteRepositoryProvider),
      isA<MockFavoriteRepository>(),
    );
    expect(
      container.read(historyRepositoryProvider),
      isA<MockHistoryRepository>(),
    );
    expect(
      container.read(profileRepositoryProvider),
      isA<MockProfileRepository>(),
    );
    expect(
      container.read(profileExtractionRepositoryProvider),
      isA<MockProfileExtractionRepository>(),
    );
    expect(
      container.read(recommendationRepositoryProvider),
      isA<RecommendationRepository>(),
    );
    expect(
      container.read(professorRepositoryProvider),
      isA<ProfessorRepository>(),
    );
    expect(
      container.read(favoriteRepositoryProvider),
      isA<FavoriteRepository>(),
    );
    expect(
      container.read(historyRepositoryProvider),
      isA<HistoryRepository>(),
    );
    expect(
      container.read(profileRepositoryProvider),
      isA<ProfileRepository>(),
    );
    expect(
      container.read(profileExtractionRepositoryProvider),
      isA<ProfileExtractionRepository>(),
    );
  });
}
