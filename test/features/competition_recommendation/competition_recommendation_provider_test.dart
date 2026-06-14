import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition_query_understanding.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/search_history_item.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/competition_recommendation_repository.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/features/competition_recommendation/providers/competition_recommendation_provider.dart';

class _FakeRepo implements CompetitionRecommendationRepository {
  _FakeRepo(this._result);

  final Result<CompetitionRecommendationResult> _result;

  @override
  Future<Result<CompetitionRecommendationResult>> getRecommendations({
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
  int competitionWrites = 0;

  @override
  List<SearchHistoryItem> list() => [];

  @override
  Stream<List<SearchHistoryItem>> watch() => Stream.value(const []);

  @override
  Future<void> addFromResult({
    required String prompt,
    required RecommendationResult result,
  }) async {}

  @override
  Future<void> addFromCompetitionResult({
    required String prompt,
    required CompetitionRecommendationResult result,
  }) async {
    competitionWrites++;
  }

  @override
  Future<void> remove(String sessionId) async {}

  @override
  Future<void> clear() async {}
}

CompetitionRecommendationResult _result({required bool empty}) =>
    CompetitionRecommendationResult(
      sessionId: 'c_1',
      understanding: const CompetitionQueryUnderstanding(
        directions: ['数学建模'],
        categories: ['理学类'],
        timingPreferences: ['秋季/下半年'],
        teamPreferences: ['团队赛'],
        uncertainties: [],
      ),
      recommendations: empty ? const [] : const [_rec],
      followUpQuestions: const [],
    );

const _rec = RecommendedCompetition(
  id: 'comp_math_modeling',
  name: '全国大学生数学建模竞赛',
  category: '理学类',
  level: '国家级',
  tags: ['数学建模', '团队赛'],
  teamSize: '3 人团队',
  signupTime: '以官网通知为准',
  contestTime: '通常每年 9 月',
  format: '建模、编程和论文写作',
  organizer: '中国工业与应用数学学会',
  officialUrl: 'http://www.mcm.edu.cn/',
  reason: '方向匹配。',
  preparationTips: ['训练论文写作'],
  limitations: ['以官网通知为准。'],
  matchScore: 0.91,
);

ProviderContainer _container(
  Result<CompetitionRecommendationResult> result, {
  required _FakeHistoryRepo history,
}) => ProviderContainer(
  overrides: [
    profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
    historyRepositoryProvider.overrideWithValue(history),
    competitionRecommendationRepositoryProvider.overrideWithValue(
      _FakeRepo(result),
    ),
  ],
  retry: (_, _) => null,
);

void main() {
  test('success with recommendations writes competition history', () async {
    final history = _FakeHistoryRepo();
    final container = _container(Success(_result(empty: false)), history: history);
    addTearDown(container.dispose);

    final data = await container.read(
      competitionRecommendationProvider('数学建模').future,
    );
    expect(data.sessionId, 'c_1');
    await Future<void>.delayed(Duration.zero);
    expect(history.competitionWrites, 1);
  });

  test('success with empty recommendations does not write history', () async {
    final history = _FakeHistoryRepo();
    final container = _container(Success(_result(empty: true)), history: history);
    addTearDown(container.dispose);

    await container.read(competitionRecommendationProvider('x').future);
    await Future<void>.delayed(Duration.zero);
    expect(history.competitionWrites, 0);
  });

  test('failure throws app exception', () async {
    final history = _FakeHistoryRepo();
    final container = _container(
      const Failure(ServerException()),
      history: history,
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      competitionRecommendationProvider('x'),
      (_, _) {},
    );
    addTearDown(sub.close);

    await expectLater(
      container.read(competitionRecommendationProvider('x').future),
      throwsA(isA<ServerException>()),
    );
    expect(history.competitionWrites, 0);
  });
}
