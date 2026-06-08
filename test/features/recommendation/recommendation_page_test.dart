import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/features/recommendation/pages/recommendation_page.dart';

class _FakeRepo implements RecommendationRepository {
  _FakeRepo(this._result);

  final Result<RecommendationResult> _result;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    String? sessionId,
  }) async => _result;
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
);

Widget _wrap(Result<RecommendationResult> result) {
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
      recommendationRepositoryProvider.overrideWithValue(_FakeRepo(result)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows query understanding and recommendation list', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(Success(_data([_rec]))));
    await tester.pumpAndSettle();
    expect(find.textContaining('医学影像'), findsWidgets);
    expect(find.text('张三'), findsOneWidget);
  });

  testWidgets('shows EmptyView when no recommendations', (tester) async {
    await tester.pumpWidget(_wrap(Success(_data(const []))));
    await tester.pumpAndSettle();
    expect(find.textContaining('暂未找到'), findsOneWidget);
  });

  testWidgets('shows ErrorView on failure', (tester) async {
    await tester.pumpWidget(_wrap(const Failure(ServerException())));
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
  });
}
