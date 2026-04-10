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
          useValue: { isAdmin: () => true },
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
          useValue: { isAdmin: () => false },
        },
      ],
    });

    const result = TestBed.runInInjectionContext(() =>
      adminAuthGuard({} as never, { url: '/admin/submissions' } as never),
    );

    const router = TestBed.inject(Router);
    expect(router.serializeUrl(result as ReturnType<Router['createUrlTree']>)).toContain(
      '/admin/login',
    );
  });
});
