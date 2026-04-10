import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/data/auth_repository.dart';
import 'package:cap_app/features/auth/models/auth_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiClientProvider),
    ref.read(authTokenStorageProvider),
  );
});

final authSessionProvider = AsyncNotifierProvider<AuthSessionController, AuthSession?>(
  AuthSessionController.new,
);

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authSessionProvider).valueOrNull != null;
});

class AuthSessionController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() {
    return _repo.restoreSession();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await _repo.login(email: email, password: password);
      return session;
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      return session;
    });
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  Future<void> forceLogoutOnUnauthorized(Object error) async {
    if (error is AppException && error.isUnauthorized) {
      await logout();
    }
  }
}
