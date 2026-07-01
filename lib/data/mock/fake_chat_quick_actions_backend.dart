import 'dart:convert';

import 'package:dio/dio.dart';

/// 假后端对 `POST /api/v1/chat/quick-actions` 的处理：读请求体 `follow_up`
/// 与 `last_recommendations`，调纯函数 [pickQuickActionsByContext] 挑 chip，
/// 按 API 信封约定（`{code, message, data}`）返回。
///
/// - `follow_up` 缺省或空 → 通用 4 个 chip（会话开始语义）。
/// - `options.data` 非 Map 时视为空 `follow_up`，不崩。
///
/// 由 `FakeBackendAdapter` 注册，亦可被单测直接经 `RequestOptions` 调用，
/// 以精确断言请求体——同一函数两处消费，避免重复（对齐 `chatRouteHandler`）。
Future<ResponseBody> chatQuickActionsHandler(RequestOptions options) async {
  final data = options.data;
  final followUp = data is Map<String, dynamic>
      ? (data['follow_up']?.toString() ?? '')
      : '';
  final recaps = data is Map<String, dynamic>
      ? (data['last_recommendations'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  final actions = pickQuickActionsByContext(followUp, recaps);
  return _jsonEnvelope(actions);
}

/// 纯函数：按上下文挑 1-4 个短操作 chip，便于独立单测。
///
/// 关键词驱动（保证 mock 模式下 chip 也会随会话变化、而非恒定硬编码）：
/// - `followUp` 空（首轮/会话开始）→ 通用 4 个。
/// - 含「换/再推荐/相似」→ 换一批系。
/// - 含「只看/地区名（北京/上海…）」→ 筛选系。
/// - 否则 → 通用 4 个兜底（含上一轮方向时仍可用）。
List<String> pickQuickActionsByContext(
  String followUp,
  List<Map<String, dynamic>> recaps,
) {
  final text = followUp.trim();

  if (text.isEmpty) {
    return const ['换一批', '偏应用', '只看985', '适合硕士'];
  }

  if (RegExp(r'换|再推荐|相似|类似的导师').hasMatch(text)) {
    return const ['换一批', '相似导师', '只看985', '偏应用'];
  }

  if (RegExp(r'只看|北京|上海|江浙|广州|深圳').hasMatch(text)) {
    // 若有上一轮推荐且含地区，提炼「只看<地区>」；否则通用筛选。
    final location = _firstLocation(recaps);
    return location == null
        ? const ['只看北京', '只看985', '换一批', '偏应用']
        : ['只看$location', '只看985', '换一批', '偏应用'];
  }

  // 默认：方向相关 + 通用。
  return const ['偏应用', '偏理论', '换一批', '适合硕士'];
}

String? _firstLocation(List<Map<String, dynamic>> recaps) {
  for (final r in recaps) {
    final uni = r['university']?.toString() ?? '';
    if (uni.contains('北京')) return '北京';
    if (uni.contains('上海')) return '上海';
  }
  return null;
}

ResponseBody _jsonEnvelope(List<String> actions) {
  return ResponseBody.fromString(
    jsonEncode({
      'code': 0,
      'message': 'ok',
      'data': {'quick_actions': actions},
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
