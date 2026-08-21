// File purpose: Wraps Angular client-side service logic for password reset service.
import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { API_BASE } from '../config/api.config';
import {
  AdminPasswordResetPageResponse,
  AdminPasswordResetRequestDto,
  PasswordResetCompleteResponse,
  PasswordResetRequestCreateResponse,
  PasswordResetStatus,
  PasswordResetStatusResponse,
} from '../models/password-reset.model';

const PASSWORD_RESET_TOKEN_KEY = 'capfront_password_reset_token';

@Injectable({ providedIn: 'root' })
export class PasswordResetService {
  private readonly http = inject(HttpClient);

  requestReset(email: string): Observable<PasswordResetRequestCreateResponse> {
    return this.http
      .post<PasswordResetRequestCreateResponse>(`${API_BASE}/auth/password-reset-requests`, {
        email,
      })
      .pipe(tap((response) => this.storeToken(response.requestToken)));
  }

  checkStoredStatus(): Observable<PasswordResetStatusResponse> | null {
    const token = this.getStoredToken();
    if (!token) {
      return null;
    }
    return this.getStatus(token);
  }

  getStatus(token: string): Observable<PasswordResetStatusResponse> {
    return this.http.get<PasswordResetStatusResponse>(
      `${API_BASE}/auth/password-reset-requests/${encodeURIComponent(token)}/status`,
    );
  }

  completeStoredReset(
    email: string,
    newPassword: string,
  ): Observable<PasswordResetCompleteResponse> {
    const token = this.getStoredToken();
    if (!token) {
      throw new Error('No password reset request is stored in this browser.');
    }
    return this.http
      .post<PasswordResetCompleteResponse>(
        `${API_BASE}/auth/password-reset-requests/${encodeURIComponent(token)}/complete`,
        { email, newPassword },
      )
      .pipe(tap(() => this.clearStoredToken()));
  }

  listAdminRequests(
    query: {
      status?: PasswordResetStatus;
      page?: number;
      size?: number;
    } = {},
  ): Observable<AdminPasswordResetPageResponse> {
    let params = new HttpParams();
    if (query.status) {
      params = params.set('status', query.status);
    }
    if (query.page != null) {
      params = params.set('page', String(query.page));
    }
    if (query.size != null) {
      params = params.set('size', String(query.size));
    }
    return this.http.get<AdminPasswordResetPageResponse>(
      `${API_BASE}/admin/users/password-reset-requests`,
      { params },
    );
  }

  approveAdminRequest(id: number, reason?: string): Observable<AdminPasswordResetRequestDto> {
    return this.http.post<AdminPasswordResetRequestDto>(
      `${API_BASE}/admin/users/password-reset-requests/${id}/approve`,
      reason ? { reason } : {},
    );
  }

  denyAdminRequest(id: number, reason?: string): Observable<AdminPasswordResetRequestDto> {
    return this.http.post<AdminPasswordResetRequestDto>(
      `${API_BASE}/admin/users/password-reset-requests/${id}/deny`,
      reason ? { reason } : {},
    );
  }

  getStoredToken(): string | null {
    const raw = localStorage.getItem(PASSWORD_RESET_TOKEN_KEY);
    const token = raw?.trim();
    return token ? token : null;
  }

  clearStoredToken(): void {
    localStorage.removeItem(PASSWORD_RESET_TOKEN_KEY);
  }

  private storeToken(token: string): void {
    localStorage.setItem(PASSWORD_RESET_TOKEN_KEY, token);
  }
}
