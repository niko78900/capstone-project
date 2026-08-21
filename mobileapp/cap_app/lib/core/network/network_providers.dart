// File purpose: Configures Flutter networking and authenticated API access.
import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/core/network/auth_token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  return const AuthTokenStorage();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(authTokenStorageProvider));
});
