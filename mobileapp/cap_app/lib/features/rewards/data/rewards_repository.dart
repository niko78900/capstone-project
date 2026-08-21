// File purpose: Connects Flutter rewards feature code to backend or local data sources.
import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/features/rewards/models/rewards_models.dart';

class RewardsRepository {
  RewardsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<RewardsMeResponse> getMe() async {
    final raw = await _apiClient.get('/api/v1/rewards/me');
    return RewardsMeResponse.fromJson((raw as Map).cast<String, dynamic>());
  }

  Future<LeaderboardResponse> getLeaderboard({
    RewardWindow window = RewardWindow.allTime,
    int limit = 50,
  }) async {
    final raw = await _apiClient.get(
      '/api/v1/rewards/leaderboard',
      queryParameters: {'window': window.apiValue, 'limit': limit},
    );
    return LeaderboardResponse.fromJson((raw as Map).cast<String, dynamic>());
  }

  Future<RecomputeRewardsResponse> recompute() async {
    final raw = await _apiClient.post('/api/v1/admin/rewards/recompute');
    return RecomputeRewardsResponse.fromJson(
      (raw as Map).cast<String, dynamic>(),
    );
  }
}
