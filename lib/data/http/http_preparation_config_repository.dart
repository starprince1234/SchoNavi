import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/preparation_config.dart';
import '../../domain/repositories/preparation_config_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/preparation_config_dto.dart';

class HttpPreparationConfigRepository implements PreparationConfigRepository {
  const HttpPreparationConfigRepository(this._dio);

  final Dio _dio;

  @override
  Future<PreparationConfig> fetch() async {
    final result = await guardApi(
      () => _dio.get<dynamic>('/api/v1/preparation/config'),
      (data) => PreparationConfigDto.fromJson(asJsonObject(data)).toEntity(),
    );
    return switch (result) {
      Success(:final data) => data,
      Failure(:final error) => throw error,
    };
  }
}
