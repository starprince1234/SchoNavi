import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/comparison_report.dart';
import '../../domain/entities/professor.dart';
import '../../domain/repositories/comparison_repository.dart';
import '../../domain/repositories/professor_repository.dart';

/// 离线兜底：按字段拼装对比表（不调用大模型）。
class MockComparisonRepository implements ComparisonRepository {
  const MockComparisonRepository({required this.professorRepository});

  final ProfessorRepository professorRepository;

  @override
  Future<Result<ComparisonReport>> compare({
    required List<String> professorIds,
  }) async {
    final ids = professorIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.length < 2 || ids.length > 3) {
      return const Failure(
        ValidationException('请选择 2-3 位导师进行对比'),
      );
    }

    final professors = <Professor>[];
    for (final id in ids) {
      switch (await professorRepository.getProfessor(id)) {
        case Success(:final data):
          professors.add(data);
        case Failure():
          break;
      }
    }

    if (professors.length < 2) {
      return const Failure(
        ValidationException('未能加载足够的导师信息，请返回重试'),
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));

    final orderedIds = professors.map((p) => p.id).toList();
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
        professorIds: orderedIds,
        professors: professors,
        rows: rows,
        summary: professors.length == 2
            ? '${professors[0].name}与${professors[1].name}的研究方向和院校背景各有侧重。'
            : '这几位导师的研究方向、院校背景和培养信息各有侧重。',
        suggestion: '建议结合你的研究兴趣、目标地区和最新招生信息做进一步确认。',
      ),
    );
  }
}
