// File purpose: Connects Flutter auth feature code to backend or local data sources.
import 'dart:convert';

import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/core/network/auth_token_storage.dart';
import 'package:cap_app/features/auth/models/auth_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  static const _sessionKey = 'auth_session';
  static const _sessionIssuedAtMsKey = 'auth_session_issued_at_ms';
  static const _sessionExpiresAtMsKey = 'auth_session_expires_at_ms';
  static const _maxSessionLifetimeMs = 604800000;

  final ApiClient _apiClient;
  final AuthTokenStorage _tokenStorage;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final raw = await _apiClient.post(
      '/api/v1/auth/register',
      data: {'email': email, 'password': password, 'displayName': displayName},
      authenticated: false,
    );

    final session = AuthSession.fromJson((raw as Map).cast<String, dynamic>());
    await _persistSession(session);
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final raw = await _apiClient.post(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
      authenticated: false,
    );

    final session = AuthSession.fromJson((raw as Map).cast<String, dynamic>());
    await _persistSession(session);
    return session;
  }

  Future<AuthSession?> restoreSession() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await _clearPersistedSession(prefs: prefs, clearToken: false);
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_sessionKey);
    final session = AuthSession.decodeFromStorage(encoded);
    if (session == null) {
      await _clearPersistedSession(prefs: prefs, clearToken: true);
      return null;
    }
    final issuedAtMs = prefs.getInt(_sessionIssuedAtMsKey);
    final expiresAtMs = prefs.getInt(_sessionExpiresAtMsKey);
    if (!_isSessionWindowValid(
      issuedAtMs: issuedAtMs,
      expiresAtMs: expiresAtMs,
    )) {
      await _clearPersistedSession(prefs: prefs, clearToken: true);
      return null;
    }

    if (session.accessToken != token) {
      return AuthSession(
        accessToken: token,
        tokenType: session.tokenType,
        expiresInMs: session.expiresInMs,
        user: session.user,
      );
    }

    return session;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearPersistedSession(prefs: prefs, clearToken: true);
  }

  Future<void> _persistSession(AuthSession session) async {
    if (session.accessToken.isEmpty) {
      throw const AppException(message: 'No access token returned by server');
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs =
        nowMs + _normalizedSessionDurationMs(session.expiresInMs);

    await _tokenStorage.saveToken(session.accessToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    await prefs.setInt(_sessionIssuedAtMsKey, nowMs);
    await prefs.setInt(_sessionExpiresAtMsKey, expiresAtMs);
  }

  int _normalizedSessionDurationMs(int rawExpiresInMs) {
    if (rawExpiresInMs <= 0) {
      return _maxSessionLifetimeMs;
    }
    if (rawExpiresInMs > _maxSessionLifetimeMs) {
      return _maxSessionLifetimeMs;
    }
    return rawExpiresInMs;
  }

  bool _isSessionWindowValid({
    required int? issuedAtMs,
    required int? expiresAtMs,
  }) {
    if (issuedAtMs == null || expiresAtMs == null) {
      return false;
    }
    if (issuedAtMs <= 0 || expiresAtMs <= issuedAtMs) {
      return false;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs >= expiresAtMs) {
      return false;
    }
    if (nowMs - issuedAtMs >= _maxSessionLifetimeMs) {
      return false;
    }
    return true;
  }

  Future<void> _clearPersistedSession({
    required SharedPreferences prefs,
    required bool clearToken,
  }) async {
    if (clearToken) {
      await _tokenStorage.clearToken();
    }
    await prefs.remove(_sessionKey);
    await prefs.remove(_sessionIssuedAtMsKey);
    await prefs.remove(_sessionExpiresAtMsKey);
  }
}
