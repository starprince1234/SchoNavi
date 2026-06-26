import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/recommendation_result.dart';
import '../../shared/utils/quick_actions_source.dart';
import '../dto/api_envelope.dart';
import '../dto/quick_actions_dto.dart';
import '../dto/route_need_dto.dart';

/// 快捷操作的 HTTP 实现：`POST /api/v1/chat/quick-actions`。
///
/// 把请求交给后端，客户端不做关键词兜底。失败一律降级返回 [Failure]——
/// 由 [ChatNotifier] 决定是否填硬编码兜底常量（对齐 spec 降级规则）。
/// 请求体对称 `/chat/route`：`follow_up` + 可选 `last_recommendations` recap（cap 5）。
class HttpQuickActionsSource implements QuickActionsSource {
  HttpQuickActionsSource(this._dio);

  final Dio _dio;

  @override
  Future<Result<List<String>>> fetch({
    required String followUp,
    RecommendationResult? lastResult,
  }) async {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/chat/quick-actions',
        data: QuickActionsRequestDto(
          followUp: followUp,
          lastRecommendations: lastResult == null
              ? null
              : [
                  for (final r in lastResult.recommendations.take(5))
                    RecommendationRecapDto.fromEntity(r),
                ],
        ).toJson(),
      ),
      (data) =>
          QuickActionsResponseDto.fromJson(asJsonObject(data)).quickActions,
    );
  }
}
