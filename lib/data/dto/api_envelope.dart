import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../core/result/result.dart';

typedef JsonDecoder<T> = T Function(Object? data);

Future<Result<T>> guardApi<T>(
  Future<Response<dynamic>> Function() request,
  JsonDecoder<T> decode,
) async {
  try {
    final response = await request();
    return Success(decodeEnvelope(response.data, decode));
  } on AppException catch (error) {
    return Failure(error);
  } on DioException catch (error) {
    return Failure(mapDioException(error));
  } catch (_) {
    return const Failure(ServerException());
  }
}

T decodeEnvelope<T>(Object? payload, JsonDecoder<T> decode) {
  if (payload is! Map) throw const ServerException();
  final json = Map<String, dynamic>.from(payload);
  final code = json['code'];
  final message = json['message']?.toString();
  if (code != 0) {
    throw ValidationException(
      message == null || message.isEmpty ? '请求失败，请稍后重试' : message,
    );
  }
  if (!json.containsKey('data')) throw const ServerException();
  try {
    return decode(json['data']);
  } catch (_) {
    throw const ServerException();
  }
}

AppException mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutException();
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const NetworkException();
    case DioExceptionType.badResponse:
      return _responseException(error.response);
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return const UnknownException();
  }
}

AppException _responseException(Response<dynamic>? response) {
  final data = response?.data;
  if (data is Map) {
    final json = Map<String, dynamic>.from(data);
    final message = json['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return ValidationException(message);
    }
  }
  final statusCode = response?.statusCode;
  if (statusCode != null) return AppException.fromStatusCode(statusCode);
  return const UnknownException();
}

Map<String, dynamic> asJsonObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException();
}

List<String> stringList(Object? value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

