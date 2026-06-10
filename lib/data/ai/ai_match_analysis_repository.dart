import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/match_analysis.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/match_analysis_repository.dart';

/// 用大模型据【导师】+【学生背景】生成接地匹配分析 JSON。
class AiMatchAnalysisRepository implements MatchAnalysisRepository {
  const AiMatchAnalysisRepository(this.llm);

  final LlmClient llm;

  @override
  Future<Result<MatchAnalysis>> analyze({
    required Professor professor,
    required UserProfile profile,
  }) async {
    final result = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _userPrompt(professor, profile)),
      ],
      jsonMode: true,
      temperature: 0.4,
    );

    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final data) => _parseAnalysis(data, professor.id),
    };
  }

  Result<MatchAnalysis> _parseAnalysis(String data, String professorId) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(ServerException());
      }

      final summary = (decoded['summary'] as String?)?.trim();
      if (summary == null || summary.isEmpty) {
        return const Failure(ServerException());
      }

      return Success(
        MatchAnalysis(
          professorId: professorId,
          summary: summary,
          strengths: _strings(decoded['strengths']),
          gaps: _strings(decoded['gaps']),
          suggestions: _strings(decoded['suggestions']),
          dimensions: _dimensions(decoded['dimensions']),
        ),
      );
    } catch (_) {
      return const Failure(ServerException());
    }
  }

  List<String> _strings(Object? value) => (value as List? ?? const [])
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();

  static const List<String> _axes = [
    '方向契合',
    '方法匹配',
    '地域',
    '学历目标',
    '产出活跃',
  ];

  List<MatchDimension> _dimensions(Object? value) {
    final list = value as List? ?? const [];
    final parsed = <String, MatchDimension>{};
    for (final item in list) {
      if (item is! Map) continue;
      final label = (item['label'] as String?)?.trim();
      if (label == null || label.isEmpty) continue;
      final raw = item['score'];
      final n = raw is num ? raw.round() : int.tryParse('$raw') ?? 0;
      final score = n.clamp(0, 100).toInt();
      final comment = (item['comment'] as String?)?.trim() ?? '';
      parsed[label] = MatchDimension(
        label: label,
        score: score,
        comment: comment,
      );
    }
    if (parsed.isEmpty) return const [];
    return [
      for (final axis in _axes)
        parsed[axis] ??
            MatchDimension(label: axis, score: 0, comment: '信息不足'),
    ];
  }

  String _userPrompt(Professor professor, UserProfile profile) {
    final professorFacts = <String, Object?>{
      'name': professor.name,
      'title': professor.title,
      'university': professor.university,
      'college': professor.college,
      'researchFields': professor.researchFields,
      if (professor.bio != null) 'bio': professor.bio,
    };
    final studentFacts = <String, Object?>{
      if (profile.name != null) 'name': profile.name,
      if (profile.degreeStage != null) 'degreeStage': profile.degreeStage,
      if (profile.school != null) 'school': profile.school,
      if (profile.major != null) 'major': profile.major,
      if (profile.researchInterests.isNotEmpty)
        'researchInterests': profile.researchInterests,
      if (profile.highlights != null) 'highlights': profile.highlights,
    };
    return '【导师】${jsonEncode(professorFacts)}\n'
        '【学生背景】${jsonEncode(studentFacts)}';
  }

  static const String _systemPrompt = '''
你是帮学生做"导师-背景匹配分析"的助手。根据【导师】与【学生背景】输出一个 JSON 对象，不要 Markdown 或多余文字：
{"summary":"...","strengths":["..."],"gaps":["..."],"suggestions":["..."],"dimensions":[{"label":"方向契合","score":0,"comment":"..."},{"label":"方法匹配","score":0,"comment":"..."},{"label":"地域","score":0,"comment":"..."},{"label":"学历目标","score":0,"comment":"..."},{"label":"产出活跃","score":0,"comment":"..."}]}
规则：
1. strengths：学生与该导师方向或要求的契合点，只基于已提供信息。
2. gaps：可能的短板；信息缺失则写"建议补充X"，不臆测学生未提供的经历。
3. suggestions：具体可执行的准备，如补哪类基础、读哪方向论文、准备什么材料。
4. summary：客观概述匹配情况，严禁给出录取概率或"一定能/不能"的结论。
5. dimensions：必须且仅含上面 5 个 label（顺序不限），score 为 0-100 的"信息性契合度"（非录取概率），comment 为该维度一句话接地解读；信息不足的维度给较低分并在 comment 说明需补充什么。
6. 不得编造导师或学生未提供的任何事实。
''';
}
