import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/auth/anonymous_credential_store.dart';
import '../../core/error/app_exception.dart';
import '../dto/api_envelope.dart';

const skipApiAuthExtraKey = 'scho_navi.skip_api_auth';

class ApiAuthenticator {
  ApiAuthenticator(this._identityDio, this._credentials);

  final Dio _identityDio;
  final AnonymousCredentialStore _credentials;
  Future<String>? _tokenFuture;
  Future<void>? _webIdentityFuture;

  Future<void> authenticate(RequestOptions options) async {
    if (options.extra[skipApiAuthExtraKey] == true) return;
    if (options.path.endsWith('/api/v1/identity/anonymous') ||
        options.path.endsWith('/identity/anonymous')) {
      return;
    }
    if (kIsWeb) {
      await _ensureWebIdentity();
      return;
    }
    if (!options.headers.containsKey('Authorization')) {
      final token = await _token();
      options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<void> clear() async {
    _tokenFuture = null;
    _webIdentityFuture = null;
    await _credentials.clear();
  }

  Future<String> _token() => _tokenFuture ??= _loadOrCreateToken();

  Future<void> _ensureWebIdentity() =>
      _webIdentityFuture ??= _identityDio.post<dynamic>(
        '/api/v1/identity/anonymous',
        options: Options(extra: {skipApiAuthExtraKey: true}),
      );

  Future<String> _loadOrCreateToken() async {
    final stored = await _credentials.readToken();
    if (stored != null && stored.isNotEmpty) return stored;
    final response = await _identityDio.post<dynamic>(
      '/api/v1/identity/anonymous',
      options: Options(extra: {skipApiAuthExtraKey: true}),
    );
    final data = decodeEnvelope(response.data, (value) => asJsonObject(value));
    final token = data['access_token']?.toString();
    if (token == null || token.isEmpty) throw const ServerException();
    await _credentials.writeToken(token);
    return token;
  }
}

class ApiAuthInterceptor extends QueuedInterceptor {
  ApiAuthInterceptor(this._authenticator);

  final ApiAuthenticator _authenticator;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      await _authenticator.authenticate(options);
      handler.next(options);
    } on DioException catch (error) {
      handler.reject(error);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}
