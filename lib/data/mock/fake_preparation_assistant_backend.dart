import 'dart:convert';

import 'package:dio/dio.dart';

import 'fake_backend.dart';

/// 假后端对 `POST /api/v1/preparation-plans/{id}/assistant` 的处理：忽略请求体
/// 细节，返回固定合理的助手回复信封（含一张 moveTask + 一张 addTask 卡，
/// 供 UI/P4a.5 渲染）。返回的卡状态均为 `pending`，由客户端共享 validator
/// 再裁定（越界卡会被标 `rejected`）。
///
/// 由 [FakeBackendAdapter] 注册，亦可被单测直接经 `RequestOptions` 调用——
/// 同一函数两处消费，对齐 `preparationDiagnoseHandler` 模式。
Future<ResponseBody> preparationAssistantHandler(
  RequestOptions options,
) async {
  // 解析请求体的 request_id 并 echo（兼容缺失：默认空串）。
  String requestId = '';
  final data = options.data;
  if (data is Map) {
    requestId = (data['request_id']?.toString()) ?? '';
  } else if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        requestId = (decoded['request_id']?.toString()) ?? '';
      }
    } catch (_) {}
  }
  return ResponseBody.fromString(
    jsonEncode({
      'code': 0,
      'message': 'ok',
      'data': {
        'request_id': requestId,
        'reply': '我整理了两项可单独确认的调整。',
        'change_set': {
          'id': 'cs_fake_1',
          'base_plan_revision': 1,
          'cards': [
            {
              'id': 'cc_fake_move',
              'type': 'move_task',
              'target_task_id': 'task_core_algo',
              'new_date': '2026-05-22',
              'summary': '把【核心算法实现】移到 5 月 22 日',
              'rationale': '避开期末考试周，同时仍早于提交 DDL。',
              'status': 'pending',
            },
            {
              'id': 'cc_fake_add',
              'type': 'add_task',
              'target_phase_key': 'defense_prep',
              'new_task': {
                'title': '第二次模拟答辩',
                'estimated_hours': 3,
                'due_date': '2026-06-05',
                'note': '记录评委追问',
              },
              'summary': '答辩准备阶段新增一次模拟答辩',
              'rationale': '在正式答辩前预留复盘时间。',
              'status': 'pending',
            },
          ],
        },
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// 在 [FakeBackendAdapter] 上注册备赛助手端点的快捷扩展。
///
/// **路径匹配约束：** [FakeBackendAdapter.fetch] 按 `(method, path)` 精确匹配，
/// 不解析 `{id}` 路径参数。因此本扩展按字面 plan id 注册：默认 `pp_1`（与
/// spec §3.4 示例一致）。测试/演示若用其他 plan id，需传入对应 `planId` 再次
/// 注册。这是当前 fake backend 的既定约束，不引入正则匹配器以保持简单。
extension AssistantFakeRegistration on FakeBackendAdapter {
  void registerPreparationAssistantHandler({String planId = 'pp_1'}) {
    register(
      'POST',
      '/api/v1/preparation-plans/$planId/assistant',
      preparationAssistantHandler,
    );
  }
}
