import 'dart:convert';

import 'package:dio/dio.dart';

import 'fake_backend.dart';

/// 假后端对 `POST /api/v1/preparation-plans/diagnose` 的处理：忽略请求体细节，
/// 返回固定合理的水平诊断信封（intermediate 档）。
///
/// 由 [FakeBackendAdapter] 注册，亦可被单测直接经 `RequestOptions` 调用——
/// 同一函数两处消费，对齐 `preparationGenerateHandler` 模式。
Future<ResponseBody> preparationDiagnoseHandler(
  RequestOptions options,
) async {
  return ResponseBody.fromString(
    jsonEncode({
      'code': 0,
      'message': 'ok',
      'data': {
        'level': 'intermediate',
        'rationale': '根据你的参赛经历和领域熟悉度，你已具备进阶基础。',
        'suggestion': '建议按进阶档排期；时间充裕时可增加老手档训练。',
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// 在 [FakeBackendAdapter] 上注册备赛水平诊断端点的快捷扩展。
extension DiagnosisFakeRegistration on FakeBackendAdapter {
  void registerPreparationDiagnoseHandler() {
    register(
      'POST',
      '/api/v1/preparation-plans/diagnose',
      preparationDiagnoseHandler,
    );
  }
}
