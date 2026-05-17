import 'dart:async';
import 'dart:convert';

import 'package:cap_app/core/notifications/local_notifications_service.dart';
import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:cap_app/features/submissions/data/submission_repository.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final submissionRepositoryProvider = Provider<SubmissionRepository>((ref) {
  return SubmissionRepository(ref.read(apiClientProvider));
});

final submissionNotificationBootstrapProvider = Provider<void>((ref) {
  final poller = _SubmissionStatusPoller(ref);
  ref.onDispose(poller.dispose);
  ref.listen(
    authSessionProvider.select((state) => state.valueOrNull?.accessToken),
    (previous, next) {
      if (next == null || next.isEmpty) {
        poller.stop();
      } else {
        poller.start();
      }
    },
    fireImmediately: true,
  );
});

final mySubmissionsProvider = FutureProvider<List<SubmissionResponse>>((
  ref,
) async {
  ref.watch(
    authSessionProvider.select((state) => state.valueOrNull?.accessToken),
  );
  final repo = ref.watch(submissionRepositoryProvider);
  try {
    return await repo.getMySubmissions();
  } catch (error) {
    await ref
        .read(authSessionProvider.notifier)
        .forceLogoutOnUnauthorized(error);
    rethrow;
  }
});

final productSubmissionControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      ProductSubmissionController,
      SubmissionResponse?
    >(ProductSubmissionController.new);

class ProductSubmissionController
    extends AutoDisposeAsyncNotifier<SubmissionResponse?> {
  SubmissionRepository get _repo => ref.read(submissionRepositoryProvider);

  @override
  Future<SubmissionResponse?> build() async {
    return null;
  }

  Future<SubmissionResponse?> submit(
    ProductSubmissionRequestDto request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.submitProduct(request));
    final error = state.asError?.error;
    if (error != null) {
      await ref
          .read(authSessionProvider.notifier)
          .forceLogoutOnUnauthorized(error);
      return null;
    }
    ref.invalidate(mySubmissionsProvider);
    return state.valueOrNull;
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final priceSubmissionControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      PriceSubmissionController,
      SubmissionResponse?
    >(PriceSubmissionController.new);

class PriceSubmissionController
    extends AutoDisposeAsyncNotifier<SubmissionResponse?> {
  SubmissionRepository get _repo => ref.read(submissionRepositoryProvider);

  @override
  Future<SubmissionResponse?> build() async {
    return null;
  }

  Future<SubmissionResponse?> submit(PriceSubmissionRequestDto request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.submitPrice(request));
    final error = state.asError?.error;
    if (error != null) {
      await ref
          .read(authSessionProvider.notifier)
          .forceLogoutOnUnauthorized(error);
      return null;
    }
    ref.invalidate(mySubmissionsProvider);
    return state.valueOrNull;
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final availabilitySubmissionControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      AvailabilitySubmissionController,
      SubmissionResponse?
    >(AvailabilitySubmissionController.new);

class AvailabilitySubmissionController
    extends AutoDisposeAsyncNotifier<SubmissionResponse?> {
  SubmissionRepository get _repo => ref.read(submissionRepositoryProvider);

  @override
  Future<SubmissionResponse?> build() async {
    return null;
  }

  Future<SubmissionResponse?> submit(
    AvailabilitySubmissionRequestDto request,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.submitAvailability(request));
    final error = state.asError?.error;
    if (error != null) {
      await ref
          .read(authSessionProvider.notifier)
          .forceLogoutOnUnauthorized(error);
      return null;
    }
    ref.invalidate(mySubmissionsProvider);
    return state.valueOrNull;
  }

  void clear() {
    state = const AsyncData(null);
  }
}

class _SubmissionStatusPoller {
  _SubmissionStatusPoller(this._ref);

  static const _pollInterval = Duration(seconds: 45);
  static const _snapshotKeyPrefix = 'submission_status_snapshot_user_';

  final Ref _ref;

  Timer? _timer;
  bool _isChecking = false;

  void start() {
    unawaited(_ref.read(localNotificationsServiceProvider).ensureInitialized());
    _timer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(_checkOnce());
    });
    unawaited(_checkOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }

  Future<void> _checkOnce() async {
    if (_isChecking) {
      return;
    }
    final session = _ref.read(authSessionProvider).valueOrNull;
    if (session == null) {
      return;
    }

    _isChecking = true;
    try {
      final submissions = await _ref
          .read(submissionRepositoryProvider)
          .getMySubmissions();
      await _processSubmissionChanges(
        userId: session.user.id,
        submissions: submissions,
      );
    } catch (error) {
      await _ref
          .read(authSessionProvider.notifier)
          .forceLogoutOnUnauthorized(error);
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _processSubmissionChanges({
    required int userId,
    required List<SubmissionResponse> submissions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshotKey = '$_snapshotKeyPrefix$userId';
    final previous = _decodeSnapshot(prefs.getString(snapshotKey));
    final current = <int, SubmissionStatus>{
      for (final submission in submissions) submission.id: submission.status,
    };

    final notificationsEnabled = _ref.read(
      submissionDecisionNotificationsEnabledProvider,
    );

    if (previous.isNotEmpty && notificationsEnabled) {
      for (final submission in submissions) {
        final oldStatus = previous[submission.id];
        final newStatus = submission.status;
        if (oldStatus == null || oldStatus == newStatus) {
          continue;
        }
        if (newStatus != SubmissionStatus.approved &&
            newStatus != SubmissionStatus.rejected) {
          continue;
        }
        await _notifyDecision(submission);
      }
    }

    final encoded = <String, String>{
      for (final entry in current.entries)
        entry.key.toString(): _statusStorageValue(entry.value),
    };
    await prefs.setString(snapshotKey, jsonEncode(encoded));
  }

  Map<int, SubmissionStatus> _decodeSnapshot(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const {};
    }
    if (decoded is! Map) {
      return const {};
    }
    final result = <int, SubmissionStatus>{};
    for (final entry in decoded.entries) {
      final id = int.tryParse(entry.key.toString());
      if (id == null) {
        continue;
      }
      final status = parseSubmissionStatus(entry.value?.toString());
      result[id] = status;
    }
    return result;
  }

  String _statusStorageValue(SubmissionStatus status) {
    return switch (status) {
      SubmissionStatus.pending => 'PENDING',
      SubmissionStatus.approved => 'APPROVED',
      SubmissionStatus.rejected => 'REJECTED',
      SubmissionStatus.unknown => 'UNKNOWN',
    };
  }

  Future<void> _notifyDecision(SubmissionResponse submission) async {
    final statusWord = submission.status == SubmissionStatus.approved
        ? 'approved'
        : 'rejected';
    final typeWord = switch (submission.type) {
      SubmissionType.product => 'product',
      SubmissionType.price => 'price',
      SubmissionType.nutrition => 'nutrition',
      SubmissionType.availability => 'availability',
      SubmissionType.unknown => 'submission',
    };
    final title = 'Submission $statusWord';
    final body = 'Your $typeWord update was $statusWord.';

    final notificationId = (submission.id.abs() % 100000) + 200000;
    await _ref
        .read(localNotificationsServiceProvider)
        .show(notificationId: notificationId, title: title, body: body);
  }
}
