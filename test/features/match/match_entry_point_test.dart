import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/features/professor/pages/professor_page.dart';

const _professor = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像'],
);

class _FakeProfessorRepo implements ProfessorRepository {
  @override
  Future<Result<Professor>> getProfessor(String id) async =>
      const Success(_professor);
}

void main() {
  testWidgets('详情页「匹配分析」跳 /match?pid=', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ProfessorPage(professorId: 'p_001'),
        ),
        GoRoute(
          path: '/match',
          builder: (_, state) =>
              Text('match:${state.uri.queryParameters['pid']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          professorRepositoryProvider.overrideWithValue(_FakeProfessorRepo()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('匹配分析'));
    await tester.pumpAndSettle();

    expect(find.text('match:p_001'), findsOneWidget);
  });
}
