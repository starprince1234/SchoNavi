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
import 'package:scho_navi/features/competition_recommendation/providers/competition_home_notifier.dart';

class _FakeRepo implements CompetitionRecommendationRepository {
  _FakeRepo(this._outcome);
  final Result<CompetitionRecommendationResult> _outcome;
  int calls = 0;
  @override
  Future<Result<CompetitionRecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async {
    calls++;
    return _outcome;
  }
}

class _FakeProfileRepo implements ProfileRepository {
  @override
  UserProfile load() => const UserProfile();

  @override
  Future<UserProfile> refresh() async => load();

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

CompetitionRecommendationResult _result(int n) =>
    CompetitionRecommendationResult(
      sessionId: 's1',
      understanding: const CompetitionQueryUnderstanding(
        directions: [],
        categories: [],
        timingPreferences: [],
        teamPreferences: [],
        uncertainties: [],
      ),
      recommendations: List.generate(
        n,
        (i) => RecommendedCompetition(
          id: 'c$i',
          name: 'C$i',
          category: '计算机类',
          level: '国家级',
          tags: const [],
          teamSize: '个人',
          signupTime: '',
          contestTime: '',
          format: '',
          organizer: '',
          officialUrl: null,
          reason: '',
          preparationTips: const [],
          limitations: const [],
          matchScore: 0.5,
        ),
      ),
      followUpQuestions: const [],
    );

ProviderContainer _container(Result<CompetitionRecommendationResult> outcome) {
  return ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
      historyRepositoryProvider.overrideWithValue(_FakeHistoryRepo()),
      competitionRecommendationRepositoryProvider.overrideWithValue(
        _FakeRepo(outcome),
      ),
    ],
  );
}

void main() {
  test('submit 成功进入 result', () async {
    final container = _container(Success(_result(2)));
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('我想参加算法竞赛');
    final s = container.read(competitionHomeProvider);
    expect(s, isA<CompetitionHomeResult>());
    expect((s as CompetitionHomeResult).data.recommendations.length, 2);
  });

  test('空结果进入 empty', () async {
    final container = _container(Success(_result(0)));
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('x');
    expect(
      container.read(competitionHomeProvider),
      isA<CompetitionHomeEmpty>(),
    );
  });

  test('失败进入 error', () async {
    final container = _container(const Failure(UnknownException()));
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('x');
    expect(
      container.read(competitionHomeProvider),
      isA<CompetitionHomeError>(),
    );
  });

  test('reset 回到 idle', () async {
    final container = _container(Success(_result(1)));
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('x');
    container.read(competitionHomeProvider.notifier).reset();
    expect(container.read(competitionHomeProvider), isA<CompetitionHomeIdle>());
  });

  test('竞态：后一次 submit 覆盖前一次', () async {
    final slow = _FakeRepo(Success(_result(1)));
    final fakeHistory = _FakeHistoryRepo();
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
        historyRepositoryProvider.overrideWithValue(fakeHistory),
        competitionRecommendationRepositoryProvider.overrideWithValue(slow),
      ],
    );
    addTearDown(container.dispose);
    await container.read(competitionHomeProvider.notifier).submit('a');
    await container.read(competitionHomeProvider.notifier).submit('b');
    expect(
      container.read(competitionHomeProvider),
      isA<CompetitionHomeResult>(),
    );
    expect(slow.calls, 2);
  });
}
