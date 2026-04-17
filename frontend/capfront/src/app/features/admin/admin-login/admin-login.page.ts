import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { finalize } from 'rxjs/operators';
import { fieldErrorMap, mapApiError } from '../../../core/models/api-error.model';
import { AuthService } from '../../../core/services/auth.service';

@Component({
  selector: 'app-admin-login-page',
  imports: [ReactiveFormsModule, MatButtonModule, MatCardModule, MatFormFieldModule, MatInputModule],
  templateUrl: './admin-login.page.html',
  styleUrl: './admin-login.page.css',
})
export class AdminLoginPageComponent {
  private readonly formBuilder = inject(FormBuilder);
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  readonly submitting = signal(false);
  readonly serverMessage = signal<string | null>(null);
  readonly errors = signal<Record<string, string>>({});

  readonly form = this.formBuilder.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]],
  });

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
          if (response.user.role !== 'ADMIN') {
            this.authService.logout();
            this.serverMessage.set('This account does not have admin access.');
            return;
          }

          const redirect = this.route.snapshot.queryParamMap.get('redirect');
          void this.router.navigateByUrl(redirect || '/admin');
        },
        error: (error: unknown) => {
          const apiError = mapApiError(error);
          this.serverMessage.set(apiError.message);
          this.errors.set(fieldErrorMap(apiError));
        },
      });
  }
}
