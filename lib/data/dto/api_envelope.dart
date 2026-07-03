import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../core/error/error_diagnostics.dart';
import '../../core/result/result.dart';

typedef JsonDecoder<T> = T Function(Object? data);

Future<Result<T>> guardApi<T>(
  Future<Response<dynamic>> Function() request,
  JsonDecoder<T> decode,
) async {
  Response<dynamic>? response;
  try {
    response = await request();
    return Success(decodeEnvelope(response.data, decode));
  } on AppException catch (error) {
    final details = response == null ? null : _responseDiagnostics(response);
    return Failure(details == null ? error : error.withDiagnostics(details));
  } on DioException catch (error) {
    return Failure(mapDioException(error));
  } catch (error, stackTrace) {
    final details = ErrorDiagnostics(
      exceptionType: error.runtimeType.toString(),
      cause: error.toString(),
      stackTrace: stackTrace.toString(),
      occurredAt: DateTime.now(),
    );
    return Failure(UnknownException(diagnostics: details));
  }
}

T decodeEnvelope<T>(Object? payload, JsonDecoder<T> decode) {
  if (payload is! Map) {
    throw ServerException(
      message: '服务返回格式异常',
      diagnostics: ErrorDiagnostics(
        exceptionType: 'ApiEnvelopeFormatException',
        cause: '响应不是 JSON 对象',
        responsePreview: sanitizedResponsePreview(payload),
        occurredAt: DateTime.now(),
      ),
    );
  }
  final json = Map<String, dynamic>.from(payload);
  final code = json['code'];
  final message = json['message']?.toString();
  if (code != 0) {
    throw ValidationException(
      message == null || message.isEmpty ? '请求失败，请稍后重试' : message,
      diagnostics: ErrorDiagnostics(
        backendCode: code?.toString(),
        backendMessage: message,
        exceptionType: 'ApiBusinessException',
        responsePreview: sanitizedResponsePreview(payload),
        occurredAt: DateTime.now(),
      ),
    );
  }
  if (!json.containsKey('data')) {
    throw ServerException(
      message: '服务返回格式异常',
      diagnostics: ErrorDiagnostics(
        exceptionType: 'ApiEnvelopeFormatException',
        cause: '成功信封缺少 data 字段',
        responsePreview: sanitizedResponsePreview(payload),
        occurredAt: DateTime.now(),
      ),
    );
  }
  try {
    return decode(json['data']);
  } on AppException {
    rethrow;
  } catch (error, stackTrace) {
    throw ServerException(
      message: '服务返回格式异常',
      diagnostics: ErrorDiagnostics(
        exceptionType: error.runtimeType.toString(),
        cause: error.toString(),
        stackTrace: stackTrace.toString(),
        responsePreview: sanitizedResponsePreview(payload),
        occurredAt: DateTime.now(),
      ),
    );
  }
}

AppException mapDioException(DioException error) {
  final details = _dioDiagnostics(error);
  final underlying = error.error;
  if (underlying is AppException) return underlying.withDiagnostics(details);
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return TimeoutException(diagnostics: details);
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return NetworkException(diagnostics: details);
    case DioExceptionType.badResponse:
      return _responseException(error.response, details);
    case DioExceptionType.cancel:
    case DioExceptionType.unknown:
      return UnknownException(diagnostics: details);
  }
}

AppException _responseException(
  Response<dynamic>? response,
  ErrorDiagnostics details,
) {
  final data = response?.data;
  String? message;
  if (data is Map) {
    final json = Map<String, dynamic>.from(data);
    message = json['message']?.toString();
  }
  final statusCode = response?.statusCode;
  if (statusCode == 422) {
    return ValidationException(
      message == null || message.isEmpty ? '输入内容校验失败' : message,
      diagnostics: details,
    );
  }
  if (statusCode != null) {
    return AppException.fromStatusCode(
      statusCode,
      message: message == null || message.isEmpty ? null : message,
      diagnostics: details,
    );
  }
  return UnknownException(diagnostics: details);
}

ErrorDiagnostics _dioDiagnostics(DioException error) {
  final response = error.response;
  final request = error.requestOptions;
  final responseDetails = response == null
      ? null
      : _responseDiagnostics(response);
  final fallback = ErrorDiagnostics(
    requestId: _requestId(response, request),
    method: request.method,
    path: request.uri.path,
    httpStatus: response?.statusCode,
    backendCode: _backendField(response?.data, 'code'),
    backendMessage: _backendField(response?.data, 'message'),
    exceptionType: error.type.name,
    cause: error.error?.toString() ?? error.message,
    responsePreview: sanitizedResponsePreview(response?.data),
    occurredAt: DateTime.now(),
  );
  return responseDetails?.merge(fallback) ?? fallback;
}

ErrorDiagnostics _responseDiagnostics(Response<dynamic> response) {
  final request = response.requestOptions;
  return ErrorDiagnostics(
    requestId: _requestId(response, request),
    method: request.method,
    path: request.uri.path,
    httpStatus: response.statusCode,
    backendCode: _backendField(response.data, 'code'),
    backendMessage: _backendField(response.data, 'message'),
    responsePreview: sanitizedResponsePreview(response.data),
    occurredAt: DateTime.now(),
  );
}

String? _requestId(Response<dynamic>? response, RequestOptions request) {
  final echoed = response?.headers.value('x-request-id');
  if (echoed != null && echoed.isNotEmpty) return echoed;
  final header = request.headers.entries
      .where((entry) => entry.key.toLowerCase() == 'x-request-id')
      .map((entry) => entry.value?.toString())
      .firstOrNull;
  return header == null || header.isEmpty ? null : header;
}

String? _backendField(Object? data, String key) {
  if (data is! Map || !data.containsKey(key)) return null;
  return data[key]?.toString();
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
