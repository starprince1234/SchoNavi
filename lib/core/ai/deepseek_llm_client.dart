import 'package:dio/dio.dart';

import '../error/app_exception.dart';
import '../result/result.dart';
import 'llm_client.dart';

class DeepSeekLlmClient implements LlmClient {
  DeepSeekLlmClient({
    required this.dio,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  final Dio dio;
  final String apiKey;
  final String baseUrl;
  final String model;

  @override
  Future<Result<String>> complete({
    required List<LlmMessage> messages,
    bool jsonMode = false,
    double temperature = 0.7,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': Headers.jsonContentType,
          },
          responseType: ResponseType.json,
        ),
        data: {
          'model': model,
          'messages': messages.map((m) => m.toJson()).toList(),
          'temperature': temperature,
          'stream': false,
          if (jsonMode) 'response_format': {'type': 'json_object'},
        },
      );

      final choices = response.data?['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return const Failure(ServerException());
      }

      final firstChoice = choices.first;
      if (firstChoice is! Map) return const Failure(ServerException());
      final message = firstChoice['message'];
      if (message is! Map) return const Failure(ServerException());
      final content = message['content'];
      if (content is! String || content.isEmpty) {
        return const Failure(ServerException());
      }

      return Success(content);
    } on DioException catch (e) {
      return Failure(_mapDioError(e));
    } catch (_) {
      return const Failure(UnknownException());
    }
  }

  AppException _mapDioError(DioException e) {
    final code = e.response?.statusCode;
    if (code != null) return AppException.fromStatusCode(code);

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return const UnknownException();
    }
  }
}
