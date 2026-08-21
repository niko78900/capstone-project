// File purpose: Wraps Angular client-side service logic for auth service.
import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { API_BASE } from '../config/api.config';
import { AuthResponse, LoginRequest } from '../models/auth.model';
import { AuthSessionService } from './auth-session.service';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly session = inject(AuthSessionService);

  login(request: LoginRequest): Observable<AuthResponse> {
    return this.http
      .post<AuthResponse>(`${API_BASE}/auth/login`, request)
      .pipe(tap((response) => this.session.setFromAuthResponse(response)));
  }

  logout(): void {
    this.session.clear();
  }
}
