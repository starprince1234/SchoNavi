import 'dart:convert';

import '../../core/ai/llm_client.dart';
import '../../core/calendar_date.dart';
import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';
import '../../domain/repositories/preparation_plan_assistant.dart';
import '../../domain/services/plan_change_validator.dart';
import '../dto/plan_assistant_dtos.dart';

export '../../domain/repositories/preparation_plan_assistant.dart'
    show
        PlanAssistantRequest,
        AssistantReply,
        AssistantHistoryEntry,
        AssistantCardResult;

/// 本地 LLM 实现：构造 spec §5.3 提示词约束 AI 仅输出已知卡类型与快照中存在的
/// task_id/phase_key，输出纯 JSON；解析时先用 `PlanChangeSetDto.fromJson`
/// 解码（卡初始 `pending`），再用请求 `plan_snapshot` 构造 `PlanSnapshot` 并经
/// 共享 `PlanChangeValidator` 标记越界/非法卡为 `rejected`。
class AiPreparationPlanAssistant implements PreparationPlanAssistant {
  AiPreparationPlanAssistant(this._llm);

  final LlmClient _llm;

  @override
  Future<Result<AssistantReply>> suggestChanges(
    PlanAssistantRequest request,
  ) async {
    final result = await _llm.complete(
      messages: [
        const LlmMessage('system', _systemPrompt),
        LlmMessage('user', _buildUserMessage(request)),
      ],
      jsonMode: true,
      temperature: 0.3,
    );

    if (result is Failure<String>) return Failure(result.error);

    try {
      final content = (result as Success<String>).data;
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(ServerException());
      }
      final snapshot = PlanSnapshot.fromPlan(
        request.planSnapshot,
        calendarToday: request.calendarToday,
      );
      final dto = AssistantReplyDto.fromJson(decoded, snapshot);
      return Success(dto.toEntity());
    } catch (_) {
      return const Failure(ServerException());
    }
  }

  String _buildUserMessage(PlanAssistantRequest req) {
    final snapshotJson = jsonEncode(req.planSnapshot.toJson());
    final historySection = req.history.isEmpty
        ? ''
        : '\n【最近历史】${jsonEncode(req.history.map((h) => <String, dynamic>{'role': h.role, 'content': h.content}).toList())}';
    return '【日历基准】${CalendarDate.toIsoDay(req.calendarToday)}\n'
        '【计划版本】${req.basePlanRevision}\n'
        '【计划快照】$snapshotJson\n'
        '【用户消息】${req.userMessage}$historySection\n'
        '请根据计划快照、用户消息和最近历史，输出自然语言回复和最多 5 张改动卡。';
  }

  static const String _systemPrompt = '''
你是 SchoNavi 的备赛日历助手。根据计划快照、用户消息和最近历史，
输出自然语言回复和最多 5 张结构化改动卡。

规则：
1. 类型仅限 move_task|add_task|delete_task|reschedule_phase|append_advice。
2. 只能引用快照中存在的 task_id 和 phase_key。
3. 必做任务、已完成任务不可删除；已完成任务不可移动。
4. 新增任务只输出 NewTaskDraft，不输出 id 或 kind。
5. 日期必须符合时间类型和阶段的合法区间。
6. reschedule_phase 必须给出受影响阶段的完整 phase_schedule。
7. 不确定如何安全修改时使用 append_advice，或返回空 cards，不要猜测。
8. summary 描述改什么，rationale 解释为什么。
9. 仅输出 JSON，不输出 Markdown 代码块。
''';
}
