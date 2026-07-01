import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/professor.dart';
import '../../domain/repositories/professor_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/professor_dto.dart';

class HttpProfessorRepository implements ProfessorRepository {
  const HttpProfessorRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<Professor>> getProfessor(String id) {
    return guardApi(
      () => _dio.get<dynamic>('/api/v1/professors/$id'),
      (data) => ProfessorDto.fromJson(asJsonObject(data)).toEntity(),
    );
  }
}
