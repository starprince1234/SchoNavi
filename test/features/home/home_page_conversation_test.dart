import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
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
import 'package:scho_navi/features/chat/providers/chat_provider.dart';
import 'package:scho_navi/features/home/pages/home_page.dart';
import 'package:scho_navi/shared/utils/quick_actions_source.dart';
import 'package:scho_navi/shared/utils/recommendation_need_classifier.dart';
import 'package:scho_navi/shared/widgets/swipe_recommendation_card.dart';

final _recResult = RecommendationResult(
  sessionId: 's_rec',
  queryUnderstanding: const QueryUnderstanding(
    researchInterests: ['计算机视觉'],
    preferredLocations: ['北京'],
    preferredUniversities: [],
    degreeStage: null,
    uncertainties: [],
  ),
  recommendations: const [
    Recommendation(
      professorId: 'p_001',
      name: '张三',
      university: '清华大学',
      college: '计算机学院',
      title: '教授',
      researchFields: ['计算机视觉'],
      matchLevel: MatchLevel.high,
      reason: '方向契合',
      limitations: [],
    ),
  ],
  followUpQuestions: const ['除了北京，你是否还考虑其他地方的导师？', '只看北京', '偏应用'],
);

class _FakeRecRepo implements RecommendationRepository {
  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async => Success(_recResult);
}

/// 可控行为的对话仓储：streamReply 用注入的 stream，便于停止生成测试。
class _ControllableChatRepo implements ChatRepository {
  _ControllableChatRepo(this.streamFactory);

  final Stream<String> Function() streamFactory;
  int streamCalls = 0;

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
  }) {
    streamCalls++;
    return streamFactory();
  }

  @override
  Future<Result<String>> forkSession({
    required String sourceSessionId,
    required String professorId,
  }) async => throw UnimplementedError();

  @override
  Future<Result<List<ChatMessage>>> loadHistory({
    required String sessionId,
  }) async => throw UnimplementedError();

  @override
  Future<Result<List<ForkRef>>> listForks({
    required String mainSessionId,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> deleteFork({required String forkId}) async =>
      throw UnimplementedError();
}

/// 可按调用次数返回不同分类结果的分类器：首轮不需要，追问按队列返回。
class _ScriptedNeedClassifier implements RecommendationNeedClassifier {
  _ScriptedNeedClassifier(this._values);
  final List<bool> _values;
  int _calls = 0;

  @override
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  }) async {
    if (_calls < _values.length) return _values[_calls++];
    return _values.last;
  }
}

class _FailingQuickActionsSource implements QuickActionsSource {
  const _FailingQuickActionsSource();

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async => const Failure(NetworkException());
}

Future<Widget> _wrap({
  required _ControllableChatRepo chatRepo,
  required RecommendationNeedClassifier classifier,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
      GoRoute(path: '/chat', builder: (_, _) => const SizedBox.shrink()),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(llm: LlmConfig(apiKey: 'test-key')),
      ),
      recommendationRepositoryProvider.overrideWithValue(_FakeRecRepo()),
      chatRepositoryProvider.overrideWithValue(chatRepo),
      recommendationNeedClassifierProvider.overrideWithValue(classifier),
      quickActionsSourceProvider.overrideWithValue(
        const _FailingQuickActionsSource(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _startConversation(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '想做计算机视觉，想去北京');
  await tester.pump();
  await tester.tap(find.byIcon(Icons.arrow_upward));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('首轮原地对话：用户消息 + 推荐卡 + 动态快捷操作，不跳 /chat', (tester) async {
    final chat = _ControllableChatRepo(() => Stream.fromIterable(const ['ok']));
    await _startConversation(
      tester,
      await _wrap(chatRepo: chat, classifier: _ScriptedNeedClassifier([false])),
    );

    expect(find.text('想做计算机视觉，想去北京', skipOffstage: false), findsOneWidget);
    expect(find.byType(SwipeRecommendationCard), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    // 动态快捷操作来自推荐结果的 followUpQuestions，长问句会被过滤。
    expect(find.text('除了北京，你是否还考虑其他地方的导师？'), findsNothing);
    expect(find.text('只看北京'), findsOneWidget);
    expect(find.text('偏应用'), findsOneWidget);
    expect(find.byTooltip('新对话'), findsOneWidget);
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    // 落地态品牌字标在对话态隐藏。
    expect(find.text('SchoNavi'), findsNothing);
  });

  testWidgets('追问走流式回答（need=false）：点击快捷操作触发 streamReply', (tester) async {
    final chat = _ControllableChatRepo(
      () => Stream.fromIterable(const ['流式', '回答']),
    );
    await _startConversation(
      tester,
      await _wrap(chatRepo: chat, classifier: _ScriptedNeedClassifier([false])),
    );

    // 点击动态快捷操作 → send → classifier need=false → 流式回答。
    await tester.tap(find.text('只看北京'));
    await tester.pumpAndSettle();

    expect(chat.streamCalls, 1);
    expect(find.text('流式回答'), findsWidgets);
  });

  testWidgets('追问走产卡（need=true）：再推一批触发 recommendationRepository', (
    tester,
  ) async {
    final chat = _ControllableChatRepo(() => Stream.fromIterable(const ['ok']));
    await _startConversation(
      tester,
      await _wrap(chatRepo: chat, classifier: _ScriptedNeedClassifier([true])),
    );

    // 输入追问并发送 → classifier need=true → 产新卡（不调 streamReply）。
    await tester.enterText(find.byType(TextField), '换一批导师');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(chat.streamCalls, 0);
    // 产卡后助手消息里仍含横滑卡片。
    expect(find.byType(SwipeRecommendationCard), findsWidgets);
  });

  testWidgets('流式生成中显示「停止生成」，点击后恢复「发送」', (tester) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    final chat = _ControllableChatRepo(() => controller.stream);
    await _startConversation(
      tester,
      await _wrap(chatRepo: chat, classifier: _ScriptedNeedClassifier([false])),
    );

    await tester.tap(find.text('只看北京'));
    await tester.pump();
    controller.add('部分答案');
    await tester.pump();

    expect(find.byTooltip('停止生成'), findsOneWidget);
    expect(find.byTooltip('发送'), findsNothing);

    await tester.tap(find.byTooltip('停止生成'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('发送'), findsOneWidget);
    expect(find.byTooltip('停止生成'), findsNothing);
  });

  testWidgets('点击新对话清空当前对话，回到落地页（品牌字标重现）', (tester) async {
    final chat = _ControllableChatRepo(() => Stream.fromIterable(const ['ok']));
    await _startConversation(
      tester,
      await _wrap(chatRepo: chat, classifier: _ScriptedNeedClassifier([false])),
    );

    expect(find.text('SchoNavi'), findsNothing);
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    await tester.tap(find.byTooltip('新对话'));
    await tester.pumpAndSettle();

    expect(find.text('SchoNavi'), findsOneWidget);
    expect(find.byType(SwipeRecommendationCard), findsNothing);
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.byTooltip('新对话'), findsNothing);
  });

  testWidgets('ChatActivity 枚举可被首页引用（编译期守护）', (tester) async {
    // 仅保证 home_page 对 ChatActivity.streaming 的引用在编译期成立。
    expect(ChatActivity.streaming, ChatActivity.streaming);
  });
}
