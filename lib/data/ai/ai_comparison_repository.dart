import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/comparison_report.dart';
import '../../domain/entities/professor.dart';
import '../../domain/repositories/comparison_repository.dart';
import '../../domain/repositories/professor_repository.dart';

/// 用大模型对传入的 2-3 位导师做横向对比。
class AiComparisonRepository implements ComparisonRepository {
  const AiComparisonRepository({
    required this.llm,
    required this.professorRepository,
  });

  final LlmClient llm;
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
      return const Failure(ValidationException('请选择 2-3 位导师进行对比'));
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
      return const Failure(ValidationException('未能加载足够的导师信息，请返回重试'));
    }

    final orderedIds = professors.map((p) => p.id).toList();
    final result = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(professors)),
      ],
      jsonMode: true,
      temperature: 0.3,
    );

    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final data) => _parseReport(data, orderedIds, professors),
    };
  }

  Result<ComparisonReport> _parseReport(
    String data,
    List<String> ids,
    List<Professor> professors,
  ) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(ServerException());
      }

      final summary = (decoded['summary'] as String?)?.trim();
      final suggestion = (decoded['suggestion'] as String?)?.trim();
      if (summary == null ||
          summary.isEmpty ||
          suggestion == null ||
          suggestion.isEmpty) {
        return const Failure(ServerException());
      }

      final idSet = ids.toSet();
      final rows = <ComparisonRow>[];
      for (final item in decoded['rows'] as List? ?? const []) {
        if (item is! Map) continue;
        final dimension = (item['dimension'] as String?)?.trim();
        if (dimension == null || dimension.isEmpty) continue;

        final cells = <String, String>{};
        final cellsRaw = item['cells'];
        if (cellsRaw is Map) {
          for (final entry in cellsRaw.entries) {
            final key = entry.key;
            final value = entry.value;
            if (key is! String || !idSet.contains(key) || value is! String) {
              continue;
            }
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) cells[key] = trimmed;
          }
        }
        if (cells.isNotEmpty) {
          rows.add(ComparisonRow(dimension: dimension, cells: cells));
        }
      }
      if (rows.isEmpty) return const Failure(ServerException());

      return Success(
        ComparisonReport(
          professorIds: ids,
          professors: professors,
          rows: rows,
          summary: summary,
          suggestion: suggestion,
        ),
      );
    } catch (_) {
      return const Failure(ServerException());
    }
  }

  String _userPrompt(List<Professor> professors) {
    final facts = [
      for (final p in professors)
        {
          'professorId': p.id,
          'name': p.name,
          'title': p.title,
          'university': p.university,
          'college': p.college,
          'researchFields': p.researchFields,
          if (p.bio != null) 'bio': p.bio,
        },
    ];
    return '【导师列表】${jsonEncode(facts)}';
  }

  static const String _systemPrompt = '''
你是帮学生横向对比导师的助手。仅对【导师列表】中的导师评述，输出一个 JSON 对象，不要 Markdown 或多余文字：
{"rows":[{"dimension":"...","cells":{"<professorId>":"短评"}}],"summary":"...","suggestion":"..."}
规则：
1. cells 的 key 必须是【导师列表】中给出的 professorId，不得新增或编造导师。
2. 维度建议涵盖：研究方向匹配、学校与地区、职称与梯队、招生与培养（以官网为准）、适合人群。
3. 每格 1-2 句、客观中立；不得编造招生名额、联系方式等未提供的事实（用"建议向学校/导师确认"）。
4. summary 概述各导师差异；suggestion 给"若你更看重 X 则倾向 Y"的条件式建议，不下唯一武断结论。
''';
}
