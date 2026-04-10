import { Component, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatCardModule } from '@angular/material/card';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { catchError, filter, finalize, of, startWith, switchMap } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import { ModerationSubmissionDto, SubmissionStatus } from '../../../core/models/moderation.model';
import { ModerationService } from '../../../core/services/moderation.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { DecisionDialogComponent } from './decision-dialog.component';

@Component({
  selector: 'app-admin-submissions-page',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatButtonToggleModule,
    MatCardModule,
    MatSnackBarModule,
    EmptyStateComponent,
    LoadingStateComponent,
  ],
  templateUrl: './admin-submissions.page.html',
  styleUrl: './admin-submissions.page.css',
})
export class AdminSubmissionsPageComponent {
  private readonly moderationService = inject(ModerationService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly dialog = inject(MatDialog);
  private readonly snackBar = inject(MatSnackBar);

  readonly statusControl = new FormControl<SubmissionStatus>('PENDING', { nonNullable: true });
  readonly submissions = signal<ModerationSubmissionDto[]>([]);
  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);
  readonly processingSubmissionId = signal<number | null>(null);

  readonly statuses: SubmissionStatus[] = ['PENDING', 'APPROVED', 'REJECTED'];

  constructor() {
    this.statusControl.valueChanges
      .pipe(
        startWith(this.statusControl.value),
        switchMap((status) => this.loadSubmissions(status)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((submissions) => this.submissions.set(submissions));
  }

  displayDate(raw: string): string {
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return raw;
    }
    return date.toLocaleString();
  }

  formatPayload(payload: unknown): string {
    try {
      return JSON.stringify(payload, null, 2);
    } catch {
      return String(payload);
    }
  }

  onApprove(submission: ModerationSubmissionDto): void {
    this.openDecisionDialog('approve', submission);
  }

  onReject(submission: ModerationSubmissionDto): void {
    this.openDecisionDialog('reject', submission);
  }

  private loadSubmissions(status: SubmissionStatus) {
    this.loading.set(true);
    this.errorMessage.set(null);
    return this.moderationService.getSubmissions(status).pipe(
      catchError((error: unknown) => {
        const apiError = mapApiError(error);
        this.errorMessage.set(apiError.message);
        return of([]);
      }),
      finalize(() => this.loading.set(false)),
    );
  }

  private openDecisionDialog(mode: 'approve' | 'reject', submission: ModerationSubmissionDto): void {
    const dialogRef = this.dialog.open(DecisionDialogComponent, {
      width: '420px',
      data: { mode, submissionId: submission.id },
    });

    dialogRef
      .afterClosed()
      .pipe(
        filter((reason) => reason !== undefined),
        switchMap((reason) => {
          this.processingSubmissionId.set(submission.id);
          const request$ =
            mode === 'approve'
              ? this.moderationService.approve(submission.id, reason)
              : this.moderationService.reject(submission.id, reason);
          return request$.pipe(
            catchError((error: unknown) => {
              const apiError = mapApiError(error);
              this.snackBar.open(apiError.message, 'Dismiss', { duration: 4000 });
              return of(null);
            }),
            finalize(() => this.processingSubmissionId.set(null)),
          );
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((response) => {
        if (!response) {
          return;
        }
        const verb = response.action === 'APPROVED' ? 'approved' : 'rejected';
        this.snackBar.open(`Submission #${response.submissionId} ${verb}.`, 'Dismiss', {
          duration: 3000,
        });
        this.statusControl.setValue(this.statusControl.value, { emitEvent: true });
      });
  }
}
