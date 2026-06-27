import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/features/professor/pages/professor_page.dart';
import 'package:scho_navi/features/recommendation/pages/recommendation_page.dart';

class _FakeRecRepo implements RecommendationRepository {
  _FakeRecRepo(this._result);

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

final _recResult = RecommendationResult(
  sessionId: 's_1',
  queryUnderstanding: const QueryUnderstanding(
    researchInterests: ['医学影像'],
    preferredLocations: ['上海'],
    preferredUniversities: [],
    uncertainties: [],
  ),
  recommendations: const [
    Recommendation(
      professorId: 'p_001',
      name: '张三',
      university: '上海交通大学',
      college: '电子信息与电气工程学院',
      title: '教授',
      researchFields: ['医学影像'],
      matchLevel: MatchLevel.high,
      reason: '方向相关。',
      limitations: [],
    ),
  ],
  followUpQuestions: const [],
);

Future<Widget> _wrapRecommendation() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const RecommendationPage(prompt: '医学影像'),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, s) => Text('chat:${s.uri.queryParameters['sid']}'),
      ),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
      recommendationRepositoryProvider.overrideWithValue(
        _FakeRecRepo(Success(_recResult)),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<Widget> _wrapProfessor() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ProfessorPage(
          professorId: 'p_001',
          mainSessionId: 's_main_1',
        ),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, s) => Text(
          'chat:${s.uri.queryParameters['fork']}|'
          '${s.uri.queryParameters['msid']}|'
          '${s.uri.queryParameters['pid']}',
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('推荐页不再有「继续追问」FAB', (tester) async {
    await tester.pumpWidget(await _wrapRecommendation());
    await tester.pumpAndSettle();

    expect(find.text('继续追问'), findsNothing);
  });

  testWidgets(
    '详情页「继续追问」以 fork 参数携带 msid 与 professorId 跳 /chat',
    (tester) async {
      await tester.pumpWidget(await _wrapProfessor());
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续追问'));
      await tester.pumpAndSettle();

      expect(find.text('chat:true|s_main_1|p_001'), findsOneWidget);
    },
  );
}
