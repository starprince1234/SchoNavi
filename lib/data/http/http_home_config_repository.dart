import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/home_config.dart';
import '../../domain/repositories/home_config_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/home_config_dto.dart';

class HttpHomeConfigRepository implements HomeConfigRepository {
  const HttpHomeConfigRepository(this._dio);

  final Dio _dio;

  @override
  Future<HomeConfig> fetchConfig(String mode) async {
    final result = await guardApi(
      () => _dio.get<dynamic>(
        '/api/v1/home/config',
        queryParameters: {'mode': mode},
      ),
      (data) => HomeConfigDto.fromJson(asJsonObject(data)).toEntity(),
    );
    return switch (result) {
      Success(:final data) => data,
      Failure(:final error) => throw error,
    };
  }
}
