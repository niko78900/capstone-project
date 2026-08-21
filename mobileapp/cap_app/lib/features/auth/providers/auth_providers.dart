// File purpose: Manages Riverpod state for Flutter auth feature flows.
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

final passwordResetGateProvider =
    AsyncNotifierProvider<
      PasswordResetGateController,
      PasswordResetStatusResponse?
    >(PasswordResetGateController.new);

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
    if (state.hasValue) {
      ref.read(passwordResetGateProvider.notifier).markCleared();
    }
    return state.valueOrNull;
  }
}

class PasswordResetGateController
    extends AsyncNotifier<PasswordResetStatusResponse?> {
  PasswordResetRepository get _repo =>
      ref.read(passwordResetRepositoryProvider);

  String? _lastApprovedNotificationKey;

  @override
  Future<PasswordResetStatusResponse?> build() async {
    try {
      await ref.watch(authSessionProvider.future);
    } catch (_) {
      // Reset recovery should not block the auth error flow.
    }
    return _resolveStoredStatus(keepTerminalStatus: false);
  }

  Future<PasswordResetStatusResponse?> checkStoredStatus({
    bool showNotification = true,
  }) async {
    state = const AsyncLoading();
    try {
      final status = await _resolveStoredStatus(
        keepTerminalStatus: true,
        showNotification: showNotification,
      );
      state = AsyncData(_gateStatus(status));
      return status;
    } catch (error, stackTrace) {
      if (error is AppException && error.statusCode == 404) {
        await _repo.clearStoredRequest();
        state = const AsyncData(null);
        return null;
      }
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> clearStoredRequest() async {
    await _repo.clearStoredRequest();
    markCleared();
  }

  void markCleared() {
    _lastApprovedNotificationKey = null;
    state = const AsyncData(null);
  }

  Future<PasswordResetStatusResponse?> _resolveStoredStatus({
    bool keepTerminalStatus = false,
    bool showNotification = true,
  }) async {
    try {
      final status = await _repo.checkStoredStatus();
      if (status == null) {
        return null;
      }

      switch (status.status) {
        case PasswordResetStatus.approved:
          if (showNotification) {
            await _notifyApproved(status);
          }
          return status;
        case PasswordResetStatus.denied:
          if (showNotification) {
            await ref
                .read(localNotificationsServiceProvider)
                .show(
                  notificationId: 310002,
                  title: 'Password reset denied',
                  body: 'Your password reset request was denied.',
                );
          }
          await _repo.clearStoredRequest();
          return keepTerminalStatus ? status : null;
        case PasswordResetStatus.completed:
        case PasswordResetStatus.expired:
          await _repo.clearStoredRequest();
          return keepTerminalStatus ? status : null;
        case PasswordResetStatus.pending:
        case PasswordResetStatus.unknown:
          return status;
      }
    } catch (error) {
      if (error is AppException && error.statusCode == 404) {
        await _repo.clearStoredRequest();
        return null;
      }
      rethrow;
    }
  }

  PasswordResetStatusResponse? _gateStatus(
    PasswordResetStatusResponse? status,
  ) {
    if (status == null) {
      return null;
    }
    return switch (status.status) {
      PasswordResetStatus.approved ||
      PasswordResetStatus.pending ||
      PasswordResetStatus.unknown => status,
      PasswordResetStatus.denied ||
      PasswordResetStatus.completed ||
      PasswordResetStatus.expired => null,
    };
  }

  Future<void> _notifyApproved(PasswordResetStatusResponse status) async {
    final key =
        '${status.email}|${status.expiresAt?.toIso8601String()}|${status.updatedAt?.toIso8601String()}';
    if (_lastApprovedNotificationKey == key) {
      return;
    }
    _lastApprovedNotificationKey = key;
    await ref
        .read(localNotificationsServiceProvider)
        .show(
          notificationId: 310001,
          title: 'Password reset approved',
          body: 'Open the app to set a new password.',
        );
  }
}

Future<void> handleStoredPasswordResetStatus(WidgetRef ref) async {
  await ref.read(passwordResetGateProvider.notifier).checkStoredStatus();
}
