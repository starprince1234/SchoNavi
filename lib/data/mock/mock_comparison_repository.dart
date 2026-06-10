import '../../core/result/result.dart';
import '../../domain/entities/comparison_report.dart';
import '../../domain/entities/professor.dart';
import '../../domain/repositories/comparison_repository.dart';

/// 离线兜底：按字段拼装对比表（不调用大模型）。
class MockComparisonRepository implements ComparisonRepository {
  @override
  Future<Result<ComparisonReport>> compare({
    required List<Professor> professors,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final ids = professors.map((p) => p.id).toList();
    Map<String, String> cell(String Function(Professor p) value) => {
      for (final p in professors) p.id: value(p),
    };

    final rows = [
      ComparisonRow(
        dimension: '研究方向',
        cells: cell(
          (p) => p.researchFields.isEmpty
              ? '公开资料未明确'
              : p.researchFields.join('、'),
        ),
      ),
      ComparisonRow(
        dimension: '学校与地区',
        cells: cell((p) => '${p.university} / ${p.college}'),
      ),
      ComparisonRow(
        dimension: '职称与梯队',
        cells: cell((p) => p.title),
      ),
      ComparisonRow(
        dimension: '招生与培养',
        cells: cell((_) => '建议以学校官网与导师主页最新说明为准'),
      ),
      ComparisonRow(
        dimension: '适合人群',
        cells: cell(
          (p) => p.researchFields.isEmpty
              ? '适合希望进一步核实研究方向的同学'
              : '适合关注${p.researchFields.first}方向的同学',
        ),
      ),
    ];

    return Success(
      ComparisonReport(
        professorIds: ids,
        rows: rows,
        summary: professors.length == 2
            ? '${professors[0].name}与${professors[1].name}的研究方向和院校背景各有侧重。'
            : '这几位导师的研究方向、院校背景和培养信息各有侧重。',
        suggestion: '建议结合你的研究兴趣、目标地区和最新招生信息做进一步确认。',
      ),
    );
  }
}
