import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/repositories/comparison_repository.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/features/compare/pages/compare_page.dart';

class _FakeProfessorRepository implements ProfessorRepository {
  @override
  Future<Result<Professor>> getProfessor(String professorId) async => Success(
    Professor(
      id: professorId,
      name: professorId == 'p_001' ? '张三' : '王强',
      university: professorId == 'p_001' ? '上海交通大学' : '北京大学',
      college: 'C',
      title: '教授',
      researchFields: const ['方向'],
    ),
  );
}

class _FakeComparisonRepository implements ComparisonRepository {
  @override
  Future<Result<ComparisonReport>> compare({
    required List<String> professorIds,
  }) async {
    final professors = [
      for (final id in professorIds)
        Professor(
          id: id,
          name: id == 'p_001' ? '张三' : '王强',
          university: id == 'p_001' ? '上海交通大学' : '北京大学',
          college: 'C',
          title: '教授',
          researchFields: const ['方向'],
        ),
    ];
    return Success(
      ComparisonReport(
        professorIds: professorIds,
        professors: professors,
        rows: const [
          ComparisonRow(
            dimension: '研究方向',
            cells: {'p_001': '偏医学影像', 'p_003': '偏自动驾驶'},
          ),
        ],
        summary: '两位方向差异明显。',
        suggestion: '若看重医学影像优先张三。',
      ),
    );
  }
}

Widget _wrap() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ComparePage(ids: ['p_001', 'p_003']),
      ),
      GoRoute(
        path: '/professor/:id',
        builder: (_, state) => Text('professor:${state.pathParameters['id']}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      professorRepositoryProvider.overrideWithValue(_FakeProfessorRepository()),
      comparisonRepositoryProvider.overrideWithValue(
        _FakeComparisonRepository(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('渲染列头、维度与单元格', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('王强'), findsOneWidget);
    expect(find.text('研究方向'), findsOneWidget);
    expect(find.text('偏医学影像'), findsOneWidget);
    expect(find.text('总体小结'), findsOneWidget);
    expect(find.text('选择建议'), findsOneWidget);
  });

  testWidgets('点击列头跳导师详情', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('compare-header-p_001')));
    await tester.pumpAndSettle();

    expect(find.text('professor:p_001'), findsOneWidget);
  });
}
