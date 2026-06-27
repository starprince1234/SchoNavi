import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/app.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/shared/utils/recommendation_intent_router.dart';
import 'package:scho_navi/shared/utils/recommendation_need_classifier.dart';

class _FakeIntentClassifier implements RecommendationIntentClassifier {
  @override
  Future<RecommendationIntent> classify(String prompt) async {
    return RecommendationIntent.mentor;
  }
}

/// 假对话仓储：推荐上下文注入为空实现。
class _FakeChatRepo implements ChatRepository {
  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async => throw UnimplementedError();

  @override
  Future<void> seedRecommendationTurn({
    required String sessionId,
    required String userPrompt,
    required RecommendationResult result,
  }) async {}

  @override
  Future<void> persistMessages(
    String sessionId,
    List<ChatMessage> messages,
  ) async {}

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) async* {
    yield '可以左右滑动查看推荐的导师。';
  }

  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> deleteFork({required String forkId}) async =>
      throw UnimplementedError();
}

class _FakeNeedClassifier implements RecommendationNeedClassifier {
  const _FakeNeedClassifier();
  @override
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  }) async => false;
}

class _FakeRecommendationRepository implements RecommendationRepository {
  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async {
    return const Success(
      RecommendationResult(
        sessionId: 's_1',
        queryUnderstanding: QueryUnderstanding(
          researchInterests: ['医学影像', '计算机视觉'],
          preferredLocations: ['上海'],
          preferredUniversities: [],
          degreeStage: '硕士',
          uncertainties: [],
        ),
        recommendations: [
          Recommendation(
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
          ),
        ],
        followUpQuestions: [],
      ),
    );
  }
}

Future<ProviderScope> _wrap() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'seenOnboarding': true,
    'profile_prompt_dismissed': true,
  });
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(llm: LlmConfig(apiKey: 'test-key')),
      ),
      recommendationIntentClassifierProvider.overrideWithValue(
        _FakeIntentClassifier(),
      ),
      recommendationRepositoryProvider.overrideWithValue(
        _FakeRecommendationRepository(),
      ),
      chatRepositoryProvider.overrideWithValue(_FakeChatRepo()),
      recommendationNeedClassifierProvider.overrideWithValue(
        const _FakeNeedClassifier(),
      ),
    ],
    child: const SchoNaviApp(),
  );
}

void main() {
  testWidgets('input -> 对话式推荐 -> favorite -> detail -> favorites/history', (
    tester,
  ) async {
    await tester.pumpWidget(await _wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '我想找医学影像和计算机视觉方向的导师，最好在上海');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    // 对话式：原地进入对话态（不跳路由），首页内出现用户消息 + 横滑推荐卡片。
    expect(find.text('我想找医学影像和计算机视觉方向的导师，最好在上海', skipOffstage: false), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);

    await tester.tap(find.byTooltip('收藏导师').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消收藏'), findsOneWidget);

    await tester.tap(find.text('张三').first);
    await tester.pumpAndSettle();
    expect(find.text('导师详情'), findsOneWidget);
    expect(find.text('研究方向'), findsOneWidget);

    // 仅 professor 路由在 /home 之上（对话态是首页原地，无独立 /chat 路由），
    // 一次 pageBack 即回到首页对话态。
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('菜单'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('我的收藏'));
    await tester.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('菜单'));
    await tester.pumpAndSettle();

    final historyTexts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => t.contains('医学影像和计算机视觉'));
    expect(historyTexts, isNotEmpty);
  });
}
