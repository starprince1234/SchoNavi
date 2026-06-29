import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/calendar_date.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/entities/preparation_plan.dart';
import '../../domain/entities/user_profile.dart';
import '../dto/preparation_plan_dtos.dart';
import '../dto/profile_dtos.dart';

export '../dto/preparation_plan_dtos.dart'
    show
        PreparationPersonalizationRequest,
        PreparationPersonalizationResult,
        PreparationPhasePersonalization,
        PreparationOptionalTaskSuggestion;

/// 备赛计划个性化器：根据请求生成各阶段的可选任务建议与个性化建议。
///
/// 实现有两套：
/// - [AiPreparationPersonalizer]：本地 LLM 调用（jsonMode），客户端解析校验。
/// - `HttpPreparationPersonalizer`：HTTP 端点，信封解码。
///
/// 失败/未配置/超时/畸形统一返回 [Failure]（由生成器兜底标准模板）。
abstract interface class PreparationPersonalizer {
  Future<Result<PreparationPersonalizationResult>> personalize({
    required PreparationPersonalizationRequest req,
  });
}

/// 本地 LLM 实现：构造提示词约束 AI 仅返回已知 phaseKey 下的可选任务 + 建议，
/// 输出纯 JSON；解析时按 spec §7.2 校验/丢弃。
class AiPreparationPersonalizer implements PreparationPersonalizer {
  AiPreparationPersonalizer(this._llm);

  final LlmClient _llm;

  @override
  Future<Result<PreparationPersonalizationResult>> personalize({
    required PreparationPersonalizationRequest req,
  }) async {
    final result = await _llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _buildUserMessage(req)),
      ],
      jsonMode: true,
      temperature: 0.3,
    );

    // LLM 未配置 / 失败 → 透传 Failure。
    if (result is Failure<String>) return Failure(result.error);

    try {
      final content = (result as Success<String>).data;
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(ServerException());
      }
      final dto = PreparationPersonalizationResultDto.fromJson(
        decoded,
        phaseKeys: req.phaseKeys.toSet(),
      );
      return Success(dto.toEntity());
    } catch (_) {
      return const Failure(ServerException());
    }
  }

  String _buildUserMessage(PreparationPersonalizationRequest req) {
    final profileSection = _encodeProfile(req.profile);
    return '【竞赛】${jsonEncode({'id': req.competition.id, 'name': req.competition.name, 'category': req.competition.category, 'rules_summary': req.competition.rulesSummary.toJson()})}\n'
        '【时间模型】${req.timelineType.name}'
        '${req.timelineType == CompetitionTimelineType.eventWindow ? '（窗口型：比赛集中在几天）' : '（提交型：作品提交到 DDL）'}\n'
        '【目标日期】${CalendarDate.toIsoDay(req.targetDate)}\n'
        '${req.eventEndDate != null ? '【赛事窗口】${CalendarDate.toIsoDay(req.eventEndDate!)}\n' : ''}'
        '${req.defenseDate != null ? '【答辩日】${CalendarDate.toIsoDay(req.defenseDate!)}\n' : ''}'
        '【日历基准】${CalendarDate.toIsoDay(req.calendarToday)}\n'
        '【每周投入】${req.weeklyCommitment.name}'
        '（约 ${req.weeklyCommitment.hoursPerWeek} 小时/周）\n'
        '【经验等级】${req.experienceLevel.name}\n'
        '【合法阶段 key】${jsonEncode(req.phaseKeys)}\n'
        '${profileSection == null ? '' : '【学生档案】$profileSection\n'}'
        '请仅针对【合法阶段 key】中的阶段，输出该阶段的可选任务建议与个性化建议。';
  }

  String? _encodeProfile(UserProfile? p) {
    if (p == null || p.isEmpty) return null;
    return jsonEncode(UserProfileDto.fromEntity(p).toJson());
  }

  static const String _systemPrompt = '''
你是 SchoNavi 的备赛计划个性化助手。根据【竞赛】、【时间模型】、【目标日期】、【赛事窗口】、【答辩日】、【日历基准】、【每周投入】、【经验等级】、【合法阶段 key】与可选的【学生档案】，为每个合法阶段生成可选任务建议与个性化建议。
规则：
1. phases 数组中每个对象的 key 必须来自【合法阶段 key】，严禁编造其他 key。
2. 每个阶段 optionalTasks 最多 3 条；每条含 templateKey（可选）、title（必填，中文）、estimatedHours（数字，小时）。
3. templateKey 为可选；若给出，同一阶段内不得重复。
4. personalizedAdvice 用中文 1-2 句给出该阶段的个性化建议；globalAdvice 用中文给出整体建议。
5. estimatedHours 必须是正数，结合每周投入与目标日期合理估算。
6. 窗口型（eventWindow）任务不得越过【目标日期】；提交型（submission）的 defense_prep 阶段仅在【答辩日】存在时出现，且其任务应落在目标日期之后到答辩日之间。
7. 仅输出一个 JSON 对象，不要 Markdown、不要多余文字。
输出格式：
{"phases":[{"key":"proposal_writing","optionalTasks":[{"templateKey":"ai_algo","title":"强化训练","estimatedHours":10}],"personalizedAdvice":"多刷真题"}],"globalAdvice":"整体偏算法"}
''';
}
