import 'dart:convert';

const int maxErrorResponsePreviewLength = 4096;

class ErrorDiagnostics {
  const ErrorDiagnostics({
    this.requestId,
    this.method,
    this.path,
    this.httpStatus,
    this.backendCode,
    this.backendMessage,
    this.exceptionType,
    this.cause,
    this.stackTrace,
    this.responsePreview,
    this.occurredAt,
    this.context = const {},
  });

  final String? requestId;
  final String? method;
  final String? path;
  final int? httpStatus;
  final String? backendCode;
  final String? backendMessage;
  final String? exceptionType;
  final String? cause;
  final String? stackTrace;
  final String? responsePreview;
  final DateTime? occurredAt;
  final Map<String, String> context;

  bool get isEmpty =>
      requestId == null &&
      method == null &&
      path == null &&
      httpStatus == null &&
      backendCode == null &&
      backendMessage == null &&
      exceptionType == null &&
      cause == null &&
      stackTrace == null &&
      responsePreview == null &&
      occurredAt == null &&
      context.isEmpty;

  ErrorDiagnostics copyWith({
    String? requestId,
    String? method,
    String? path,
    int? httpStatus,
    String? backendCode,
    String? backendMessage,
    String? exceptionType,
    String? cause,
    String? stackTrace,
    String? responsePreview,
    DateTime? occurredAt,
    Map<String, String>? context,
  }) => ErrorDiagnostics(
    requestId: requestId ?? this.requestId,
    method: method ?? this.method,
    path: path ?? this.path,
    httpStatus: httpStatus ?? this.httpStatus,
    backendCode: backendCode ?? this.backendCode,
    backendMessage: backendMessage ?? this.backendMessage,
    exceptionType: exceptionType ?? this.exceptionType,
    cause: cause ?? this.cause,
    stackTrace: stackTrace ?? this.stackTrace,
    responsePreview: responsePreview ?? this.responsePreview,
    occurredAt: occurredAt ?? this.occurredAt,
    context: context ?? this.context,
  );

  ErrorDiagnostics merge(ErrorDiagnostics other) => ErrorDiagnostics(
    requestId: other.requestId ?? requestId,
    method: other.method ?? method,
    path: other.path ?? path,
    httpStatus: other.httpStatus ?? httpStatus,
    backendCode: other.backendCode ?? backendCode,
    backendMessage: other.backendMessage ?? backendMessage,
    exceptionType: other.exceptionType ?? exceptionType,
    cause: other.cause ?? cause,
    stackTrace: other.stackTrace ?? stackTrace,
    responsePreview: other.responsePreview ?? responsePreview,
    occurredAt: other.occurredAt ?? occurredAt,
    context: {...context, ...other.context},
  );

  String format({required String message}) {
    final rows = <String>['错误信息: $message'];
    void add(String label, Object? value) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) rows.add('$label: $text');
    }

    add('请求 ID', requestId);
    add('请求方法', method);
    add('接口路径', path);
    add('HTTP 状态', httpStatus);
    add('业务码', backendCode);
    add('后端消息', backendMessage);
    add('异常类型', exceptionType);
    add('异常原因', cause);
    add('发生时间', occurredAt?.toIso8601String());
    for (final entry in context.entries) {
      add(entry.key, entry.value);
    }
    add('响应预览', responsePreview);
    add('堆栈', stackTrace);
    return rows.join('\n');
  }
}

String? sanitizedResponsePreview(Object? payload) {
  if (payload == null) return null;
  final sanitized = _sanitize(payload);
  final text = sanitized is String ? sanitized : jsonEncode(sanitized);
  if (text.length <= maxErrorResponsePreviewLength) return text;
  return '${text.substring(0, maxErrorResponsePreviewLength)}…（已截断）';
}

Object? _sanitize(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _isSensitiveKey(entry.key.toString())
            ? '[REDACTED]'
            : _sanitize(entry.value),
    };
  }
  if (value is Iterable) return value.map(_sanitize).toList(growable: false);
  return value;
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
  return const {
    'authorization',
    'cookie',
    'setcookie',
    'token',
    'accesstoken',
    'refreshtoken',
    'apikey',
    'password',
    'secret',
    'contact',
    'email',
    'phone',
    'wechat',
  }.contains(normalized);
}
