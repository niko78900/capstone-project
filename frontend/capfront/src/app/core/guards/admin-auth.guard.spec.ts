import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { adminAuthGuard } from './admin-auth.guard';
import { AuthSessionService } from '../services/auth-session.service';

describe('adminAuthGuard', () => {
  it('allows access when current user is admin', () => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        {
          provide: AuthSessionService,
          useValue: { isAdmin: () => true, isAuthenticated: () => true },
        },
      ],
    });

    const result = TestBed.runInInjectionContext(() =>
      adminAuthGuard({} as never, { url: '/admin/submissions' } as never),
    );
    expect(result).toBeTrue();
  });

  it('redirects non-admin users to login route', () => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        {
          provide: AuthSessionService,
          useValue: { isAdmin: () => false, isAuthenticated: () => true },
        },
      ],
    });

    const result = TestBed.runInInjectionContext(() =>
      adminAuthGuard({} as never, { url: '/admin/submissions' } as never),
    );

    const router = TestBed.inject(Router);
    const serialized = router.serializeUrl(result as ReturnType<Router['createUrlTree']>);
    expect(serialized).toContain('/login');
    expect(serialized).toContain('reason=forbidden');
  });

  it('redirects unauthenticated users with authRequired reason', () => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        {
          provide: AuthSessionService,
          useValue: { isAdmin: () => false, isAuthenticated: () => false },
        },
      ],
    });

    const result = TestBed.runInInjectionContext(() =>
      adminAuthGuard({} as never, { url: '/admin' } as never),
    );

    const router = TestBed.inject(Router);
    const serialized = router.serializeUrl(result as ReturnType<Router['createUrlTree']>);
    expect(serialized).toContain('/login');
    expect(serialized).toContain('reason=authRequired');
  });
});
