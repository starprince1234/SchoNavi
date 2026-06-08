import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/core/di/providers.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';
import 'package:scho_navi/features/professor/pages/professor_page.dart';

class _FakeRepo implements ProfessorRepository {
  _FakeRepo(this._result);

  final Result<Professor> _result;

  @override
  Future<Result<Professor>> getProfessor(String id) async => _result;
}

Widget _wrap(Result<Professor> result) => ProviderScope(
  overrides: [professorRepositoryProvider.overrideWithValue(_FakeRepo(result))],
  child: const MaterialApp(home: ProfessorPage(professorId: 'p_001')),
);

void main() {
  testWidgets('renders professor info', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Success(
          Professor(
            id: 'p_001',
            name: '张三',
            university: '上海交通大学',
            college: '电子信息与电气工程学院',
            title: '教授',
            researchFields: ['医学影像'],
            bio: '研究医学影像。',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('张三  教授'), findsOneWidget);
    expect(find.textContaining('研究医学影像'), findsOneWidget);
  });

  testWidgets('shows 暂无信息 for missing bio', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Success(
          Professor(
            id: 'p_x',
            name: '李四',
            university: '某大学',
            college: '某学院',
            title: '讲师',
            researchFields: ['网络安全'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('暂无信息'), findsWidgets);
  });

  testWidgets('shows ErrorView on failure', (tester) async {
    await tester.pumpWidget(_wrap(const Failure(NotFoundException())));
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
  });
}
