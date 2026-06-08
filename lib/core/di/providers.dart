import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_db.dart';
import '../../data/mock/mock_professor_repository.dart';
import '../../data/mock/mock_recommendation_repository.dart';
import '../../domain/repositories/professor_repository.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../config/app_config.dart';

final mockDbProvider = Provider<MockDb>((ref) => MockDb());

final recommendationRepositoryProvider = Provider<RecommendationRepository>((
  ref,
) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
      return MockRecommendationRepository(ref.watch(mockDbProvider));
    case DataSource.http:
      // V1.0：返回 HttpRecommendationRepository(ref.watch(dioClientProvider))
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});

final professorRepositoryProvider = Provider<ProfessorRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  switch (cfg.dataSource) {
    case DataSource.mock:
      return MockProfessorRepository(ref.watch(mockDbProvider));
    case DataSource.http:
      throw UnimplementedError('HTTP data source not wired until V1.0');
  }
});
