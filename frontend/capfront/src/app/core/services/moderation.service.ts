import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { API_BASE } from '../config/api.config';
import {
  ModerationSubmissionDto,
  SubmissionDecisionRequest,
  SubmissionDecisionResponse,
  SubmissionStatus,
} from '../models/moderation.model';

@Injectable({ providedIn: 'root' })
export class ModerationService {
  private readonly http = inject(HttpClient);

  getSubmissions(status: SubmissionStatus): Observable<ModerationSubmissionDto[]> {
    const params = new HttpParams().set('status', status);
    return this.http.get<ModerationSubmissionDto[]>(`${API_BASE}/admin/submissions`, { params });
  }

  approve(submissionId: number, reason?: string): Observable<SubmissionDecisionResponse> {
    const body: SubmissionDecisionRequest = reason ? { reason } : {};
    return this.http.post<SubmissionDecisionResponse>(
      `${API_BASE}/admin/submissions/${submissionId}/approve`,
      body,
    );
  }

  reject(submissionId: number, reason?: string): Observable<SubmissionDecisionResponse> {
    const body: SubmissionDecisionRequest = reason ? { reason } : {};
    return this.http.post<SubmissionDecisionResponse>(
      `${API_BASE}/admin/submissions/${submissionId}/reject`,
      body,
    );
  }
}
