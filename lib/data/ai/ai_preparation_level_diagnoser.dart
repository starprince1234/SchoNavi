import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/preparation_level_diagnoser.dart';
import '../dto/level_diagnosis_dtos.dart';
import '../dto/profile_dtos.dart';

export '../../domain/repositories/preparation_level_diagnoser.dart'
    show LevelDiagnosisRequest, LevelDiagnosisSuggestion, DiagnosisAnswer;

/// 本地 LLM 实现：构造 spec §5.1 提示词约束 AI 仅返回 beginner|intermediate|
/// experienced 三档及理由与排期建议，输出纯 JSON；解析时按 §5.1 校验/丢弃。
class AiPreparationLevelDiagnoser implements PreparationLevelDiagnoser {
  AiPreparationLevelDiagnoser(this._llm);

  final LlmClient _llm;

  @override
  Future<Result<LevelDiagnosisSuggestion>> diagnose(
    LevelDiagnosisRequest request,
  ) async {
    final result = await _llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _buildUserMessage(request)),
      ],
      jsonMode: true,
      temperature: 0.2,
    );

    if (result is Failure<String>) return Failure(result.error);

    try {
      final content = (result as Success<String>).data;
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(ServerException());
      }
      final dto = LevelDiagnosisSuggestionDto.fromJson(decoded);
      return Success(dto.toEntity());
    } catch (_) {
      return const Failure(ServerException());
    }
  }

  String _buildUserMessage(LevelDiagnosisRequest req) {
    final profileSection = _encodeProfile(req.profile);
    return '【竞赛】${jsonEncode(req.competition.toJson())}\n'
        '【问答答案】${jsonEncode(req.answers.map((a) => {'question_key': a.questionKey, 'answer': a.answer}).toList())}\n'
        '${profileSection == null ? '' : '【学生档案】$profileSection\n'}'
        '请根据以上信息判断用户在该类赛事上的经验等级。';
  }

  String? _encodeProfile(UserProfile? p) {
    if (p == null || p.isEmpty) return null;
    return jsonEncode(UserProfileDto.fromEntity(p).toJson());
  }

  static const String _systemPrompt = '''
你是 SchoNavi 的备赛水平诊断助手。根据竞赛类目、用户档案和两个问答答案，
判断用户在该类赛事上的经验等级，并给出简短、可解释的理由与排期建议。

规则：
1. level 仅限 beginner|intermediate|experienced。
2. rationale 用中文 1–2 句，只引用输入中存在的事实。
3. suggestion 给出与档位对应的排期建议。
4. 不得声称用户获得过输入中未提供的奖项。
5. 仅输出 JSON：{"level":"...","rationale":"...","suggestion":"..."}
''';
}
