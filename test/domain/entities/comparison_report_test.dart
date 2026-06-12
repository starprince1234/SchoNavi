import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/domain/entities/comparison_report.dart';

void main() {
  test('ComparisonReport 保留列顺序与行数据', () {
    const report = ComparisonReport(
      professorIds: ['p_001', 'p_003'],
      rows: [
        ComparisonRow(
          dimension: '研究方向',
          cells: {'p_001': '医学影像', 'p_003': '自动驾驶'},
        ),
      ],
      summary: '两位方向差异明显。',
      suggestion: '若看重医学影像可优先 p_001。',
    );

    expect(report.professorIds, ['p_001', 'p_003']);
    expect(report.rows.single.dimension, '研究方向');
    expect(report.rows.single.cells['p_003'], '自动驾驶');
    expect(report.summary, isNotEmpty);
    expect(report.suggestion, isNotEmpty);
  });
}
