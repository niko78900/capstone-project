import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { API_BASE } from '../config/api.config';
import {
  LeaderboardResponse,
  RecomputeRewardsResponse,
  RewardsMeResponse,
  RewardWindow,
} from '../models/rewards.model';

@Injectable({ providedIn: 'root' })
export class RewardsService {
  private readonly http = inject(HttpClient);

  getMe(): Observable<RewardsMeResponse> {
    return this.http.get<RewardsMeResponse>(`${API_BASE}/rewards/me`);
  }

  getLeaderboard(window: RewardWindow = 'ALL_TIME', limit = 50): Observable<LeaderboardResponse> {
    const params = new HttpParams()
      .set('window', window)
      .set('limit', String(limit));
    return this.http.get<LeaderboardResponse>(`${API_BASE}/rewards/leaderboard`, { params });
  }

  recompute(): Observable<RecomputeRewardsResponse> {
    return this.http.post<RecomputeRewardsResponse>(`${API_BASE}/admin/rewards/recompute`, {});
  }
}
