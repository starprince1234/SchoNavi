import 'package:dio/dio.dart';

import '../../domain/entities/home_prompt.dart';
import '../../domain/repositories/home_prompt_repository.dart';

/// HTTP implementation of [HomePromptRepository].
///
/// Calls `GET /api/v1/home/prompts?mode={mode}` and expects a JSON array of
/// objects shaped like `{ "text": "..." }`.
///
/// In the current build this request is intended to be intercepted by a mock
/// adapter, but the repository itself is backend-ready.
class HttpHomePromptRepository implements HomePromptRepository {
  const HttpHomePromptRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<HomePrompt>> fetchPrompts(String mode) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/home/prompts',
      queryParameters: {'mode': mode},
    );

    final data = response.data;
    if (data == null) return const [];
    return data.cast<Map<String, dynamic>>().map(HomePrompt.fromJson).toList();
  }
}

