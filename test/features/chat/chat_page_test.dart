import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_message.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/entities/favorite_item.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/search_history_item.dart';
import 'package:scho_navi/domain/entities/user_profile.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/domain/repositories/favorite_repository.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
import 'package:scho_navi/domain/repositories/profile_repository.dart';
import 'package:scho_navi/domain/repositories/recommendation_repository.dart';
import 'package:scho_navi/features/chat/pages/chat_page.dart';
import 'package:scho_navi/features/chat/widgets/chat_message_bubble.dart';
import 'package:scho_navi/shared/utils/quick_actions_source.dart';
import 'package:scho_navi/shared/utils/recommendation_need_classifier.dart';
import 'package:scho_navi/shared/widgets/swipe_recommendation_card.dart';

class _StreamChatRepo implements ChatRepository {
  _StreamChatRepo(this.build);

  final Stream<String> Function() build;
  int streamCalls = 0;

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async => throw UnimplementedError();

  @override
  void seedRecommendationTurn({
    required String sessionId,
    required String userPrompt,
    required RecommendationResult result,
  }) {}

  @override
  Stream<String> streamReply({
    required String sessionId,
    required String message,
    String? professorId,
  }) {
    streamCalls++;
    return build();
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

Widget _wrap(_StreamChatRepo repo) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ChatPage(sessionId: 's_test'),
      ),
      GoRoute(path: '/professor/:id', builder: (_, _) => const Placeholder()),
    ],
  );
  return ProviderScope(
    overrides: [
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(llm: LlmConfig(apiKey: 'test-key')),
      ),
      chatRepositoryProvider.overrideWithValue(repo),
      recommendationNeedClassifierProvider.overrideWithValue(
        const _FakeNeedClassifier(false),
      ),
      quickActionsSourceProvider.overrideWithValue(
        const _FailingQuickActionsSource(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('挂载后显示悬浮按钮与快捷操作', (tester) async {
    await tester.pumpWidget(
      _wrap(_StreamChatRepo(() => Stream.fromIterable(const ['x']))),
    );
    await tester.pumpAndSettle();

    // 旧会话追问路径（sessionId 非 null、无 initialPrompt）左上为「返回」。
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byTooltip('重新生成'), findsWidgets);
    expect(find.text('换一批'), findsOneWidget);
  });

  testWidgets('点击快捷操作：用户消息上屏并流式返回回答', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['流式', '回答']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('换一批'));
    await tester.pumpAndSettle();

    expect(find.text('换一批'), findsWidgets);
    expect(repo.streamCalls, 1);
    expect(find.byType(GptMarkdown), findsWidgets);
  });

  testWidgets('响应中显示「停止生成」，点击后恢复「发送」', (tester) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    await tester.pumpWidget(_wrap(_StreamChatRepo(() => controller.stream)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士'));
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

  testWidgets('重新生成会再次调用仓储', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士'));
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 1);

    await tester.tap(find.byTooltip('重新生成').first);
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 2);
  });

  testWidgets('助手消息气泡显示操作栏工具提示', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('解释理由'));
    await tester.pumpAndSettle();

    final bubble = find.byType(ChatMessageBubble).last;
    expect(
      find.descendant(of: bubble, matching: find.byTooltip('复制')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bubble, matching: find.byTooltip('重新生成')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bubble, matching: find.byTooltip('有用')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bubble, matching: find.byTooltip('没用')),
      findsOneWidget,
    );
  });

  testWidgets('点击复制按钮显示已复制提示', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士'));
    await tester.pumpAndSettle();

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final bubble = find.byType(ChatMessageBubble).last;
    await tester.tap(
      find.descendant(of: bubble, matching: find.byTooltip('复制')),
    );
    await tester.pumpAndSettle();

    expect(find.text('已复制'), findsOneWidget);
  });

  testWidgets('点赞按钮可切换状态', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士'));
    await tester.pumpAndSettle();

    final bubble = find.byType(ChatMessageBubble).last;

    await tester.tap(
      find.descendant(of: bubble, matching: find.byTooltip('有用')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: bubble, matching: find.byIcon(Icons.thumb_up)),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: bubble, matching: find.byTooltip('有用')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: bubble,
        matching: find.byIcon(Icons.thumb_up_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('点击单条消息重新生成会再次调用仓储', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士'));
    await tester.pumpAndSettle();
    expect(repo.streamCalls, 1);

    final bubble = find.byType(ChatMessageBubble).last;
    await tester.tap(
      find.descendant(of: bubble, matching: find.byTooltip('重新生成')),
    );
    await tester.pumpAndSettle();

    expect(repo.streamCalls, 2);
  });

  // ---- 对话式推荐首轮（initialPrompt）路径 ----

  group('对话式首轮 initialPrompt', () {
    RecommendationResult recResult() => RecommendationResult(
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
      followUpQuestions: const ['除了北京，你是否还考虑其他地方的导师？', '只看北京', '偏应用', '适合博士'],
    );

    Widget wrapConversational({required ChatRepository chatRepo}) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const ChatPage(initialPrompt: '想做计算机视觉，想去北京'),
          ),
          GoRoute(
            path: '/professor/:id',
            builder: (_, _) => const Placeholder(),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          initialAppConfigProvider.overrideWithValue(
            const AppConfig(llm: LlmConfig(apiKey: 'test-key')),
          ),
          chatRepositoryProvider.overrideWithValue(chatRepo),
          recommendationRepositoryProvider.overrideWithValue(
            _FakeRecRepo(Success(recResult())),
          ),
          recommendationNeedClassifierProvider.overrideWithValue(
            _FakeNeedClassifier(false),
          ),
          quickActionsSourceProvider.overrideWithValue(
            const _FailingQuickActionsSource(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
          historyRepositoryProvider.overrideWithValue(_FakeHistoryRepo()),
          favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('首轮即产用户消息 + 助手横滑推荐卡片，不显示欢迎卡', (tester) async {
      final chat = _StreamChatRepo(() => Stream.fromIterable(const ['可以追问']));
      await tester.pumpWidget(wrapConversational(chatRepo: chat));
      await tester.pumpAndSettle();

      // 用户消息上屏（列表可能滚出视口，跳过离屏过滤）。
      expect(find.text('想做计算机视觉，想去北京', skipOffstage: false), findsOneWidget);
      // 助手横滑卡片出现。
      expect(find.byType(SwipeRecommendationCard), findsOneWidget);
      expect(find.text('张三'), findsOneWidget);
      expect(find.text('除了北京，你是否还考虑其他地方的导师？'), findsNothing);
      expect(find.text('只看北京'), findsOneWidget);
      expect(find.text('偏应用'), findsOneWidget);
      // initialPrompt 路径不显示欢迎卡。
      expect(find.text('有什么想追问的？', skipOffstage: false), findsNothing);
    });

    testWidgets('点击卡片跳导师详情', (tester) async {
      final chat = _StreamChatRepo(() => Stream.fromIterable(const ['ok']));
      await tester.pumpWidget(wrapConversational(chatRepo: chat));
      await tester.pumpAndSettle();

      await tester.tap(find.text('张三'));
      await tester.pumpAndSettle();

      expect(find.byType(Placeholder), findsOneWidget);
    });
  });

  testWidgets('未配置 LLM Key 时直达聊天页显示错误且不请求推荐', (tester) async {
    final rec = _CountingRecRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppConfigProvider.overrideWithValue(const AppConfig()),
          recommendationRepositoryProvider.overrideWithValue(rec),
        ],
        child: const MaterialApp(home: ChatPage(initialPrompt: '想做计算机视觉')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('未配置 LLM_API_KEY'), findsOneWidget);
    expect(rec.calls, 0);
  });

  testWidgets('两个 ChatPage 使用独立状态，返回后恢复原会话消息', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['答案']));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ChatPage(sessionId: 'first'),
        ),
        GoRoute(
          path: '/second',
          builder: (_, _) => const ChatPage(sessionId: 'second'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppConfigProvider.overrideWithValue(
            const AppConfig(llm: LlmConfig(apiKey: 'test-key')),
          ),
          chatRepositoryProvider.overrideWithValue(repo),
          recommendationNeedClassifierProvider.overrideWithValue(
            const _FakeNeedClassifier(false),
          ),
          quickActionsSourceProvider.overrideWithValue(
            const _FailingQuickActionsSource(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士'));
    await tester.pumpAndSettle();
    expect(find.text('答案'), findsOneWidget);

    router.push('/second');
    await tester.pumpAndSettle();
    expect(find.byType(ChatMessageBubble), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('答案'), findsOneWidget);
  });

  testWidgets('不再渲染 AppBar 实体栏', (tester) async {
    await tester.pumpWidget(
      _wrap(_StreamChatRepo(() => Stream.fromIterable(const ['x']))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('新会话页(initialPrompt)左上新对话按钮跳转首页', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const ChatPage(initialPrompt: '想做计算机视觉'),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Text('home-marker'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppConfigProvider.overrideWithValue(
            const AppConfig(llm: LlmConfig(apiKey: 'test-key')),
          ),
          chatRepositoryProvider.overrideWithValue(repo),
          recommendationRepositoryProvider.overrideWithValue(
            _FakeRecRepo(
              Success(
                RecommendationResult(
                  sessionId: 's_rec',
                  queryUnderstanding: const QueryUnderstanding(
                    researchInterests: ['计算机视觉'],
                    preferredLocations: [],
                    preferredUniversities: [],
                    degreeStage: null,
                    uncertainties: [],
                  ),
                  recommendations: const [],
                  followUpQuestions: const [],
                ),
              ),
            ),
          ),
          recommendationNeedClassifierProvider.overrideWithValue(
            const _FakeNeedClassifier(false),
          ),
          quickActionsSourceProvider.overrideWithValue(
            const _FailingQuickActionsSource(),
          ),
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepo()),
          historyRepositoryProvider.overrideWithValue(_FakeHistoryRepo()),
          favoriteRepositoryProvider.overrideWithValue(_FakeFavoriteRepo()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // initialPrompt 新会话页左上为「新对话」，点击回首页。
    expect(find.byTooltip('新对话'), findsOneWidget);
    await tester.tap(find.byTooltip('新对话'));
    await tester.pumpAndSettle();

    expect(find.text('home-marker'), findsOneWidget);
  });

  testWidgets('旧会话追问页左上返回按钮 pop 回上一页', (tester) async {
    final repo = _StreamChatRepo(() => Stream.fromIterable(const ['x']));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('root-marker'),
        ),
        GoRoute(
          path: '/chat',
          builder: (_, _) => const ChatPage(sessionId: 's_test'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialAppConfigProvider.overrideWithValue(
            const AppConfig(llm: LlmConfig(apiKey: 'test-key')),
          ),
          chatRepositoryProvider.overrideWithValue(repo),
          recommendationNeedClassifierProvider.overrideWithValue(
            const _FakeNeedClassifier(false),
          ),
          quickActionsSourceProvider.overrideWithValue(
            const _FailingQuickActionsSource(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/chat');
    await tester.pumpAndSettle();

    // 旧会话追问页左上为「返回」，点击 pop 回根路由。
    expect(find.byTooltip('返回'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('root-marker'), findsOneWidget);
  });
}

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

class _CountingRecRepo implements RecommendationRepository {
  int calls = 0;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async {
    calls++;
    return const Failure(ServerException());
  }
}

class _FakeNeedClassifier implements RecommendationNeedClassifier {
  const _FakeNeedClassifier(this._value);
  final bool _value;
  @override
  Future<bool> needRecommendations(
    String followUp, {
    RecommendationResult? lastResult,
  }) async => _value;
}

class _FailingQuickActionsSource implements QuickActionsSource {
  const _FailingQuickActionsSource();

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async => const Failure(NetworkException());
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
  List<SearchHistoryItem> list() => const [];
  @override
  Stream<List<SearchHistoryItem>> watch() => const Stream.empty();
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

class _FakeFavoriteRepo implements FavoriteRepository {
  final _items = <String, FavoriteItem>{};
  final _controller = StreamController<List<FavoriteItem>>.broadcast();
  @override
  List<FavoriteItem> list() => _items.values.toList();
  @override
  Stream<List<FavoriteItem>> watch() => _controller.stream;
  @override
  bool isFavorite(String professorId) => _items.containsKey(professorId);
  @override
  Future<void> add(FavoriteItem item) async {
    _items[item.professorId] = item;
    _controller.add(list());
  }

  @override
  Future<void> remove(String professorId) async {
    _items.remove(professorId);
    _controller.add(list());
  }

  @override
  Future<bool> toggle(FavoriteItem item) async {
    if (_items.containsKey(item.professorId)) {
      await remove(item.professorId);
      return false;
    }
    await add(item);
    return true;
  }
}
