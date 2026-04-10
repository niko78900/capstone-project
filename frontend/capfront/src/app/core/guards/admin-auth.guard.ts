import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthSessionService } from '../services/auth-session.service';

export const adminAuthGuard: CanActivateFn = (_route, state) => {
  const session = inject(AuthSessionService);
  const router = inject(Router);

  if (session.isAdmin()) {
    return true;
  }

  return router.createUrlTree(['/admin/login'], {
    queryParams: { redirect: state.url },
  });
};
