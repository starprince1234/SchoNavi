import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/launcher/link_launcher.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/features/recommendation/pages/recommendation_page.dart';

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
  Future<UserProfile> refresh() async => load();
  @override
  Future<void> save(UserProfile profile) async {}
  @override
  Future<void> clear() async {}
}

class _FakeLauncher implements LinkLauncher {
  _FakeLauncher(this.result);

  final LaunchResult result;
  String? openedUrl;

  @override
  Future<LaunchResult> open(String? url) async {
    openedUrl = url;
    return result;
  }
}

RecommendationResult _data(List<Recommendation> recs) => RecommendationResult(
  sessionId: 's_1',
  queryUnderstanding: const QueryUnderstanding(
    researchInterests: ['医学影像'],
    preferredLocations: ['上海'],
    preferredUniversities: [],
    degreeStage: '硕士',
    uncertainties: ['未明确偏理论或应用'],
  ),
  recommendations: recs,
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
  homepageUrl: 'https://example.edu.cn/zhangsan',
);

Future<Widget> _wrap(
  Result<RecommendationResult> result, {
  LinkLauncher? launcher,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const RecommendationPage(prompt: '医学影像'),
      ),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
      recommendationRepositoryProvider.overrideWithValue(_FakeRepo(result)),
      if (launcher != null) linkLauncherProvider.overrideWithValue(launcher),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows query understanding and recommendation list', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap(Success(_data([_rec]))));
    await tester.pumpAndSettle();
    expect(find.textContaining('医学影像'), findsWidgets);
    expect(find.text('张三'), findsOneWidget);
  });

  testWidgets('shows EmptyView when no recommendations', (tester) async {
    await tester.pumpWidget(await _wrap(Success(_data(const []))));
    await tester.pumpAndSettle();
    expect(find.textContaining('暂未找到'), findsOneWidget);
  });

  testWidgets('shows ErrorView on failure', (tester) async {
    await tester.pumpWidget(await _wrap(const Failure(ServerException())));
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('favorite button toggles recommendation into local favorites', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap(Success(_data([_rec]))));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('收藏导师'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('取消收藏'), findsOneWidget);
  });

  testWidgets('homepage button calls injected launcher', (tester) async {
    final launcher = _FakeLauncher(LaunchResult.success);
    await tester.pumpWidget(
      await _wrap(Success(_data([_rec])), launcher: launcher),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('访问主页'));
    await tester.pumpAndSettle();

    expect(launcher.openedUrl, 'https://example.edu.cn/zhangsan');
  });

  testWidgets('empty homepage url shows noUrl message', (tester) async {
    const recWithoutUrl = Recommendation(
      professorId: 'p_002',
      name: '李四',
      university: '某大学',
      college: '某学院',
      title: '教授',
      researchFields: ['网络安全'],
      matchLevel: MatchLevel.medium,
      reason: '方向相关。',
      limitations: [],
    );
    await tester.pumpWidget(await _wrap(Success(_data([recWithoutUrl]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('访问主页'));
    await tester.pumpAndSettle();

    expect(find.text('暂无主页信息'), findsOneWidget);
  });

  testWidgets('failed homepage launch shows stale link message', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(
        Success(_data([_rec])),
        launcher: _FakeLauncher(LaunchResult.failed),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('访问主页'));
    await tester.pumpAndSettle();

    expect(find.text('主页可能已失效，可通过学校官网确认'), findsOneWidget);
  });
}
