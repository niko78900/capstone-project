import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStorage {
  const AuthTokenStorage();

  static const _tokenKey = 'auth_token';
  static String? _cachedToken;

  FlutterSecureStorage get _storage => const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    final cached = _cachedToken;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final persisted = await _storage.read(key: _tokenKey);
    _cachedToken = persisted;
    return persisted;
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }
}
