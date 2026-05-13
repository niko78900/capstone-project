import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { catchError, finalize, of, startWith } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import {
  AdminPasswordResetRequestDto,
  PasswordResetStatus,
} from '../../../core/models/password-reset.model';
import { PasswordResetService } from '../../../core/services/password-reset.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { PageHeaderComponent } from '../../../shared/components/page-header/page-header.component';

type ResetStatusFilter = 'ALL' | PasswordResetStatus;

@Component({
  selector: 'app-admin-users-page',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatCardModule,
    MatFormFieldModule,
    MatSelectModule,
    MatSnackBarModule,
    EmptyStateComponent,
    LoadingStateComponent,
    PageHeaderComponent,
  ],
  templateUrl: './admin-users.page.html',
  styleUrl: './admin-users.page.css',
})
export class AdminUsersPageComponent {
  private readonly passwordResetService = inject(PasswordResetService);
  private readonly snackBar = inject(MatSnackBar);
  private readonly destroyRef = inject(DestroyRef);

  readonly statusControl = new FormControl<ResetStatusFilter>('PENDING', { nonNullable: true });
  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);
  readonly requests = signal<AdminPasswordResetRequestDto[]>([]);
  readonly totalResults = signal(0);
  readonly processingId = signal<number | null>(null);

  readonly statuses: ResetStatusFilter[] = [
    'PENDING',
    'APPROVED',
    'DENIED',
    'COMPLETED',
    'EXPIRED',
    'ALL',
  ];
  readonly pendingCount = computed(
    () => this.requests().filter((request) => request.status === 'PENDING').length,
  );

  constructor() {
    this.statusControl.valueChanges
      .pipe(startWith(this.statusControl.value), takeUntilDestroyed(this.destroyRef))
      .subscribe(() => this.loadRequests());
  }

  refresh(): void {
    this.loadRequests();
  }

  approve(request: AdminPasswordResetRequestDto): void {
    if (!this.canDecide(request) || this.processingId() !== null) {
      return;
    }
    this.processingId.set(request.id);
    this.passwordResetService
      .approveAdminRequest(request.id)
      .pipe(
        catchError((error: unknown) => {
          this.snackBar.open(mapApiError(error).message, 'Dismiss', { duration: 4200 });
          return of(null);
        }),
        finalize(() => this.processingId.set(null)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((result) => {
        if (!result) {
          return;
        }
        this.snackBar.open('Password reset request approved.', 'Dismiss', { duration: 2600 });
        this.loadRequests();
      });
  }

  deny(request: AdminPasswordResetRequestDto): void {
    if (!this.canDecide(request) || this.processingId() !== null) {
      return;
    }
    this.processingId.set(request.id);
    this.passwordResetService
      .denyAdminRequest(request.id)
      .pipe(
        catchError((error: unknown) => {
          this.snackBar.open(mapApiError(error).message, 'Dismiss', { duration: 4200 });
          return of(null);
        }),
        finalize(() => this.processingId.set(null)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((result) => {
        if (!result) {
          return;
        }
        this.snackBar.open('Password reset request denied.', 'Dismiss', { duration: 2600 });
        this.loadRequests();
      });
  }

  canDecide(request: AdminPasswordResetRequestDto): boolean {
    return request.status === 'PENDING';
  }

  displayDate(raw: string | null): string {
    if (!raw) {
      return '-';
    }
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return raw;
    }
    return date.toLocaleString();
  }

  matchedUserLabel(request: AdminPasswordResetRequestDto): string {
    if (request.matchedUserId == null) {
      return 'No matching user';
    }
    const name = request.matchedUserDisplayName ?? 'User';
    return `${name} (#${request.matchedUserId})`;
  }

  statusLabel(status: ResetStatusFilter): string {
    return status === 'ALL' ? 'All statuses' : status.charAt(0) + status.slice(1).toLowerCase();
  }

  private loadRequests(): void {
    this.loading.set(true);
    this.errorMessage.set(null);
    const status = this.statusControl.value === 'ALL' ? undefined : this.statusControl.value;
    this.passwordResetService
      .listAdminRequests({ status, page: 0, size: 50 })
      .pipe(
        catchError((error: unknown) => {
          this.errorMessage.set(mapApiError(error).message);
          return of({
            items: [],
            totalElements: 0,
            page: 0,
            size: 50,
            totalPages: 0,
          });
        }),
        finalize(() => this.loading.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((page) => {
        this.requests.set(page.items);
        this.totalResults.set(page.totalElements);
      });
  }
}
