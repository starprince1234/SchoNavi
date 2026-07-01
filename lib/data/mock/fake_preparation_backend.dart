import 'dart:convert';

import 'package:dio/dio.dart';

import 'fake_backend.dart';

/// 假后端对 `POST /api/v1/preparation-plans/generate` 的处理：忽略请求体细节，
/// 返回固定合理的个性化信封（覆盖 `comp_icpc` 的 `proposal_writing` 阶段）。
///
/// 由 [FakeBackendAdapter] 注册，亦可被单测直接经 `RequestOptions` 调用——
/// 同一函数两处消费，对齐 `chatRouteHandler` / `chatQuickActionsHandler` 模式。
Future<ResponseBody> preparationGenerateHandler(RequestOptions options) async {
  return ResponseBody.fromString(
    jsonEncode({
      'code': 0,
      'message': 'ok',
      'data': {
        'phases': [
          {
            'key': 'proposal_writing',
            'optional_tasks': [
              {
                'template_key': 'fake_mock_train',
                'title': '模拟训练',
                'estimated_hours': 8,
              },
            ],
            'personalized_advice': '建议每周固定时段训练',
          },
        ],
        'global_advice': '保持节奏，关注官网通知',
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// 在 [FakeBackendAdapter] 上注册备赛计划生成端点的快捷扩展。
extension PreparationFakeRegistration on FakeBackendAdapter {
  void registerPreparationHandler() {
    register(
      'POST',
      '/api/v1/preparation-plans/generate',
      preparationGenerateHandler,
    );
  }
}
