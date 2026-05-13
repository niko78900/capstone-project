import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RememberedCredentials {
  const RememberedCredentials({required this.email, required this.password});

  final String email;
  final String password;
}

class AuthTokenStorage {
  const AuthTokenStorage();

  static const _tokenKey = 'auth_token';
  static const _rememberedEmailKey = 'remembered_email';
  static const _rememberedPasswordKey = 'remembered_password';
  static const _passwordResetTokenKey = 'password_reset_token';
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

  Future<void> saveRememberedCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _rememberedEmailKey, value: email);
    await _storage.write(key: _rememberedPasswordKey, value: password);
  }

  Future<RememberedCredentials?> readRememberedCredentials() async {
    final email = await _storage.read(key: _rememberedEmailKey);
    final password = await _storage.read(key: _rememberedPasswordKey);
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return RememberedCredentials(email: email, password: password);
  }

  Future<void> clearRememberedCredentials() async {
    await _storage.delete(key: _rememberedEmailKey);
    await _storage.delete(key: _rememberedPasswordKey);
  }

  Future<void> savePasswordResetToken(String token) async {
    await _storage.write(key: _passwordResetTokenKey, value: token);
  }

  Future<String?> readPasswordResetToken() async {
    return _storage.read(key: _passwordResetTokenKey);
  }

  Future<void> clearPasswordResetToken() async {
    await _storage.delete(key: _passwordResetTokenKey);
  }
}
