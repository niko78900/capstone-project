// File purpose: Wraps Angular client-side service logic for moderation service.
import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { API_BASE } from '../config/api.config';
import {
  ModerationListQuery,
  ModerationSubmissionPage,
  ModerationSubmissionDetail,
  ModerationSubmissionDto,
  SubmissionDecisionRequest,
  SubmissionDecisionResponse,
  SubmissionHistoryResponse,
  SubmissionPayloadPatchRequest,
  SubmissionPayloadPatchResponse,
  SubmissionStatus,
} from '../models/moderation.model';

@Injectable({ providedIn: 'root' })
export class ModerationService {
  private readonly http = inject(HttpClient);

  listSubmissions(query: ModerationListQuery = {}): Observable<ModerationSubmissionPage> {
    let params = new HttpParams();
    if (query.status) {
      params = params.set('status', query.status);
    }
    if (query.type) {
      params = params.set('type', query.type);
    }
    if (query.q && query.q.trim().length > 0) {
      params = params.set('q', query.q.trim());
    }
    if (query.page != null) {
      params = params.set('page', String(query.page));
    }
    if (query.size != null) {
      params = params.set('size', String(query.size));
    }
    if (query.sort && query.sort.trim().length > 0) {
      params = params.set('sort', query.sort.trim());
    }
    return this.http.get<ModerationSubmissionPage>(`${API_BASE}/admin/submissions`, { params });
  }

  getSubmissions(status: SubmissionStatus): Observable<ModerationSubmissionDto[]> {
    return this.listSubmissions({ status }).pipe(map((page) => page.items));
  }

  countSubmissions(status: SubmissionStatus): Observable<number> {
    return this.listSubmissions({ status, page: 0, size: 1 }).pipe(
      map((page) => page.totalElements),
    );
  }

  getSubmission(submissionId: number): Observable<ModerationSubmissionDetail> {
    return this.http.get<ModerationSubmissionDetail>(
      `${API_BASE}/admin/submissions/${submissionId}`,
    );
  }

  patchSubmissionPayload(
    submissionId: number,
    request: SubmissionPayloadPatchRequest,
  ): Observable<SubmissionPayloadPatchResponse> {
    return this.http.patch<SubmissionPayloadPatchResponse>(
      `${API_BASE}/admin/submissions/${submissionId}/payload`,
      request,
    );
  }

  getSubmissionHistory(submissionId: number): Observable<SubmissionHistoryResponse> {
    return this.http.get<SubmissionHistoryResponse>(
      `${API_BASE}/admin/submissions/${submissionId}/history`,
    );
  }

  refreshAiReview(submissionId: number): Observable<ModerationSubmissionDetail['aiSummary']> {
    return this.http.post<ModerationSubmissionDetail['aiSummary']>(
      `${API_BASE}/admin/submissions/${submissionId}/ai-review`,
      {},
    );
  }

  approve(submissionId: number, reason?: string): Observable<SubmissionDecisionResponse> {
    const body: SubmissionDecisionRequest = reason ? { reason } : {};
    return this.http.post<SubmissionDecisionResponse>(
      `${API_BASE}/admin/submissions/${submissionId}/approve`,
      body,
    );
  }

  reject(
    submissionId: number,
    reason: string,
    rejectionSeverity: SubmissionDecisionRequest['rejectionSeverity'],
  ): Observable<SubmissionDecisionResponse> {
    const body: SubmissionDecisionRequest = { reason, rejectionSeverity };
    return this.http.post<SubmissionDecisionResponse>(
      `${API_BASE}/admin/submissions/${submissionId}/reject`,
      body,
    );
  }
}
