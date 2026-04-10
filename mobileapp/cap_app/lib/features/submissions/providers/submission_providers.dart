import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/submissions/data/submission_repository.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final submissionRepositoryProvider = Provider<SubmissionRepository>((ref) {
  return SubmissionRepository(ref.read(apiClientProvider));
});

final mySubmissionsProvider = FutureProvider<List<SubmissionResponse>>((ref) async {
  final repo = ref.watch(submissionRepositoryProvider);
  try {
    return await repo.getMySubmissions();
  } catch (error) {
    await ref.read(authSessionProvider.notifier).forceLogoutOnUnauthorized(error);
    rethrow;
  }
});

final productSubmissionControllerProvider =
    AutoDisposeAsyncNotifierProvider<ProductSubmissionController, SubmissionResponse?>(
  ProductSubmissionController.new,
);

class ProductSubmissionController extends AutoDisposeAsyncNotifier<SubmissionResponse?> {
  SubmissionRepository get _repo => ref.read(submissionRepositoryProvider);

  @override
  Future<SubmissionResponse?> build() async {
    return null;
  }

  Future<SubmissionResponse?> submit(ProductSubmissionRequestDto request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.submitProduct(request));
    final error = state.asError?.error;
    if (error != null) {
      await ref.read(authSessionProvider.notifier).forceLogoutOnUnauthorized(error);
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
    AutoDisposeAsyncNotifierProvider<PriceSubmissionController, SubmissionResponse?>(
  PriceSubmissionController.new,
);

class PriceSubmissionController extends AutoDisposeAsyncNotifier<SubmissionResponse?> {
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
      await ref.read(authSessionProvider.notifier).forceLogoutOnUnauthorized(error);
      return null;
    }
    ref.invalidate(mySubmissionsProvider);
    return state.valueOrNull;
  }

  void clear() {
    state = const AsyncData(null);
  }
}
