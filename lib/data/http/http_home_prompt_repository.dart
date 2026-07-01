import 'package:dio/dio.dart';

import '../../core/result/result.dart';
import '../../domain/entities/home_prompt.dart';
import '../../domain/repositories/home_prompt_repository.dart';
import '../dto/api_envelope.dart';
import '../dto/home_prompt_dto.dart';

/// HTTP implementation of [HomePromptRepository].
///
/// Calls `GET /api/v1/home/prompts?mode={mode}` and expects an envelope whose
/// data is a JSON array of objects shaped like `{ "text": "..." }`.
class HttpHomePromptRepository implements HomePromptRepository {
  const HttpHomePromptRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<HomePrompt>> fetchPrompts(String mode) async {
    final result = await guardApi(
      () => _dio.get<dynamic>(
        '/api/v1/home/prompts',
        queryParameters: {'mode': mode},
      ),
      (data) => (data as List<dynamic>? ?? const <dynamic>[])
          .map((item) => HomePromptDto.fromJson(asJsonObject(item)).toEntity())
          .toList(growable: false),
    );

    return switch (result) {
      Success(:final data) => data,
      Failure() => const <HomePrompt>[],
    };
  }
}
