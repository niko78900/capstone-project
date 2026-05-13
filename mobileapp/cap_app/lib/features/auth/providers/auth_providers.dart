import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/notifications/local_notifications_service.dart';
import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/data/auth_repository.dart';
import 'package:cap_app/features/auth/data/password_reset_repository.dart';
import 'package:cap_app/features/auth/models/auth_models.dart';
import 'package:cap_app/features/auth/models/password_reset_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiClientProvider),
    ref.read(authTokenStorageProvider),
  );
});

final passwordResetRepositoryProvider = Provider<PasswordResetRepository>((
  ref,
) {
  return PasswordResetRepository(
    ref.read(apiClientProvider),
    ref.read(authTokenStorageProvider),
  );
});

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionController, AuthSession?>(
      AuthSessionController.new,
    );

final passwordResetRequestControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      PasswordResetRequestController,
      PasswordResetRequestResponse?
    >(PasswordResetRequestController.new);

final passwordResetCompletionControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      PasswordResetCompletionController,
      PasswordResetCompleteResponse?
    >(PasswordResetCompletionController.new);

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authSessionProvider).valueOrNull != null;
});

class AuthSessionController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() {
    return _repo.restoreSession();
  }

  Future<void> login({required String email, required String password}) async {
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

class PasswordResetRequestController
    extends AutoDisposeAsyncNotifier<PasswordResetRequestResponse?> {
  PasswordResetRepository get _repo =>
      ref.read(passwordResetRepositoryProvider);

  @override
  Future<PasswordResetRequestResponse?> build() async {
    return null;
  }

  Future<PasswordResetRequestResponse?> request(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.requestReset(email));
    return state.valueOrNull;
  }
}

class PasswordResetCompletionController
    extends AutoDisposeAsyncNotifier<PasswordResetCompleteResponse?> {
  PasswordResetRepository get _repo =>
      ref.read(passwordResetRepositoryProvider);

  @override
  Future<PasswordResetCompleteResponse?> build() async {
    return null;
  }

  Future<PasswordResetCompleteResponse?> complete({
    required String email,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.completeStoredReset(email: email, newPassword: newPassword),
    );
    return state.valueOrNull;
  }
}

Future<void> handleStoredPasswordResetStatus(WidgetRef ref) async {
  final status = await ref
      .read(passwordResetRepositoryProvider)
      .checkStoredStatus();
  if (status == null) {
    return;
  }

  switch (status.status) {
    case PasswordResetStatus.approved:
      await ref
          .read(localNotificationsServiceProvider)
          .show(
            notificationId: 310001,
            title: 'Password reset approved',
            body: 'Open the app to set a new password.',
          );
      break;
    case PasswordResetStatus.denied:
      await ref
          .read(localNotificationsServiceProvider)
          .show(
            notificationId: 310002,
            title: 'Password reset denied',
            body: 'Your password reset request was denied.',
          );
      await ref.read(passwordResetRepositoryProvider).clearStoredRequest();
      break;
    case PasswordResetStatus.completed:
    case PasswordResetStatus.expired:
      await ref.read(passwordResetRepositoryProvider).clearStoredRequest();
      break;
    case PasswordResetStatus.pending:
    case PasswordResetStatus.unknown:
      break;
  }
}
