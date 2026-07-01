import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/comparison_report.dart';
import '../../domain/repositories/comparison_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/comparison_dto.dart';

class HttpComparisonRepository implements ComparisonRepository {
  const HttpComparisonRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<ComparisonReport>> compare({
    required List<String> professorIds,
  }) {
    return guardApi(
      () => _dio.post<dynamic>(
        '/api/v1/professors/compare',
        data: <String, dynamic>{'professor_ids': professorIds},
      ),
      (data) => ComparisonReportDto.fromJson(asJsonObject(data)).toEntity(),
    );
  }
}
