// File purpose: Controls Angular route access for auth guard.
import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthSessionService } from '../services/auth-session.service';

export const authGuard: CanActivateFn = (_route, state) => {
  const session = inject(AuthSessionService);
  const router = inject(Router);

  if (session.isAuthenticated()) {
    return true;
  }

  return router.createUrlTree(['/login'], {
    queryParams: {
      redirect: state.url,
      reason: 'authRequired',
    },
  });
};
