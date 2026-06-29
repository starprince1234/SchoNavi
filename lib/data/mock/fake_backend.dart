import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'fake_chat_quick_actions_backend.dart';
import 'fake_chat_route_backend.dart';
import 'fake_preparation_backend.dart';
import 'fake_preparation_diagnose_backend.dart';

export 'fake_preparation_backend.dart' show PreparationFakeRegistration;
export 'fake_preparation_diagnose_backend.dart'
    show DiagnosisFakeRegistration;

/// Dio 层「假后端」：拦截 `/api/v1/*` 请求，按 `(method, path)` 分派到
/// 已注册的 handler，返回符合 API 信封约定的 [ResponseBody]。
///
/// 客户端代码与真后端完全一致（同一套 `HttpXxxRepository` + DTO + 信封
/// 解码），只换 transport。测试 override `dioProvider` 注入本适配器，即可
/// 在无真后端时走真实链路；未来经 config 接入可让 http 模式离线演示。
///
/// 已注册 `/chat/route`、`/chat/quick-actions` 与
/// `/preparation-plans/generate`。**未注册路径返回 404 信封**，让
/// 尚未 fake 的端点显式失败——缺口一目了然，便于后续逐步补齐端点。
class FakeBackendAdapter implements HttpClientAdapter {
  FakeBackendAdapter() : _handlers = _defaultHandlers();

  final Map<_RouteKey, Future<ResponseBody> Function(RequestOptions)> _handlers;

  /// 注册或覆盖一个端点 handler，便于扩展。
  void register(
    String method,
    String path,
    Future<ResponseBody> Function(RequestOptions options) handler,
  ) {
    _handlers[_RouteKey(method.toUpperCase(), path)] = handler;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final key = _RouteKey(options.method.toUpperCase(), options.path);
    final handler = _handlers[key];
    if (handler != null) return handler(options);
    return Future.value(_notFound(options.path));
  }

  @override
  void close({bool force = false}) {}

  static Map<_RouteKey, Future<ResponseBody> Function(RequestOptions)>
      _defaultHandlers() {
    return {
      _RouteKey('POST', '/api/v1/chat/route'): chatRouteHandler,
      _RouteKey('POST', '/api/v1/chat/quick-actions'): chatQuickActionsHandler,
      _RouteKey('POST', '/api/v1/preparation-plans/generate'):
          preparationGenerateHandler,
      _RouteKey('POST', '/api/v1/preparation-plans/diagnose'):
          preparationDiagnoseHandler,
    };
  }

  static ResponseBody _notFound(String path) {
    return ResponseBody.fromString(
      jsonEncode({
        'code': 40401,
        'message': 'fake backend: route not registered ($path)',
        'data': null,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _RouteKey {
  const _RouteKey(this.method, this.path);

  final String method;
  final String path;

  @override
  bool operator ==(Object other) =>
      other is _RouteKey && other.method == method && other.path == path;

  @override
  int get hashCode => Object.hash(method, path);
}
