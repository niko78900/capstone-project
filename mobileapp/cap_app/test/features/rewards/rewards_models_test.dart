// File purpose: Covers Flutter tests for rewards models test behavior.
import 'package:cap_app/features/rewards/models/rewards_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rewards models', () {
    test('parse stats, recent events, and leaderboard entries', () {
      final me = RewardsMeResponse.fromJson({
        'stats': {
          'userId': 1,
          'email': 'tester@example.com',
          'approvedProductCount': 2,
          'approvedPriceCount': 3,
          'approvedNutritionCount': 1,
          'approvedTotalCount': 6,
          'rejectedCount': 1,
          'score': 42,
          'lastEventAt': '2026-05-12T10:00:00Z',
        },
        'recentEvents': [
          {
            'eventId': 9,
            'submissionId': 7,
            'submissionType': 'PRICE',
            'eventType': 'APPROVED_PRICE',
            'points': 5,
            'createdAt': '2026-05-13T10:00:00Z',
          },
        ],
      });

      final leaderboard = LeaderboardResponse.fromJson({
        'window': '30D',
        'limit': 50,
        'entries': [
          {
            'rank': 1,
            'userId': 1,
            'email': 'tester@example.com',
            'score': 42,
            'approvedCount': 6,
            'rejectedCount': 1,
            'lastEventAt': '2026-05-12T10:00:00Z',
          },
        ],
      });

      expect(me.stats.score, 42);
      expect(me.stats.approvedTotalCount, 6);
      expect(me.recentEvents.single.points, 5);
      expect(me.recentEvents.single.submissionType, 'PRICE');
      expect(leaderboard.window, RewardWindow.thirtyDays);
      expect(leaderboard.entries.single.rank, 1);
      expect(leaderboard.entries.single.email, 'tester@example.com');
    });
  });
}
