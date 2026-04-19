import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { authGuard } from './auth.guard';
import { AuthSessionService } from '../services/auth-session.service';

describe('authGuard', () => {
  it('allows access when authenticated', () => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        {
          provide: AuthSessionService,
          useValue: { isAuthenticated: () => true },
        },
      ],
    });

    const result = TestBed.runInInjectionContext(() =>
      authGuard({} as never, { url: '/rewards' } as never),
    );
    expect(result).toBeTrue();
  });

  it('redirects guests to /login with authRequired reason', () => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        {
          provide: AuthSessionService,
          useValue: { isAuthenticated: () => false },
        },
      ],
    });

    const result = TestBed.runInInjectionContext(() =>
      authGuard({} as never, { url: '/rewards' } as never),
    );

    const router = TestBed.inject(Router);
    const serialized = router.serializeUrl(result as ReturnType<Router['createUrlTree']>);
    expect(serialized).toContain('/login');
    expect(serialized).toContain('reason=authRequired');
    expect(serialized).toContain('redirect=%2Frewards');
  });
});
