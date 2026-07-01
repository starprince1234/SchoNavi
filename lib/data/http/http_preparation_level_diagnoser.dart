import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/repositories/preparation_level_diagnoser.dart';
import '../dto/api_envelope.dart';
import '../dto/level_diagnosis_dtos.dart';

/// HTTP 实现：`POST /api/v1/preparation-plans/diagnose`，请求体见 spec §3.2，
/// 用 [guardApi] + 信封解码。后端返回的 `data` 经
/// [LevelDiagnosisSuggestionDto.fromJson] 解码并校验（与 AI 路径同一套规则）。
class HttpPreparationLevelDiagnoser implements PreparationLevelDiagnoser {
  const HttpPreparationLevelDiagnoser(this._dio);

  final Dio _dio;

  @override
  Future<Result<LevelDiagnosisSuggestion>> diagnose(
    LevelDiagnosisRequest request,
  ) {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/preparation-plans/diagnose',
        data: levelDiagnosisRequestToJson(request),
      ),
      (data) =>
          LevelDiagnosisSuggestionDto.fromJson(asJsonObject(data)).toEntity(),
    );
  }
}
