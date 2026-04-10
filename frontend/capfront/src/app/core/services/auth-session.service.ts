import { Injectable, computed, signal } from '@angular/core';
import { AuthResponse, AuthSession } from '../models/auth.model';

const SESSION_STORAGE_KEY = 'capfront_auth_session';

@Injectable({ providedIn: 'root' })
export class AuthSessionService {
  private readonly sessionSignal = signal<AuthSession | null>(this.readFromStorage());

  readonly session = computed(() => this.sessionSignal());
  readonly isAuthenticated = computed(() => this.sessionSignal() !== null);
  readonly isAdmin = computed(() => this.sessionSignal()?.user.role === 'ADMIN');

  get token(): string | null {
    return this.sessionSignal()?.accessToken ?? null;
  }

  setFromAuthResponse(response: AuthResponse): void {
    const next: AuthSession = {
      accessToken: response.accessToken,
      user: response.user,
    };
    this.sessionSignal.set(next);
    this.writeToStorage(next);
  }

  clear(): void {
    this.sessionSignal.set(null);
    localStorage.removeItem(SESSION_STORAGE_KEY);
  }

  private readFromStorage(): AuthSession | null {
    const raw = localStorage.getItem(SESSION_STORAGE_KEY);
    if (!raw) {
      return null;
    }

    try {
      const parsed = JSON.parse(raw) as Partial<AuthSession>;
      if (
        typeof parsed.accessToken !== 'string' ||
        parsed.user == null ||
        typeof parsed.user.id !== 'number' ||
        typeof parsed.user.email !== 'string' ||
        typeof parsed.user.displayName !== 'string' ||
        (parsed.user.role !== 'ADMIN' && parsed.user.role !== 'USER')
      ) {
        return null;
      }
      return {
        accessToken: parsed.accessToken,
        user: parsed.user,
      };
    } catch {
      return null;
    }
  }

  private writeToStorage(session: AuthSession): void {
    localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
  }
}
