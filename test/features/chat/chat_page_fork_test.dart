import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/config/app_config.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/storage/local_store.dart';
import 'package:scho_navi/data/local/local_chat_history_store.dart';
import 'package:scho_navi/data/mock/mock_chat_repository.dart';
import 'package:scho_navi/data/mock/mock_db.dart';
import 'package:scho_navi/domain/entities/query_understanding.dart';
import 'package:scho_navi/domain/entities/recommendation_result.dart';
import 'package:scho_navi/features/chat/pages/chat_page.dart';
import 'package:scho_navi/features/chat/widgets/professor_anchor_bar.dart';
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

RecommendationResult _recResult(String sid) => RecommendationResult(
      sessionId: sid,
      queryUnderstanding: const QueryUnderstanding(
        researchInterests: [],
        preferredLocations: [],
        preferredUniversities: [],
        uncertainties: [],
      ),
      recommendations: const [],
      followUpQuestions: const [],
    );

void main() {
  testWidgets('fork 模式渲染锚点条', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = MockChatRepository(
      MockDb(),
      historyStore: LocalChatHistoryStore(_MemStore()),
      streamChunkDelay: Duration.zero,
    );
    const sessionId = 's1';
    final professorId = MockDb().allProfessors.first.id;

    await repo.seedRecommendationTurn(
      sessionId: sessionId,
      userPrompt: '想做CV',
      result: _recResult(sessionId),
    );
    await repo.forkSession(
      sourceSessionId: sessionId,
      professorId: professorId,
    );

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(dataSource: DataSource.http),
      ),
    ]);
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/chat',
          builder: (_, _) => UncontrolledProviderScope(
            container: container,
            child: ChatPage(
              forkMode: true,
              mainSessionId: sessionId,
              professorId: professorId,
            ),
          ),
        ),
        GoRoute(
          path: '/professor/:id',
          builder: (_, state) => Scaffold(
            body: Text(
              'msid=${state.uri.queryParameters['msid'] ?? 'none'}',
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(ProfessorAnchorBar), findsOneWidget);
  });

  testWidgets('锚点条点击携带 mainSessionId 作为 msid 跳转到教授详情', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = MockChatRepository(
      MockDb(),
      historyStore: LocalChatHistoryStore(_MemStore()),
      streamChunkDelay: Duration.zero,
    );
    const sessionId = 's_main_42';
    final professorId = MockDb().allProfessors.first.id;

    await repo.seedRecommendationTurn(
      sessionId: sessionId,
      userPrompt: '想做CV',
      result: _recResult(sessionId),
    );
    await repo.forkSession(
      sourceSessionId: sessionId,
      professorId: professorId,
    );

    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      initialAppConfigProvider.overrideWithValue(
        const AppConfig(dataSource: DataSource.http),
      ),
    ]);
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/chat',
          builder: (_, _) => UncontrolledProviderScope(
            container: container,
            child: ChatPage(
              forkMode: true,
              mainSessionId: sessionId,
              professorId: professorId,
            ),
          ),
        ),
        GoRoute(
          path: '/professor/:id',
          builder: (_, state) => Scaffold(
            body: Text(
              'msid=${state.uri.queryParameters['msid'] ?? 'none'}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(ProfessorAnchorBar), findsOneWidget);

    await tester.tap(find.byType(ProfessorAnchorBar));
    await tester.pumpAndSettle();

    expect(find.text('msid=$sessionId'), findsOneWidget);
  });
}
