import { HttpErrorResponse } from '@angular/common/http';
import { Component, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { catchError, of } from 'rxjs';
import { finalize } from 'rxjs/operators';
import { fieldErrorMap, mapApiError } from '../../../core/models/api-error.model';
import { AuthService } from '../../../core/services/auth.service';
import { PasswordResetService } from '../../../core/services/password-reset.service';

type LoginMode = 'login' | 'requestReset' | 'pendingReset' | 'completeReset';

@Component({
  selector: 'app-admin-login-page',
  imports: [ReactiveFormsModule, MatButtonModule, MatCardModule, MatFormFieldModule, MatInputModule],
  templateUrl: './admin-login.page.html',
  styleUrl: './admin-login.page.css',
})
export class AdminLoginPageComponent {
  private readonly formBuilder = inject(FormBuilder);
  private readonly authService = inject(AuthService);
  private readonly passwordResetService = inject(PasswordResetService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly destroyRef = inject(DestroyRef);

  readonly submitting = signal(false);
  readonly resetSubmitting = signal(false);
  readonly checkingResetStatus = signal(false);
  readonly serverMessage = signal<string | null>(null);
  readonly noticeMessage = signal<string | null>(null);
  readonly errors = signal<Record<string, string>>({});
  readonly mode = signal<LoginMode>('login');
  readonly resetMessage = signal<string | null>(null);
  readonly resetError = signal<string | null>(null);

  readonly form = this.formBuilder.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]],
  });
  readonly resetRequestForm = this.formBuilder.group({
    email: ['', [Validators.required, Validators.email]],
  });
  readonly resetCompleteForm = this.formBuilder.group({
    email: ['', [Validators.required, Validators.email]],
    newPassword: ['', [Validators.required, Validators.minLength(8), Validators.maxLength(100)]],
    confirmPassword: ['', [Validators.required]],
  });

  constructor() {
    this.route.queryParamMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((params) => {
      const reason = params.get('reason');
      switch (reason) {
        case 'sessionExpired':
          this.noticeMessage.set('Your session expired. Please sign in again.');
          break;
        case 'forbidden':
          this.noticeMessage.set('You do not have permission to access that page.');
          break;
        case 'authRequired':
          this.noticeMessage.set('Please sign in to continue.');
          break;
        default:
          this.noticeMessage.set(null);
          break;
      }
    });
    this.checkStoredResetStatus(false);
  }

  submit(): void {
    if (this.form.invalid || this.submitting()) {
      this.form.markAllAsTouched();
      return;
    }

    this.submitting.set(true);
    this.serverMessage.set(null);
    this.errors.set({});

    const { email, password } = this.form.getRawValue();

    this.authService
      .login({
        email: email ?? '',
        password: password ?? '',
      })
      .pipe(finalize(() => this.submitting.set(false)))
      .subscribe({
        next: (response) => {
          const redirect = this.route.snapshot.queryParamMap.get('redirect');
          if (
            redirect?.startsWith('/admin') &&
            response.user.role !== 'ADMIN'
          ) {
            void this.router.navigateByUrl('/products');
            return;
          }

          const roleHome = response.user.role === 'ADMIN'
            ? '/admin/submissions'
            : '/products';
          void this.router.navigateByUrl(redirect || roleHome);
        },
        error: (error: unknown) => {
          const apiError = mapApiError(error);
          this.serverMessage.set(apiError.message);
          this.errors.set(fieldErrorMap(apiError));
        },
      });
  }

  showResetRequest(): void {
    this.serverMessage.set(null);
    this.resetError.set(null);
    this.resetMessage.set(null);
    const email = this.form.controls.email.value;
    if (email) {
      this.resetRequestForm.controls.email.setValue(email);
    }
    this.mode.set('requestReset');
  }

  showLogin(): void {
    this.resetError.set(null);
    this.resetMessage.set(null);
    this.mode.set('login');
  }

  submitResetRequest(): void {
    if (this.resetRequestForm.invalid || this.resetSubmitting()) {
      this.resetRequestForm.markAllAsTouched();
      return;
    }

    this.resetSubmitting.set(true);
    this.resetError.set(null);
    this.resetMessage.set(null);
    const email = this.resetRequestForm.controls.email.value ?? '';
    this.passwordResetService
      .requestReset(email)
      .pipe(finalize(() => this.resetSubmitting.set(false)))
      .subscribe({
        next: () => {
          this.resetMessage.set('Password reset request sent for admin review.');
          this.mode.set('pendingReset');
        },
        error: (error: unknown) => {
          this.resetError.set(mapApiError(error).message);
        },
      });
  }

  checkStoredResetStatus(showPendingMessage = true): void {
    const status$ = this.passwordResetService.checkStoredStatus();
    if (!status$ || this.checkingResetStatus()) {
      return;
    }

    this.checkingResetStatus.set(true);
    status$
      .pipe(
        catchError((error: unknown) => {
          this.resetError.set(mapApiError(error).message);
          if (error instanceof HttpErrorResponse && error.status === 404) {
            this.passwordResetService.clearStoredToken();
          }
          return of(null);
        }),
        finalize(() => this.checkingResetStatus.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((status) => {
        if (!status) {
          return;
        }
        if (status.status === 'APPROVED') {
          this.resetMessage.set('Your reset request was approved. Set a new password.');
          this.resetCompleteForm.patchValue({ email: status.email }, { emitEvent: false });
          this.mode.set('completeReset');
          return;
        }
        if (status.status === 'DENIED') {
          this.passwordResetService.clearStoredToken();
          this.noticeMessage.set('Your password reset request was denied by an admin.');
          this.mode.set('login');
          return;
        }
        if (status.status === 'COMPLETED' || status.status === 'EXPIRED') {
          this.passwordResetService.clearStoredToken();
          this.noticeMessage.set(
            status.status === 'EXPIRED'
              ? 'Your password reset request expired. Submit a new request if needed.'
              : 'Password reset completed. Please sign in.',
          );
          this.mode.set('login');
          return;
        }
        if (showPendingMessage) {
          this.resetMessage.set('Your reset request is still waiting for admin review.');
        }
        this.mode.set('pendingReset');
      });
  }

  submitNewPassword(): void {
    if (this.resetCompleteForm.invalid || this.resetSubmitting()) {
      this.resetCompleteForm.markAllAsTouched();
      return;
    }
    const { email, newPassword, confirmPassword } = this.resetCompleteForm.getRawValue();
    if (newPassword !== confirmPassword) {
      this.resetError.set('Passwords do not match.');
      return;
    }

    this.resetSubmitting.set(true);
    this.resetError.set(null);
    this.resetMessage.set(null);
    this.passwordResetService
      .completeStoredReset(email ?? '', newPassword ?? '')
      .pipe(finalize(() => this.resetSubmitting.set(false)))
      .subscribe({
        next: () => {
          this.noticeMessage.set('Password reset completed. Please sign in.');
          this.form.patchValue({ email: email ?? '', password: '' }, { emitEvent: false });
          this.mode.set('login');
        },
        error: (error: unknown) => {
          this.resetError.set(mapApiError(error).message);
        },
      });
  }
}
