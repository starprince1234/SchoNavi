import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/data/mock/fake_backend.dart';
import 'package:scho_navi/data/mock/fake_chat_route_backend.dart';
import 'package:scho_navi/data/mock/follow_up_routing.dart';

void main() {
  group('followUpNeedsRecommendations (relocated keyword logic)', () {
    test('明确要求重新筛选时产卡', () {
      expect(followUpNeedsRecommendations('只看上海的导师'), isTrue);
      expect(followUpNeedsRecommendations('再推荐几位相似的导师'), isTrue);
      expect(followUpNeedsRecommendations('换一批'), isTrue);
    });

    test('针对已有导师的解释性问题不产卡', () {
      expect(followUpNeedsRecommendations('第一位导师在北京吗？'), isFalse);
      expect(followUpNeedsRecommendations('他的研究方向是什么？'), isFalse);
      expect(followUpNeedsRecommendations('为什么推荐他？'), isFalse);
    });

    test('空追问不产卡', () {
      expect(followUpNeedsRecommendations(''), isFalse);
      expect(followUpNeedsRecommendations('   '), isFalse);
    });
  });

  group('chatRouteHandler', () {
    test('明确词返回 need:true 信封', () async {
      final body = await chatRouteHandler(_post({'follow_up': '换一批'}));
      final json = await _decode(body);

      expect(json['code'], 0);
      expect(json['message'], 'ok');
      expect((json['data'] as Map)['need'], isTrue);
    });

    test('解释性问句返回 need:false 信封', () async {
      final body = await chatRouteHandler(
        _post({'follow_up': '他的研究方向是什么？'}),
      );
      final json = await _decode(body);

      expect((json['data'] as Map)['need'], isFalse);
    });

    test('follow_up 缺省视为空，返回 need:false', () async {
      final body = await chatRouteHandler(_post(<String, dynamic>{}));
      final json = await _decode(body);

      expect((json['data'] as Map)['need'], isFalse);
    });

    test('非 Map 请求体返回 need:false', () async {
      final body = await chatRouteHandler(_post('not-a-map'));
      final json = await _decode(body);

      expect((json['data'] as Map)['need'], isFalse);
    });
  });

  group('FakeBackendAdapter', () {
    test('把 POST /api/v1/chat/route 分派到 chatRouteHandler', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = FakeBackendAdapter();

      final res = await dio.post<dynamic>('/api/v1/chat/route', data: {
        'follow_up': '再推荐几位',
      });
      expect(res.data['code'], 0);
      expect((res.data['data'] as Map)['need'], isTrue);
    });

    test('未注册路径返回 404 信封', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = FakeBackendAdapter();

      final res = await dio.get<dynamic>('/api/v1/recommendations/mentors');
      expect(res.data['code'], 40401);
      expect(res.data['data'], isNull);
    });

    test('register 可扩展覆盖端点', () async {
      final adapter = FakeBackendAdapter()
        ..register(
          'POST',
          '/api/v1/ping',
          (options) async => ResponseBody.fromString(
            jsonEncode({'code': 0, 'message': 'ok', 'data': {'pong': true}}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = adapter;

      final res = await dio.post<dynamic>('/api/v1/ping');
      expect((res.data['data'] as Map)['pong'], isTrue);
    });
  });
}

RequestOptions _post(Object? data) {
  return RequestOptions(path: '/api/v1/chat/route', method: 'POST', data: data);
}

Future<Map<String, dynamic>> _decode(ResponseBody body) async {
  final bytes = <int>[];
  await for (final chunk in body.stream) {
    bytes.addAll(chunk);
  }
  return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}
