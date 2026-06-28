import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../dto/api_envelope.dart';
import '../dto/preparation_plan_dtos.dart';
import '../ai/ai_preparation_personalizer.dart';

/// HTTP 实现：`POST /api/v1/preparation-plans/generate`，请求体见 spec §7.2，
/// 用 [guardApi] + 信封解码。后端返回的 `data` 经
/// [PreparationPersonalizationResultDto.fromJson] 解码并校验。
class HttpPreparationPersonalizer implements PreparationPersonalizer {
  const HttpPreparationPersonalizer(this._dio);

  final Dio _dio;

  @override
  Future<Result<PreparationPersonalizationResult>> personalize({
    required PreparationPersonalizationRequest req,
  }) {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/preparation-plans/generate',
        data: req.toJson(),
      ),
      (data) => PreparationPersonalizationResultDto.fromJson(
        asJsonObject(data),
        phaseKeys: req.phaseKeys.toSet(),
      ).toEntity(),
    );
  }
}
