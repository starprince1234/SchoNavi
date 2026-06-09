import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/chat_result.dart';
import 'package:scho_navi/domain/entities/match_level.dart';
import 'package:scho_navi/domain/entities/recommendation.dart';
import 'package:scho_navi/domain/repositories/chat_repository.dart';
import 'package:scho_navi/features/chat/pages/chat_page.dart';
import 'package:scho_navi/shared/widgets/professor_card.dart';

class _FakeChatRepo implements ChatRepository {
  _FakeChatRepo(this._result);

  final Result<ChatResult> _result;
  int calls = 0;

  @override
  Future<Result<ChatResult>> sendMessage({
    required String sessionId,
    required String message,
    String? professorId,
  }) async {
    calls++;
    return _result;
  }
}

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

Widget _wrap(_FakeChatRepo repo) {
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
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('挂载后显示标题与快捷问题', (tester) async {
    await tester.pumpWidget(_wrap(_FakeChatRepo(const Success(_okResult))));
    await tester.pumpAndSettle();

    expect(find.text('继续追问'), findsOneWidget);
    expect(find.text('有没有相似的导师？'), findsOneWidget);
  });

  testWidgets('点击快捷问题：用户消息上屏、回答带卡片、点击卡片跳转', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeChatRepo(
          const Success(
            ChatResult(
              sessionId: 's_test',
              answer: '相近导师如下',
              relatedRecommendations: [_rec],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('有没有相似的导师？'));
    await tester.pumpAndSettle();

    expect(find.text('有没有相似的导师？'), findsWidgets);
    expect(find.byType(ProfessorCard), findsOneWidget);

    await tester.tap(find.byType(ProfessorCard));
    await tester.pumpAndSettle();
    expect(find.byType(Placeholder), findsOneWidget);
  });

  testWidgets('重新生成会再次调用仓储', (tester) async {
    final repo = _FakeChatRepo(const Success(_okResult));
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('适合硕士申请吗？'));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    await tester.tap(find.byTooltip('重新生成'));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
  });
}

const _okResult = ChatResult(
  sessionId: 's_test',
  answer: '测试回答',
  relatedRecommendations: [],
);
