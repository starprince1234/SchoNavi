import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/search_history_item.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/features/recommendation/providers/recommendation_provider.dart';

class _FakeRepo implements RecommendationRepository {
  _FakeRepo(this._result);

  final Result<RecommendationResult> _result;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async => _result;
}

class _FakeProfileRepo implements ProfileRepository {
  @override
  UserProfile load() => const UserProfile();
  @override
  Future<void> save(UserProfile profile) async {}
  @override
  Future<void> clear() async {}
}

class _FakeHistoryRepo implements HistoryRepository {
  @override
  List<SearchHistoryItem> list() => [];
  @override
  Stream<List<SearchHistoryItem>> watch() => Stream.value([]);
  @override
  Future<void> addFromResult({
    required String prompt,
    required RecommendationResult result,
  }) async {}
  @override
  Future<void> addFromCompetitionResult({
    required String prompt,
    required CompetitionRecommendationResult result,
  }) async {}
  @override
  Future<void> remove(String sessionId) async {}
  @override
  Future<void> clear() async {}
}

RecommendationResult _result({required bool empty}) => RecommendationResult(
  sessionId: 's_1',
  queryUnderstanding: const QueryUnderstanding(
    researchInterests: ['医学影像'],
    preferredLocations: ['上海'],
    preferredUniversities: [],
    uncertainties: [],
  ),
  recommendations: empty ? const [] : const [_rec],
  followUpQuestions: const [],
);

const _rec = Recommendation(
  professorId: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
  matchLevel: MatchLevel.high,
  reason: '方向相关。',
  limitations: [],
);

ProviderContainer _container(Result<RecommendationResult> result) => ProviderContainer(
  overrides: [
    profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
    historyRepositoryProvider.overrideWithValue(_FakeHistoryRepo()),
    recommendationRepositoryProvider.overrideWithValue(
      _FakeRepo(result),
    ),
  ],
);

void main() {
  test('provider resolves to data on Success', () async {
    final container = _container(Success(_result(empty: false)));
    addTearDown(container.dispose);

    final data = await container.read(recommendationProvider('医学影像').future);
    expect(data.sessionId, 's_1');
  });

  test('provider yields empty recommendations when result is empty', () async {
    final container = _container(Success(_result(empty: true)));
    addTearDown(container.dispose);

    final data = await container.read(recommendationProvider('x').future);
    expect(data.recommendations, isEmpty);
  });

  test('provider throws AppException on Failure', () async {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        historyRepositoryProvider.overrideWithValue(_FakeHistoryRepo()),
        recommendationRepositoryProvider.overrideWithValue(
          _FakeRepo(const Failure(ServerException())),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(recommendationProvider('x').future),
      throwsA(isA<ServerException>()),
    );
  });
}
