// File purpose: Defines Angular TypeScript models for rewards model.
import { SubmissionType } from './moderation.model';

export type RewardWindow = 'ALL_TIME' | '30D';

export interface ContributorStatsDto {
  userId: number;
  email: string;
  approvedProductCount: number;
  approvedPriceCount: number;
  approvedNutritionCount: number;
  approvedTotalCount: number;
  rejectedCount: number;
  score: number;
  lastEventAt: string | null;
}

export interface ContributorScoreEventDto {
  eventId: number;
  submissionId: number;
  submissionType: SubmissionType;
  eventType: string;
  points: number;
  createdAt: string;
}

export interface RewardsMeResponse {
  stats: ContributorStatsDto;
  recentEvents: ContributorScoreEventDto[];
}

export interface LeaderboardEntryDto {
  rank: number;
  userId: number;
  email: string;
  score: number;
  approvedCount: number;
  rejectedCount: number;
  lastEventAt: string | null;
}

export interface LeaderboardResponse {
  window: RewardWindow | string;
  limit: number;
  entries: LeaderboardEntryDto[];
}

export interface RecomputeRewardsResponse {
  rebuiltStats: number;
  rebuiltEvents: number;
}
