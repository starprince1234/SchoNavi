import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/error/app_exception.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_comparison_repository.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';
import 'package:scho_navi/domain/repositories/professor_repository.dart';

const _p1 = Professor(
  id: 'p_001',
  name: '张三',
  university: '上海交通大学',
  college: '电子信息与电气工程学院',
  title: '教授',
  researchFields: ['医学影像', '计算机视觉'],
);

const _p3 = Professor(
  id: 'p_003',
  name: '王强',
  university: '北京大学',
  college: '信息科学技术学院',
  title: '教授',
  researchFields: ['自动驾驶'],
);

class _FakeProfessorRepository implements ProfessorRepository {
  @override
  Future<Result<Professor>> getProfessor(String professorId) async {
    if (professorId == _p1.id) return const Success(_p1);
    if (professorId == _p3.id) return const Success(_p3);
    return const Failure(NotFoundException());
  }
}

void main() {
  final repo = MockComparisonRepository(
    professorRepository: _FakeProfessorRepository(),
  );

  test('rows 含关键维度，每位导师均有单元格', () async {
    final result = await repo.compare(
      professorIds: [_p1.id, _p3.id],
    );
    final report = (result as Success<ComparisonReport>).data;

    expect(report.professorIds, [_p1.id, _p3.id]);
    expect(report.professors.map((p) => p.id), [_p1.id, _p3.id]);
    expect(report.rows.map((row) => row.dimension), contains('研究方向'));
    for (final row in report.rows) {
      expect(row.cells.containsKey(_p1.id), isTrue);
      expect(row.cells.containsKey(_p3.id), isTrue);
    }
    expect(report.summary, isNotEmpty);
    expect(report.suggestion, isNotEmpty);
  });

  test('少于 2 位返回 ValidationException', () async {
    final result = await repo.compare(professorIds: [_p1.id]);
    expect((result as Failure).error, isA<ValidationException>());
  });

  test('多于 3 位返回 ValidationException', () async {
    final result = await repo.compare(
      professorIds: [_p1.id, _p3.id, 'p_004', 'p_005'],
    );
    expect((result as Failure).error, isA<ValidationException>());
  });

  test('可加载导师不足 2 返回失败', () async {
    final result = await repo.compare(professorIds: [_p1.id, 'missing']);
    expect(result, isA<Failure>());
  });
}