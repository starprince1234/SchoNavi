import 'dart:convert';

import 'package:dio/dio.dart';

import 'follow_up_routing.dart';

/// 假后端对 `POST /api/v1/chat/route` 的处理：读请求体 `follow_up`，
/// 复用 [followUpNeedsRecommendations] 计算 `need`，按 API 信封约定
///（`{code,message,data}`）返回。
///
/// - `follow_up` 缺省或空 → `need:false`（对齐旧 `text.isEmpty → false`）。
/// - 忽略 `last_recommendations`（关键词语义不依赖上一轮推荐）。
/// - `options.data` 非 Map 时视为缺省 `follow_up`，返回 `need:false`。
///
/// 由 `FakeBackendAdapter` 注册，亦可被单测直接经轻量 `_FakeAdapter` 注入
/// 以精确断言请求体——同一函数两处消费，避免重复。
Future<ResponseBody> chatRouteHandler(RequestOptions options) async {
  final data = options.data;
  final followUp = data is Map<String, dynamic>
      ? options.data['follow_up']?.toString() ?? ''
      : '';
  final need = followUpNeedsRecommendations(followUp);
  return _jsonEnvelope(need: need);
}

ResponseBody _jsonEnvelope({required bool need}) {
  return ResponseBody.fromString(
    jsonEncode({
      'code': 0,
      'message': 'ok',
      'data': {'need': need},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
