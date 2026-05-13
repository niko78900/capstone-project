import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/core/network/auth_token_storage.dart';
import 'package:cap_app/features/auth/models/password_reset_models.dart';

class PasswordResetRepository {
  PasswordResetRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final AuthTokenStorage _tokenStorage;

  Future<PasswordResetRequestResponse> requestReset(String email) async {
    final raw = await _apiClient.post(
      '/api/v1/auth/password-reset-requests',
      data: {'email': email},
    );
    if (raw is! Map) {
      throw const AppException(message: 'Password reset request failed');
    }
    final response = PasswordResetRequestResponse.fromJson(
      raw.cast<String, dynamic>(),
    );
    if (response.requestToken.isEmpty) {
      throw const AppException(message: 'Password reset request failed');
    }
    await _tokenStorage.savePasswordResetToken(response.requestToken);
    return response;
  }

  Future<PasswordResetStatusResponse?> checkStoredStatus() async {
    final token = await _tokenStorage.readPasswordResetToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    final raw = await _apiClient.get(
      '/api/v1/auth/password-reset-requests/$token/status',
    );
    if (raw is! Map) {
      throw const AppException(message: 'Could not check reset request');
    }
    return PasswordResetStatusResponse.fromJson(raw.cast<String, dynamic>());
  }

  Future<PasswordResetCompleteResponse> completeStoredReset({
    required String email,
    required String newPassword,
  }) async {
    final token = await _tokenStorage.readPasswordResetToken();
    if (token == null || token.isEmpty) {
      throw const AppException(
        message: 'No password reset request is stored on this device',
      );
    }
    final raw = await _apiClient.post(
      '/api/v1/auth/password-reset-requests/$token/complete',
      data: {'email': email, 'newPassword': newPassword},
    );
    if (raw is! Map) {
      throw const AppException(message: 'Password reset failed');
    }
    await _tokenStorage.clearPasswordResetToken();
    return PasswordResetCompleteResponse.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> clearStoredRequest() {
    return _tokenStorage.clearPasswordResetToken();
  }
}
