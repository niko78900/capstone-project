// File purpose: Manages Riverpod state for Flutter rewards feature flows.
import 'package:cap_app/core/network/network_providers.dart';
import 'package:cap_app/features/auth/providers/auth_providers.dart';
import 'package:cap_app/features/rewards/data/rewards_repository.dart';
import 'package:cap_app/features/rewards/models/rewards_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  return RewardsRepository(ref.read(apiClientProvider));
});

final rewardWindowProvider = StateProvider<RewardWindow>((ref) {
  return RewardWindow.allTime;
});

final rewardsDashboardProvider = FutureProvider<RewardsDashboard>((ref) async {
  ref.watch(
    authSessionProvider.select((state) => state.valueOrNull?.accessToken),
  );
  final window = ref.watch(rewardWindowProvider);
  final repo = ref.watch(rewardsRepositoryProvider);
  try {
    final results = await Future.wait([
      repo.getMe(),
      repo.getLeaderboard(window: window, limit: 50),
    ]);
    return RewardsDashboard(
      me: results[0] as RewardsMeResponse,
      leaderboard: results[1] as LeaderboardResponse,
    );
  } catch (error) {
    await ref
        .read(authSessionProvider.notifier)
        .forceLogoutOnUnauthorized(error);
    rethrow;
  }
});

final rewardsRecomputeControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      RewardsRecomputeController,
      RecomputeRewardsResponse?
    >(RewardsRecomputeController.new);

class RewardsRecomputeController
    extends AutoDisposeAsyncNotifier<RecomputeRewardsResponse?> {
  RewardsRepository get _repo => ref.read(rewardsRepositoryProvider);

  @override
  Future<RecomputeRewardsResponse?> build() async {
    return null;
  }

  Future<RecomputeRewardsResponse?> recompute() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.recompute);
    final error = state.asError?.error;
    if (error != null) {
      await ref
          .read(authSessionProvider.notifier)
          .forceLogoutOnUnauthorized(error);
      return null;
    }
    ref.invalidate(rewardsDashboardProvider);
    return state.valueOrNull;
  }
}
