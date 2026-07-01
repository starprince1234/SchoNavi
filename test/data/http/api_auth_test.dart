import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/auth/anonymous_credential_store.dart';
import 'package:scho_navi/data/http/api_auth.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }
}

class _MemoryCredentials implements AnonymousCredentialStore {
  String? token;

  @override
  Future<void> clear() async => token = null;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async => this.token = token;
}

void main() {
  test('adds anonymous bearer token to API requests and caches it', () async {
    var identityCalls = 0;
    final credentials = _MemoryCredentials();
    final identityDio = _dio((options) async {
      identityCalls++;
      expect(options.path, '/api/v1/identity/anonymous');
      return _json({
        'code': 0,
        'message': 'ok',
        'data': {'owner_id': 'owner-1', 'access_token': 'token-1'},
      });
    });
    final apiDio =
        _dio((options) async {
            expect(options.headers['Authorization'], 'Bearer token-1');
            return _json({'code': 0, 'message': 'ok', 'data': {}});
          })
          ..interceptors.add(
            ApiAuthInterceptor(ApiAuthenticator(identityDio, credentials)),
          );

    await apiDio.get<dynamic>('/api/v1/profile');
    await apiDio.get<dynamic>('/api/v1/history');

    expect(identityCalls, 1);
    expect(credentials.token, 'token-1');
  });

  test('does not authenticate identity endpoint itself', () async {
    var identityCalls = 0;
    RequestOptions? captured;
    final identityDio = _dio((_) async {
      identityCalls++;
      return _json({
        'code': 0,
        'message': 'ok',
        'data': {'owner_id': 'owner-1', 'access_token': 'token-1'},
      });
    });
    final apiDio =
        _dio((options) async {
            captured = options;
            return _json({
              'code': 0,
              'message': 'ok',
              'data': {'owner_id': 'owner-1', 'access_token': 'token-1'},
            });
          })
          ..interceptors.add(
            ApiAuthInterceptor(
              ApiAuthenticator(identityDio, _MemoryCredentials()),
            ),
          );

    await apiDio.post<dynamic>('/api/v1/identity/anonymous');

    expect(identityCalls, 0);
    expect(captured!.headers.containsKey('Authorization'), isFalse);
  });
}

Dio _dio(Future<ResponseBody> Function(RequestOptions options) handler) {
  return Dio(BaseOptions(baseUrl: 'https://api.example.com'))
    ..httpClientAdapter = _FakeAdapter(handler);
}

ResponseBody _json(Map<String, dynamic> json) {
  return ResponseBody.fromString(
    jsonEncode(json),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
