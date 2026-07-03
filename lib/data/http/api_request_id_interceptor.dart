import 'package:dio/dio.dart';

import '../../core/ids/uuid_v7.dart';

const apiRequestIdHeader = 'X-Request-ID';

class ApiRequestIdInterceptor extends Interceptor {
  ApiRequestIdInterceptor({UuidV7? ids}) : _ids = ids ?? UuidV7();

  final UuidV7 _ids;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final current = _header(options.headers, apiRequestIdHeader);
    final idempotencyKey = _header(options.headers, 'Idempotency-Key');
    options.headers[apiRequestIdHeader] =
        current ?? idempotencyKey ?? _ids.generate();
    handler.next(options);
  }
}

String? _header(Map<String, dynamic> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() != name.toLowerCase()) continue;
    final value = entry.value?.toString();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
