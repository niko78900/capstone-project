import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStorage {
  const AuthTokenStorage();

  static const _tokenKey = 'auth_token';

  FlutterSecureStorage get _storage => const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
