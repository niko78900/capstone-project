// File purpose: Defines Flutter data models for rewards feature flows.
enum RewardWindow { allTime, thirtyDays }

extension RewardWindowLabels on RewardWindow {
  String get apiValue {
    return switch (this) {
      RewardWindow.allTime => 'ALL_TIME',
      RewardWindow.thirtyDays => '30D',
    };
  }

  String get label {
    return switch (this) {
      RewardWindow.allTime => 'All time',
      RewardWindow.thirtyDays => 'Last 30 days',
    };
  }
}

RewardWindow parseRewardWindow(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case '30D':
    case 'THIRTY_DAYS':
      return RewardWindow.thirtyDays;
    case 'ALL_TIME':
    default:
      return RewardWindow.allTime;
  }
}

class ContributorStatsDto {
  const ContributorStatsDto({
    required this.userId,
    required this.email,
    required this.approvedProductCount,
    required this.approvedPriceCount,
    required this.approvedNutritionCount,
    required this.approvedTotalCount,
    required this.rejectedCount,
    required this.score,
    required this.lastEventAt,
  });

  final int userId;
  final String email;
  final int approvedProductCount;
  final int approvedPriceCount;
  final int approvedNutritionCount;
  final int approvedTotalCount;
  final int rejectedCount;
  final int score;
  final DateTime? lastEventAt;

  factory ContributorStatsDto.fromJson(Map<String, dynamic> json) {
    return ContributorStatsDto(
      userId: _toInt(json['userId']),
      email: _toString(json['email']),
      approvedProductCount: _toInt(json['approvedProductCount']),
      approvedPriceCount: _toInt(json['approvedPriceCount']),
      approvedNutritionCount: _toInt(json['approvedNutritionCount']),
      approvedTotalCount: _toInt(json['approvedTotalCount']),
      rejectedCount: _toInt(json['rejectedCount']),
      score: _toInt(json['score']),
      lastEventAt: _toDateTime(json['lastEventAt']),
    );
  }
}

class ContributorScoreEventDto {
  const ContributorScoreEventDto({
    required this.eventId,
    required this.submissionId,
    required this.submissionType,
    required this.eventType,
    required this.points,
    required this.createdAt,
  });

  final int eventId;
  final int submissionId;
  final String submissionType;
  final String eventType;
  final int points;
  final DateTime? createdAt;

  factory ContributorScoreEventDto.fromJson(Map<String, dynamic> json) {
    return ContributorScoreEventDto(
      eventId: _toInt(json['eventId']),
      submissionId: _toInt(json['submissionId']),
      submissionType: _toString(json['submissionType']),
      eventType: _toString(json['eventType']),
      points: _toInt(json['points']),
      createdAt: _toDateTime(json['createdAt']),
    );
  }
}

class RewardsMeResponse {
  const RewardsMeResponse({required this.stats, required this.recentEvents});

  final ContributorStatsDto stats;
  final List<ContributorScoreEventDto> recentEvents;

  factory RewardsMeResponse.fromJson(Map<String, dynamic> json) {
    final statsRaw = json['stats'];
    final eventsRaw = json['recentEvents'];
    return RewardsMeResponse(
      stats: statsRaw is Map
          ? ContributorStatsDto.fromJson(statsRaw.cast<String, dynamic>())
          : ContributorStatsDto.fromJson(const {}),
      recentEvents: eventsRaw is List
          ? eventsRaw
                .whereType<Map>()
                .map(
                  (event) => ContributorScoreEventDto.fromJson(
                    event.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class LeaderboardEntryDto {
  const LeaderboardEntryDto({
    required this.rank,
    required this.userId,
    required this.email,
    required this.score,
    required this.approvedCount,
    required this.rejectedCount,
    required this.lastEventAt,
  });

  final int rank;
  final int userId;
  final String email;
  final int score;
  final int approvedCount;
  final int rejectedCount;
  final DateTime? lastEventAt;

  factory LeaderboardEntryDto.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryDto(
      rank: _toInt(json['rank']),
      userId: _toInt(json['userId']),
      email: _toString(json['email']),
      score: _toInt(json['score']),
      approvedCount: _toInt(json['approvedCount']),
      rejectedCount: _toInt(json['rejectedCount']),
      lastEventAt: _toDateTime(json['lastEventAt']),
    );
  }
}

class LeaderboardResponse {
  const LeaderboardResponse({
    required this.window,
    required this.limit,
    required this.entries,
  });

  final RewardWindow window;
  final int limit;
  final List<LeaderboardEntryDto> entries;

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) {
    final entriesRaw = json['entries'];
    return LeaderboardResponse(
      window: parseRewardWindow(json['window']?.toString()),
      limit: _toInt(json['limit']),
      entries: entriesRaw is List
          ? entriesRaw
                .whereType<Map>()
                .map(
                  (entry) => LeaderboardEntryDto.fromJson(
                    entry.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class RecomputeRewardsResponse {
  const RecomputeRewardsResponse({
    required this.rebuiltStats,
    required this.rebuiltEvents,
  });

  final int rebuiltStats;
  final int rebuiltEvents;

  factory RecomputeRewardsResponse.fromJson(Map<String, dynamic> json) {
    return RecomputeRewardsResponse(
      rebuiltStats: _toInt(json['rebuiltStats']),
      rebuiltEvents: _toInt(json['rebuiltEvents']),
    );
  }
}

class RewardsDashboard {
  const RewardsDashboard({required this.me, required this.leaderboard});

  final RewardsMeResponse me;
  final LeaderboardResponse leaderboard;
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String _toString(dynamic value, {String fallback = ''}) {
  return value?.toString() ?? fallback;
}

DateTime? _toDateTime(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}
