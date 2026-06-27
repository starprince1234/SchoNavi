import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/competition_recommendation_result.dart';
import 'package:scho_navi/domain/entities/fork_ref.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/domain/entities/search_history_item.dart';
import 'package:scho_navi/domain/repositories/history_repository.dart';
import 'package:scho_navi/features/history/pages/history_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemStore implements LocalStore {
  final Map<String, dynamic> _m = {};

  @override
  String? getString(String key) => _m[key] as String?;

  @override
  Future<void> setString(String key, String value) async => _m[key] = value;

  @override
  bool? getBool(String key) => _m[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _m[key] = value;

  @override
  Map<String, dynamic>? getJson(String key) => _m[key] as Map<String, dynamic>?;

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      _m[key] = value;

  @override
  List<dynamic>? getJsonList(String key) => _m[key] as List<dynamic>?;

  @override
  Future<void> setJsonList(String key, List<dynamic> value) async =>
      _m[key] = value;

  @override
  bool containsKey(String key) => _m.containsKey(key);

  @override
  Future<void> remove(String key) async => _m.remove(key);

  @override
  Future<void> clear() async => _m.clear();
}

class _FakeHistoryRepo implements HistoryRepository {
  _FakeHistoryRepo(List<SearchHistoryItem> items) : _items = List.of(items) {
    _controller = StreamController<List<SearchHistoryItem>>.broadcast();
    Future<void>.delayed(Duration.zero, () => _add(_items));
  }

  void _add(List<SearchHistoryItem> items) {
    if (!_controller.isClosed) _controller.add(List.unmodifiable(items));
  }

  final List<SearchHistoryItem> _items;
  late final StreamController<List<SearchHistoryItem>> _controller;

  @override
  List<SearchHistoryItem> list() => List.unmodifiable(_items);

  @override
  Stream<List<SearchHistoryItem>> watch() => _controller.stream;

  @override
  Future<void> addFromResult({
    required String prompt,
    required RecommendationResult result,
  }) async {
    _items.add(SearchHistoryItem(
      sessionId: result.sessionId,
      prompt: prompt,
      createdAt: DateTime.now(),
      summary: '',
      researchInterests: result.queryUnderstanding.researchInterests,
      preferredLocations: result.queryUnderstanding.preferredLocations,
      recommendationCount: result.recommendations.length,
    ));
    _add(_items);
  }

  @override
  Future<void> addFromCompetitionResult({
    required String prompt,
    required CompetitionRecommendationResult result,
  }) async {
    _items.add(SearchHistoryItem(
      sessionId: result.sessionId,
      prompt: prompt,
      createdAt: DateTime.now(),
      summary: '',
      researchInterests: const [],
      preferredLocations: const [],
      recommendationCount: result.recommendations.length,
      type: SearchHistoryType.competition,
    ));
    _add(_items);
  }

  @override
  Future<void> remove(String sessionId) async {
    _items.removeWhere((i) => i.sessionId == sessionId);
    _add(_items);
  }

  @override
  Future<void> clear() async {
    _items.clear();
    _add(_items);
  }
}

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HistoryPage()),
        GoRoute(
          path: '/chat',
          builder: (_, state) {
            final q = state.uri.queryParameters;
            return Text('fork=${q['fork']}&fid=${q['fid']}');
          },
        ),
      ],
    );

RecommendationResult _mentorResult() => RecommendationResult(
      sessionId: 's1',
      queryUnderstanding: const QueryUnderstanding(
        researchInterests: ['计算机视觉'],
        preferredLocations: ['北京'],
        preferredUniversities: [],
        uncertainties: [],
      ),
      recommendations: const [],
      followUpQuestions: const [],
    );

Widget _pump({
  required HistoryRepository historyRepo,
  required MockChatRepository chatRepo,
}) {
  final container = ProviderContainer(overrides: [
    chatRepositoryProvider.overrideWithValue(chatRepo),
    historyRepositoryProvider.overrideWithValue(historyRepo),
  ]);
  addTearDown(container.dispose);

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: _router()),
  );
}

MockChatRepository _chatRepo() => MockChatRepository(
      MockDb(),
      historyStore: LocalChatHistoryStore(_MemStore()),
      streamChunkDelay: Duration.zero,
    );

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('主条目仅标题 + 加号，无摘要/计数/标签', (tester) async {
    final chatRepo = _chatRepo();
    await chatRepo.seedRecommendationTurn(
      sessionId: 's1',
      userPrompt: '想做CV，想去北京',
      result: _mentorResult(),
    );
    await chatRepo.forkSession(
      sourceSessionId: 's1',
      professorId: MockDb().allProfessors.first.id,
    );

    await tester.pumpWidget(_pump(
      historyRepo: _FakeHistoryRepo([
        SearchHistoryItem(
          sessionId: 's1',
          prompt: '想做CV，想去北京',
          createdAt: DateTime(2026, 6, 27),
          summary: '为你挑选了 4 位导师',
          researchInterests: ['计算机视觉'],
          preferredLocations: ['北京'],
          recommendationCount: 4,
        ),
      ]),
      chatRepo: chatRepo,
    ));
    await tester.pumpAndSettle();

    expect(find.text('想做CV，想去北京'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.textContaining('为你挑'), findsNothing);
    expect(find.textContaining('位导师'), findsNothing);
    expect(find.textContaining('4 位导师'), findsNothing);
  });

  testWidgets('点击加号展开子项并显示导师信息', (tester) async {
    final chatRepo = _chatRepo();
    await chatRepo.seedRecommendationTurn(
      sessionId: 's1',
      userPrompt: '想做CV',
      result: _mentorResult(),
    );
    final profId = MockDb().allProfessors.first.id;
    await chatRepo.forkSession(sourceSessionId: 's1', professorId: profId);

    await tester.pumpWidget(_pump(
      historyRepo: _FakeHistoryRepo([
        SearchHistoryItem(
          sessionId: 's1',
          prompt: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          summary: '',
          researchInterests: [],
          preferredLocations: [],
          recommendationCount: 0,
        ),
      ]),
      chatRepo: chatRepo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text(MockDb().allProfessors.first.name), findsOneWidget);
    expect(find.textContaining(MockDb().allProfessors.first.university),
        findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget); // plus still present (rotated)
  });

  testWidgets('无 fork 展开显示“暂无追问历史”', (tester) async {
    await tester.pumpWidget(_pump(
      historyRepo: _FakeHistoryRepo([
        SearchHistoryItem(
          sessionId: 's1',
          prompt: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          summary: '',
          researchInterests: [],
          preferredLocations: [],
          recommendationCount: 0,
        ),
      ]),
      chatRepo: _chatRepo(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('暂无追问历史'), findsOneWidget);
  });

  testWidgets('子项点击导航到 /chat?fork=true&fid=forkId', (tester) async {
    final chatRepo = _chatRepo();
    await chatRepo.seedRecommendationTurn(
      sessionId: 's1',
      userPrompt: '想做CV',
      result: _mentorResult(),
    );
    final profId = MockDb().allProfessors.first.id;
    final forkRes =
        await chatRepo.forkSession(sourceSessionId: 's1', professorId: profId);
    final forkId = (forkRes as Success<String>).data;

    await tester.pumpWidget(_pump(
      historyRepo: _FakeHistoryRepo([
        SearchHistoryItem(
          sessionId: 's1',
          prompt: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          summary: '',
          researchInterests: [],
          preferredLocations: [],
          recommendationCount: 0,
        ),
      ]),
      chatRepo: chatRepo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text(MockDb().allProfessors.first.name));
    await tester.pumpAndSettle();

    expect(find.text('fork=true&fid=$forkId'), findsOneWidget);
  });

  testWidgets('子项左滑删除并刷新 fork 列表', (tester) async {
    final chatRepo = _chatRepo();
    await chatRepo.seedRecommendationTurn(
      sessionId: 's1',
      userPrompt: '想做CV',
      result: _mentorResult(),
    );
    final profId = MockDb().allProfessors.first.id;
    await chatRepo.forkSession(sourceSessionId: 's1', professorId: profId);

    await tester.pumpWidget(_pump(
      historyRepo: _FakeHistoryRepo([
        SearchHistoryItem(
          sessionId: 's1',
          prompt: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          summary: '',
          researchInterests: [],
          preferredLocations: [],
          recommendationCount: 0,
        ),
      ]),
      chatRepo: chatRepo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final profName = MockDb().allProfessors.first.name;
    expect(find.text(profName), findsOneWidget);

    await tester.drag(find.text(profName), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text(profName), findsNothing);
    final forks = await chatRepo.listForks(mainSessionId: 's1');
    expect((forks as Success<List<ForkRef>>).data, isEmpty);
  });

  testWidgets('主条目左滑级联删除，先删 fork 再去掉主记录', (tester) async {
    final chatRepo = _chatRepo();
    await chatRepo.seedRecommendationTurn(
      sessionId: 's1',
      userPrompt: '想做CV',
      result: _mentorResult(),
    );
    final profId = MockDb().allProfessors.first.id;
    await chatRepo.forkSession(sourceSessionId: 's1', professorId: profId);

    await tester.pumpWidget(_pump(
      historyRepo: _FakeHistoryRepo([
        SearchHistoryItem(
          sessionId: 's1',
          prompt: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          summary: '',
          researchInterests: [],
          preferredLocations: [],
          recommendationCount: 0,
        ),
      ]),
      chatRepo: chatRepo,
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.text('想做CV'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('想做CV'), findsNothing);
    final forks = await chatRepo.listForks(mainSessionId: 's1');
    expect((forks as Success<List<ForkRef>>).data, isEmpty);
  });

  testWidgets('展开两 fork 后删除一个，立即刷新且折叠再展开只剩一个', (tester) async {
    final chatRepo = _chatRepo();
    await chatRepo.seedRecommendationTurn(
      sessionId: 's1',
      userPrompt: '想做CV',
      result: _mentorResult(),
    );
    final db = MockDb();
    final prof0 = db.allProfessors[0];
    final prof1 = db.allProfessors[1];
    await chatRepo.forkSession(sourceSessionId: 's1', professorId: prof0.id);
    await chatRepo.forkSession(sourceSessionId: 's1', professorId: prof1.id);

    await tester.pumpWidget(_pump(
      historyRepo: _FakeHistoryRepo([
        SearchHistoryItem(
          sessionId: 's1',
          prompt: '想做CV',
          createdAt: DateTime(2026, 6, 27),
          summary: '',
          researchInterests: [],
          preferredLocations: [],
          recommendationCount: 0,
        ),
      ]),
      chatRepo: chatRepo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text(prof0.name), findsOneWidget);
    expect(find.text(prof1.name), findsOneWidget);

    await tester.drag(find.text(prof0.name), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text(prof0.name), findsNothing,
        reason: '被删除的 fork 应立即从展开列表中消失');
    expect(find.text(prof1.name), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text(prof0.name), findsNothing,
        reason: '折叠后重新展开不应再显示已删除 fork');
    expect(find.text(prof1.name), findsOneWidget);
    final forks = await chatRepo.listForks(mainSessionId: 's1');
    final remaining = (forks as Success<List<ForkRef>>).data;
    expect(remaining.length, 1);
    expect(remaining.first.professorName, prof1.name);
  });
}
