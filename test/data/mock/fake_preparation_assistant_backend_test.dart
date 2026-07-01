import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/mock/fake_preparation_assistant_backend.dart';

RequestOptions _req(Map<String, dynamic> body) => RequestOptions(
  path: '/api/v1/preparation-plans/pp_1/assistant',
  method: 'POST',
  data: body,
  baseUrl: 'https://fake.local',
);

void main() {
  test('echo 请求的 request_id', () async {
    final resp = await preparationAssistantHandler(
      _req({
        'request_id': 'req_echo_1',
        'calendar_today': '2026-05-01',
        'base_plan_revision': 1,
        'plan_snapshot': {'id': 'pp_1', 'revision': 1},
        'user_message': '问',
      }),
    );
    final body = await resp.stream.toList();
    final json = jsonDecode(utf8.decode(body[0])) as Map<String, dynamic>;
    expect(json['data']['request_id'], 'req_echo_1');
  });
}
