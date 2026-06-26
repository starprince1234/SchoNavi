import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/mock/fake_backend.dart';
import 'package:scho_navi/data/mock/fake_chat_quick_actions_backend.dart';

void main() {
  group('pickQuickActionsByContext', () {
    test('followUp 空 → 返回通用 4 个 chip', () {
      final actions = pickQuickActionsByContext('', const []);
      expect(actions, hasLength(4));
      expect(actions, containsAll(['换一批', '偏应用', '只看985', '适合硕士']));
    });

    test('含「换一批/再推荐」→ 返回换一批系', () {
      final actions = pickQuickActionsByContext('换一批导师', const []);
      expect(actions.first, '换一批');
      expect(actions, contains('相似导师'));
    });

    test('含「只看/北京」→ 返回筛选系', () {
      final actions = pickQuickActionsByContext('只看北京', const []);
      expect(actions, contains('只看北京'));
      expect(actions, contains('只看985'));
    });

    test('recaps 非空时优先返回方向相关 chip', () {
      final recaps = <Map<String, dynamic>>[
        const {
          'professor_id': 'p_001',
          'name': '张三',
          'university': '清华大学',
          'research_fields': ['计算机视觉', '医学影像'],
        },
      ];
      final actions = pickQuickActionsByContext('详情', recaps);
      expect(actions, contains('偏应用'));
      expect(actions, contains('偏理论'));
    });
  });

  group('chatQuickActionsHandler', () {
    test('返回信封 {code:0, message:ok, data:{quick_actions:[...]}}', () async {
      final body = await chatQuickActionsHandler(_post({'follow_up': '换一批'}));
      final json = await _decode(body);

      expect(json['code'], 0);
      expect(json['message'], 'ok');
      expect((json['data'] as Map)['quick_actions'], isA<List>());
    });

    test('follow_up 缺省视为空，返回通用 chip', () async {
      final body = await chatQuickActionsHandler(_post(<String, dynamic>{}));
      final json = await _decode(body);
      expect(((json['data'] as Map)['quick_actions'] as List), hasLength(4));
    });

    test('非 Map 请求体按空 followUp 处理', () async {
      final body = await chatQuickActionsHandler(_post('not-a-map'));
      final json = await _decode(body);
      expect(((json['data'] as Map)['quick_actions'] as List), hasLength(4));
    });
  });

  group('FakeBackendAdapter', () {
    test('把 POST /api/v1/chat/quick-actions 分派到 handler', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = FakeBackendAdapter();

      final res = await dio.post<dynamic>(
        '/api/v1/chat/quick-actions',
        data: {'follow_up': '换一批'},
      );
      expect(res.data['code'], 0);
      expect((res.data['data'] as Map)['quick_actions'], isA<List>());
    });
  });
}

RequestOptions _post(Object? data) {
  return RequestOptions(
    path: '/api/v1/chat/quick-actions',
    method: 'POST',
    data: data,
  );
}

Future<Map<String, dynamic>> _decode(ResponseBody body) async {
  final bytes = <int>[];
  await for (final chunk in body.stream) {
    bytes.addAll(chunk);
  }
  return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}
