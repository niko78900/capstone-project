import 'dart:convert';

import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/core/network/auth_token_storage.dart';
import 'package:cap_app/features/auth/models/auth_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  AuthRepository(
    this._apiClient,
    this._tokenStorage,
  );

  static const _sessionKey = 'auth_session';

  final ApiClient _apiClient;
  final AuthTokenStorage _tokenStorage;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final raw = await _apiClient.post(
      '/api/v1/auth/register',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
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
      data: {
        'email': email,
        'password': password,
      },
    );

    final session = AuthSession.fromJson((raw as Map).cast<String, dynamic>());
    await _persistSession(session);
    return session;
  }

  Future<AuthSession?> restoreSession() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_sessionKey);
    final session = AuthSession.decodeFromStorage(encoded);
    if (session == null) {
      await _tokenStorage.clearToken();
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
    await _tokenStorage.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> _persistSession(AuthSession session) async {
    if (session.accessToken.isEmpty) {
      throw const AppException(message: 'No access token returned by server');
    }

    await _tokenStorage.saveToken(session.accessToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }
}
