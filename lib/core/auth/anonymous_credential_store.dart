import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AnonymousCredentialStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clear();
}

class SecureAnonymousCredentialStore implements AnonymousCredentialStore {
  const SecureAnonymousCredentialStore(this._storage);

  static const _key = 'scho_navi.anonymous_access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _key);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
