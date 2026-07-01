import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/repositories/preparation_plan_assistant.dart';
import '../../domain/services/plan_change_validator.dart';
import '../dto/api_envelope.dart';
import '../dto/plan_assistant_dtos.dart';

/// HTTP 实现：`POST /api/v1/preparation-plans/{id}/assistant`，请求体见
/// spec §3.4，用 [guardApi] + 信封解码。后端返回的 `data` 经
/// [AssistantReplyDto.fromJson] 解码并经共享 `PlanChangeValidator` 校验
/// （与 AI 路径同一套规则）。`{id}` 取自 `request.planId`。
class HttpPreparationPlanAssistant implements PreparationPlanAssistant {
  const HttpPreparationPlanAssistant(this._dio);

  final Dio _dio;

  @override
  Future<Result<AssistantReply>> suggestChanges(PlanAssistantRequest request) {
    final snapshot = PlanSnapshot.fromPlan(
      request.planSnapshot,
      calendarToday: request.calendarToday,
    );
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/preparation-plans/${request.planId}/assistant',
        data: planAssistantRequestToJson(request),
      ),
      (data) =>
          AssistantReplyDto.fromJson(asJsonObject(data), snapshot).toEntity(),
    );
  }
}
