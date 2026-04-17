import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { AuthSessionService } from '../services/auth-session.service';

export const authInterceptor: HttpInterceptorFn = (request, next) => {
  const session = inject(AuthSessionService);
  const router = inject(Router);

  const token = session.token;
  const isAuthLoginRequest = request.url.includes('/auth/login');
  const withAuth = token
    ? request.clone({
        setHeaders: {
          Authorization: `Bearer ${token}`,
        },
      })
    : request;

  return next(withAuth).pipe(
    catchError((error: unknown) => {
      if (error instanceof HttpErrorResponse && error.status === 401 && !isAuthLoginRequest) {
        session.clear();
        if (router.url.startsWith('/admin')) {
          void router.navigate(['/admin/login'], {
            queryParams: {
              reason: 'sessionExpired',
              redirect: router.url,
            },
          });
        }
      }
      return throwError(() => error);
    }),
  );
};
