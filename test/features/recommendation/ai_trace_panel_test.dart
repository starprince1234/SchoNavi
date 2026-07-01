import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/ai/llm_client.dart';
import 'package:scho_navi/core/ai/llm_trace.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/features/recommendation/pages/recommendation_page.dart';

class _FakeProfileRepo implements ProfileRepository {
  @override
  UserProfile load() => const UserProfile();
  @override
  Future<UserProfile> refresh() async => load();
  @override
  Future<void> save(UserProfile p) async {}
  @override
  Future<void> clear() async {}
}

class _FakeRecRepo implements RecommendationRepository {
  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async => const Success(
    RecommendationResult(
      sessionId: 's1',
      queryUnderstanding: QueryUnderstanding(
        researchInterests: ['医学影像'],
        preferredLocations: [],
        preferredUniversities: [],
        uncertainties: [],
      ),
      recommendations: [
        Recommendation(
          professorId: 'p_001',
          name: '张三',
          university: '上海交通大学',
          college: 'C',
          title: '教授',
          researchFields: ['医学影像'],
          matchLevel: MatchLevel.high,
          reason: '方向相关',
          limitations: [],
        ),
      ],
      followUpQuestions: [],
    ),
  );
}

Future<Widget> _wrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const RecommendationPage(prompt: '医学影像'),
      ),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
      GoRoute(path: '/chat', builder: (_, _) => const Placeholder()),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(
          dataSource: DataSource.llm,
          featureFlags: FeatureFlags(showAiTrace: true),
          llm: LlmConfig(apiKey: 'sk-test'),
        ),
      ),
      recommendationRepositoryProvider.overrideWithValue(_FakeRecRepo()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('演示模式 + 有 trace → 展开显示 model', (tester) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    // 注入一条 trace（模拟推荐调用已记录）
    final element = tester.element(find.byType(RecommendationPage));
    final container = ProviderScope.containerOf(element);
    container
        .read(aiTraceProvider.notifier)
        .record(
          const LlmTrace(
            model: 'deepseek-chat',
            messages: [LlmMessage('system', 'sys'), LlmMessage('user', '医学影像')],
            rawResponse: '{"recommendations":[]}',
            elapsedMs: 123,
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('查看 AI 详情'), findsOneWidget);
    await tester.tap(find.text('查看 AI 详情'));
    await tester.pumpAndSettle();

    expect(find.textContaining('deepseek-chat'), findsOneWidget);
  });
}
