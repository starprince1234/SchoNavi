import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/domain/entities/feedback.dart';
import 'package:scho_navi/features/feedback/widgets/feedback_entry_button.dart';

void main() {
  testWidgets('点击反馈入口跳转 /feedback 并携带 type=recommendation 上下文', (tester) async {
    String? pushedLocation;
    final router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        if (state.matchedLocation == '/feedback') {
          pushedLocation = state.uri.toString();
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(
              child: FeedbackEntryButton(
                type: FeedbackType.recommendation,
                messageId: 'msg_42',
                prompt: '推荐张三',
                label: '反馈这条推荐',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/feedback',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byTooltip('反馈这条推荐'), findsOneWidget);
    await tester.tap(find.byTooltip('反馈这条推荐'));
    await tester.pumpAndSettle();

    expect(pushedLocation, isNotNull);
    expect(pushedLocation!, contains('/feedback'));
    expect(pushedLocation, contains('type=recommendation'));
    expect(pushedLocation, contains('mid=msg_42'));
    expect(pushedLocation, contains('prompt='));
  });

  testWidgets('导师场景跳转携带 type=missing_professor 与 pid', (tester) async {
    String? pushedLocation;
    final router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        if (state.matchedLocation == '/feedback') {
          pushedLocation = state.uri.toString();
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(
              child: FeedbackEntryButton(
                type: FeedbackType.missingProfessor,
                professorId: 'p_001',
                route: '/professor/p_001',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/feedback',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byTooltip('反馈'));
    await tester.pumpAndSettle();

    expect(pushedLocation, isNotNull);
    expect(pushedLocation!, contains('/feedback'));
    expect(pushedLocation, contains('type=missing_professor'));
    expect(pushedLocation, contains('pid=p_001'));
    expect(pushedLocation, contains('route=%2Fprofessor%2Fp_001'));
  });

  testWidgets('备赛助手场景跳转携带 type=bug 与 route', (tester) async {
    String? pushedLocation;
    final router = GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        if (state.matchedLocation == '/feedback') {
          pushedLocation = state.uri.toString();
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Center(
              child: FeedbackEntryButton(
                type: FeedbackType.bug,
                route: '/preparation-plans',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/feedback',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byTooltip('反馈'));
    await tester.pumpAndSettle();

    expect(pushedLocation, isNotNull);
    expect(pushedLocation!, contains('/feedback'));
    expect(pushedLocation, contains('type=bug'));
    expect(pushedLocation, contains('route=%2Fpreparation-plans'));
  });
}
