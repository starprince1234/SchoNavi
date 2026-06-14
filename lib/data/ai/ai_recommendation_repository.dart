import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/match_level.dart';
import '../../domain/entities/professor.dart';
import '../../domain/entities/query_understanding.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/recommendation_repository.dart';
import 'professor_candidate_source.dart';

class AiRecommendationRepository implements RecommendationRepository {
  AiRecommendationRepository({
    required this.llm,
    required this.candidates,
  });

  final LlmClient llm;
  final ProfessorCandidateSource candidates;

  @override
  Future<Result<RecommendationResult>> getRecommendations({
    required String prompt,
    UserProfile? profile,
    String? sessionId,
  }) async {
    final pool = candidates.candidatesFor(prompt);
    final profileSection = _encodeProfile(profile);
    final res = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage(
          'user',
          '【用户需求】$prompt\n'
              '${profileSection == null ? '' : '【学生档案】$profileSection\n'}'
              '【候选导师】${_encode(pool)}',
        ),
      ],
      jsonMode: true,
      temperature: 0.3,
    );

    if (res is Failure<String>) return Failure(res.error);

    try {
      return Success(
        _parse(
          (res as Success<String>).data,
          pool,
          sessionId ?? 's_${prompt.hashCode.toUnsigned(20)}',
        ),
      );
    } catch (_) {
      return const Failure(ServerException());
    }
  }

  String _encode(List<Professor> pool) {
    return jsonEncode([
      for (final p in pool)
        {
          'id': p.id,
          'name': p.name,
          'university': p.university,
          'college': p.college,
          'title': p.title,
          'researchFields': p.researchFields,
          if (p.bio != null) 'bio': p.bio,
        },
    ]);
  }

  /// 把档案压成紧凑 JSON；空档案返回 null（不注入）。
  String? _encodeProfile(UserProfile? p) {
    if (p == null || p.isEmpty) return null;
    return jsonEncode({
      if (p.gender != null) 'gender': p.gender!.name,
      if (p.degreeStage != null) 'degreeStage': p.degreeStage,
      if (p.targetDegree != null) 'targetDegree': p.targetDegree,
      if (p.school != null) 'school': p.school,
      if (p.major != null) 'major': p.major,
      if (p.score != null && !p.score!.isEmpty)
        'score': {
          if (p.score!.gpa != null) 'gpa': p.score!.gpa,
          if (p.score!.scale != null) 'scale': p.score!.scale,
          if (p.score!.rank != null) 'rank': p.score!.rank,
        },
      if (p.researchInterests.isNotEmpty)
        'researchInterests': p.researchInterests,
      if (p.competitions.isNotEmpty)
        'competitions': [for (final c in p.competitions) c.toJson()],
      if (p.research.isNotEmpty)
        'research': [for (final r in p.research) r.toJson()],
      if (p.highlights != null) 'highlights': p.highlights,
    });
  }

  RecommendationResult _parse(
    String content,
    List<Professor> pool,
    String sessionId,
  ) {
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final byId = {for (final p in pool) p.id: p};
    final queryUnderstanding =
        decoded['queryUnderstanding'] as Map<String, dynamic>? ?? const {};

    return RecommendationResult(
      sessionId: sessionId,
      queryUnderstanding: QueryUnderstanding(
        researchInterests: _strings(queryUnderstanding['researchInterests']),
        preferredLocations: _strings(queryUnderstanding['preferredLocations']),
        preferredUniversities: _strings(
          queryUnderstanding['preferredUniversities'],
        ),
        degreeStage: _nullableString(queryUnderstanding['degreeStage']),
        uncertainties: _strings(queryUnderstanding['uncertainties']),
      ),
      recommendations: _recommendations(decoded['recommendations'], byId),
      followUpQuestions: _strings(decoded['followUpQuestions']),
    );
  }

  List<Recommendation> _recommendations(
    Object? value,
    Map<String, Professor> byId,
  ) {
    final items = value as List? ?? const [];
    final recs = <Recommendation>[];

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final professorId = item['professorId'] as String?;
      final p = professorId == null ? null : byId[professorId];
      if (p == null) continue;

      final reason = (item['reason'] as String?)?.trim();
      if (reason == null || reason.isEmpty) continue;
      recs.add(
        Recommendation(
          professorId: p.id,
          name: p.name,
          university: p.university,
          college: p.college,
          title: p.title,
          researchFields: p.researchFields,
          homepageUrl: p.homepageUrl,
          matchLevel: _matchLevel(item['matchLevel'] as String?),
          reason: reason,
          limitations: _strings(item['limitations']),
        ),
      );
    }

    return recs;
  }

  List<String> _strings(Object? value) {
    return (value as List?)?.map((item) => item.toString()).toList() ??
        const [];
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  MatchLevel _matchLevel(String? value) {
    return switch (value) {
      'high' => MatchLevel.high,
      'low' => MatchLevel.low,
      _ => MatchLevel.medium,
    };
  }

  static const String _systemPrompt = '''
你是 SchoNavi 的导师推荐助手。根据【用户需求】，从【候选导师】中筛选并排序最匹配的导师。
规则：
1. 只能推荐【候选导师】中出现的导师，用其 id 作为 professorId 引用；严禁编造导师、学校或事实。
2. 仅输出一个 JSON 对象，不要 Markdown、不要多余文字。
3. reason：用中文 2-3 句具体说明匹配点（研究方向/学校/地区/阶段）。
4. limitations：只写诚实、通用的注意事项，如“招生信息以学校官网为准”，不要编造具体数字或事实。
5. matchLevel 取值 high、medium、low 之一。
6. queryUnderstanding：抽取研究兴趣/地区/学校/阶段；degreeStage 取“硕士”“博士”或 null；uncertainties 写未明确处。地区可据学校常识推断。
7. followUpQuestions：1-3 个细化推荐的中文追问。
8. 若提供【学生档案】，请结合其研究兴趣/成绩/竞赛/科研背景调整排序，并在 reason 中适当引用学生背景与导师的契合点；但仍只引用候选导师事实、不得编造。
9. 候选中无相关导师时 recommendations 用空数组。
输出格式：
{"queryUnderstanding":{"researchInterests":["医学影像"],"preferredLocations":["上海"],"preferredUniversities":[],"degreeStage":"硕士","uncertainties":["未明确偏理论或应用"]},"recommendations":[{"professorId":"p_001","matchLevel":"high","reason":"……","limitations":["……"]}],"followUpQuestions":["……"]}
''';
}
