import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/competition.dart';
import '../../domain/entities/research_item.dart';
import '../../domain/repositories/profile_extraction_repository.dart';

/// 用大模型把学生自述抽取为结构化成果条目（接地、不编造）。
class AiProfileExtractionRepository implements ProfileExtractionRepository {
  const AiProfileExtractionRepository(this.llm);

  final LlmClient llm;

  @override
  Future<Result<AchievementDraft>> extract({required String rawText}) async {
    final result = await llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', '【学生自述】$rawText'),
      ],
      jsonMode: true,
      temperature: 0.2,
    );

    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final data) => _parse(data),
    };
  }

  Result<AchievementDraft> _parse(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(ServerException());
      }
      return Success(
        AchievementDraft(
          competitions: _competitions(decoded['competitions']),
          research: _research(decoded['research']),
        ),
      );
    } catch (_) {
      return const Failure(ServerException());
    }
  }

  List<Competition> _competitions(Object? value) {
    final list = value as List? ?? const [];
    final out = <Competition>[];
    for (final item in list) {
      if (item is! Map) continue;
      final c = Competition.fromJson(Map<String, dynamic>.from(item));
      if (c.name.isEmpty) continue; // 缺名丢弃
      out.add(c);
    }
    return out;
  }

  List<ResearchItem> _research(Object? value) {
    final list = value as List? ?? const [];
    final out = <ResearchItem>[];
    for (final item in list) {
      if (item is! Map) continue;
      final r = ResearchItem.fromJson(Map<String, dynamic>.from(item));
      if (r.title.isEmpty) continue; // 缺标题丢弃
      out.add(r);
    }
    return out;
  }

  static const String _systemPrompt = '''
你是把学生自述整理为结构化成果的助手。仅依据【学生自述】抽取，**不得编造**未提及的奖项、论文、项目。只输出一个 JSON 对象，不要 Markdown 或多余文字：
{"competitions":[{"name":"","level":"","award":"","year":""}],"research":[{"type":"paper","title":"","role":"","venueOrStatus":"","year":""}]}
规则：
1. competitions.name、research.title 为必填；无法确定名称/标题的条目直接省略。
2. level 归一为：国际 / 国家级 / 省级 / 校级 之一，拿不准留空字符串。
3. research.type 取 paper / project / patent / other 之一（论文=paper，项目=project，专利=patent）。
4. 其余字段（award/year/role/venueOrStatus）拿不准留空字符串，不要臆测。
5. 自述中没有成果时，两个数组都为空。
''';
}
