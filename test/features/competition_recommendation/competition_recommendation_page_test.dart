import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/launcher/link_launcher.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/competition_query_understanding.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/recommended_competition.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/competition_recommendation_repository.dart';
import 'package:scho_navi/features/competition_recommendation/pages/competition_recommendation_page.dart';

class _FakeRepo implements CompetitionRecommendationRepository {
  const _FakeRepo(this._result);

  final Result<CompetitionRecommendationResult> _result;

  @override
  Future<Result<CompetitionRecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async => _result;
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

CompetitionRecommendationResult _data(List<RecommendedCompetition> recs) =>
    CompetitionRecommendationResult(
      sessionId: 'c_1',
      understanding: const CompetitionQueryUnderstanding(
        directions: ['数学建模'],
        categories: ['理学类'],
        timingPreferences: ['秋季/下半年'],
        teamPreferences: ['团队赛'],
        uncertainties: [],
      ),
      recommendations: recs,
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

Future<Widget> _wrap(
  Result<CompetitionRecommendationResult> result, {
  LinkLauncher? launcher,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const CompetitionRecommendationPage(prompt: '数学建模'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      competitionRecommendationRepositoryProvider.overrideWithValue(
        _FakeRepo(result),
      ),
      if (launcher != null) linkLauncherProvider.overrideWithValue(launcher),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _tapOfficialButton(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -280));
  await tester.pumpAndSettle();
  await tester.tap(find.text('访问官网'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows query understanding and competition list', (tester) async {
    await tester.pumpWidget(await _wrap(Success(_data([_rec]))));
    await tester.pumpAndSettle();

    expect(find.text('我理解到的竞赛需求'), findsOneWidget);
    expect(find.text('全国大学生数学建模竞赛'), findsOneWidget);
    expect(find.text('访问官网'), findsOneWidget);
  });

  testWidgets('shows EmptyView when no recommendations', (tester) async {
    await tester.pumpWidget(await _wrap(Success(_data(const []))));
    await tester.pumpAndSettle();

    expect(find.textContaining('暂未找到匹配的竞赛'), findsOneWidget);
  });

  testWidgets('shows ErrorView on failure', (tester) async {
    await tester.pumpWidget(await _wrap(const Failure(ServerException())));
    await tester.pumpAndSettle();

    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('official button calls injected launcher', (tester) async {
    final launcher = _FakeLauncher(LaunchResult.success);
    await tester.pumpWidget(
      await _wrap(Success(_data([_rec])), launcher: launcher),
    );
    await tester.pumpAndSettle();

    await _tapOfficialButton(tester);

    expect(launcher.openedUrl, 'http://www.mcm.edu.cn/');
  });

  testWidgets('empty official url shows noUrl message', (tester) async {
    const noUrl = RecommendedCompetition(
      id: 'comp_ai',
      name: '人工智能创意赛',
      category: '计算机类',
      level: '国家级',
      tags: ['人工智能'],
      teamSize: '1-4 人团队',
      signupTime: '以官网通知为准',
      contestTime: '以官网通知为准',
      format: '方案和答辩',
      organizer: '主办单位',
      officialUrl: null,
      reason: '方向匹配。',
      preparationTips: ['准备原型'],
      limitations: [],
      matchScore: 0.8,
    );
    await tester.pumpWidget(await _wrap(Success(_data([noUrl]))));
    await tester.pumpAndSettle();

    await _tapOfficialButton(tester);

    expect(find.text('暂无官网信息，请以学校或赛事官方通知为准'), findsOneWidget);
  });

  testWidgets('failed official launch shows competition stale link message', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(
        Success(_data([_rec])),
        launcher: _FakeLauncher(LaunchResult.failed),
      ),
    );
    await tester.pumpAndSettle();

    await _tapOfficialButton(tester);

    expect(find.text('官网可能暂时无法打开，请以赛事官方通知为准'), findsOneWidget);
  });
}
