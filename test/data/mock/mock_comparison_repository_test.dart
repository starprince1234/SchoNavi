import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/result/result.dart';
import 'package:scho_navi/data/mock/mock_comparison_repository.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';
import 'package:scho_navi/domain/entities/professor.dart';

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

void main() {
  test('rows 含关键维度，每位导师均有单元格', () async {
    final result = await MockComparisonRepository().compare(
      professors: [_p1, _p3],
    );
    final report = (result as Success<ComparisonReport>).data;

    expect(report.professorIds, ['p_001', 'p_003']);
    expect(report.rows.map((row) => row.dimension), contains('研究方向'));
    for (final row in report.rows) {
      expect(row.cells.containsKey('p_001'), isTrue);
      expect(row.cells.containsKey('p_003'), isTrue);
    }
    expect(report.summary, isNotEmpty);
    expect(report.suggestion, isNotEmpty);
  });
}
