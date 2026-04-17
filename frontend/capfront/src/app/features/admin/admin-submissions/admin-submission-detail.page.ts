import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatDialog } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { catchError, filter, finalize, forkJoin, map, of, switchMap } from 'rxjs';
import { ProductDetailDto } from '../../../core/models/catalog.model';
import { mapApiError } from '../../../core/models/api-error.model';
import { ModerationSubmissionDto, SubmissionStatus } from '../../../core/models/moderation.model';
import { CatalogService } from '../../../core/services/catalog.service';
import { ModerationService } from '../../../core/services/moderation.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { PageHeaderComponent } from '../../../shared/components/page-header/page-header.component';
import { DecisionDialogComponent } from './decision-dialog.component';

interface FlattenedPayloadField {
  key: string;
  label: string;
  value: string;
}

interface QueueReturnParams {
  status: SubmissionStatus;
  q: string;
  type: string;
  sort: string;
}

@Component({
  selector: 'app-admin-submission-detail-page',
  imports: [
    RouterLink,
    MatButtonModule,
    MatCardModule,
    MatIconModule,
    MatSnackBarModule,
    EmptyStateComponent,
    LoadingStateComponent,
    PageHeaderComponent,
  ],
  templateUrl: './admin-submission-detail.page.html',
  styleUrl: './admin-submission-detail.page.css',
})
export class AdminSubmissionDetailPageComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly moderationService = inject(ModerationService);
  private readonly catalogService = inject(CatalogService);
  private readonly dialog = inject(MatDialog);
  private readonly snackBar = inject(MatSnackBar);
  private readonly destroyRef = inject(DestroyRef);

  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);
  readonly processingDecision = signal(false);
  readonly showJson = signal(false);
  readonly submission = signal<ModerationSubmissionDto | null>(null);
  readonly sourceProduct = signal<ProductDetailDto | null | undefined>(undefined);
  readonly submissionId = signal<number | null>(null);
  readonly returnQueryParams = signal<QueueReturnParams>({
    status: 'PENDING',
    q: '',
    type: 'ALL',
    sort: 'NEWEST',
  });

  readonly title = computed(() => {
    const submission = this.submission();
    if (!submission) {
      return 'Submission Review';
    }
    return `Ref ${this.submissionReference(submission)} • ${submission.type}`;
  });

  readonly subtitle = computed(() => {
    const submission = this.submission();
    if (!submission) {
      return 'Review and moderate this submission.';
    }
    return `${submission.submittedByEmail} • Created ${this.displayDate(submission.createdAt)}`;
  });

  readonly payloadFields = computed(() =>
    this.flattenPayload(this.submission()?.payload ?? null),
  );

  readonly imagePreviewUrl = computed(() => {
    const payload = this.asRecord(this.submission()?.payload);
    if (!payload) {
      return null;
    }
    const imageUrl = this.asText(payload['imageUrl'], '');
    return imageUrl.length > 0 ? imageUrl : null;
  });

  constructor() {
    this.route.queryParamMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((params) => {
      const statusRaw = (params.get('status') ?? 'PENDING').toUpperCase();
      const status =
        statusRaw === 'APPROVED' || statusRaw === 'REJECTED' || statusRaw === 'PENDING'
          ? statusRaw
          : 'PENDING';
      this.returnQueryParams.set({
        status,
        q: params.get('q') ?? '',
        type: params.get('type') ?? 'ALL',
        sort: params.get('sort') ?? 'NEWEST',
      });
    });

    this.route.paramMap
      .pipe(
        map((params) => Number(params.get('id'))),
        switchMap((id) => this.loadSubmission(id)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((submission) => {
        this.submission.set(submission);
        this.showJson.set(false);
        this.prefetchProductContext(submission);
      });
  }

  togglePayloadMode(): void {
    this.showJson.update((value) => !value);
  }

  formatPayload(payload: unknown): string {
    try {
      return JSON.stringify(payload, null, 2);
    } catch {
      return String(payload);
    }
  }

  displayDate(raw: string): string {
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return raw;
    }
    return date.toLocaleString();
  }

  submissionReference(submission: ModerationSubmissionDto): string {
    const typePrefix = this.typePrefix(submission.type);
    const dateKey = this.dateKey(submission.createdAt);
    const compactId = this.compactId(submission.id);
    return `${typePrefix}-${dateKey}-${compactId}`;
  }

  statusChipClass(status: SubmissionStatus): string {
    switch (status) {
      case 'APPROVED':
        return 'status-approved';
      case 'REJECTED':
        return 'status-rejected';
      case 'PENDING':
      default:
        return 'status-pending';
    }
  }

  onApprove(): void {
    const submission = this.submission();
    if (!submission || submission.status !== 'PENDING') {
      return;
    }
    this.openDecisionDialog('approve', submission);
  }

  onReject(): void {
    const submission = this.submission();
    if (!submission || submission.status !== 'PENDING') {
      return;
    }
    this.openDecisionDialog('reject', submission);
  }

  private openDecisionDialog(mode: 'approve' | 'reject', submission: ModerationSubmissionDto): void {
    const dialogRef = this.dialog.open(DecisionDialogComponent, {
      width: '420px',
      data: {
        mode,
        submissionId: submission.id,
        submissionRef: this.submissionReference(submission),
        title: mode === 'approve' ? 'Approve Submission' : 'Reject Submission',
      },
    });

    dialogRef
      .afterClosed()
      .pipe(
        filter((reason) => reason !== undefined),
        switchMap((reason) => {
          this.processingDecision.set(true);
          const request$ =
            mode === 'approve'
              ? this.moderationService.approve(submission.id, reason)
              : this.moderationService.reject(submission.id, reason);

          return request$.pipe(
            catchError((error: unknown) => {
              const apiError = mapApiError(error);
              this.snackBar.open(apiError.message, 'Dismiss', { duration: 4200 });
              return of(null);
            }),
            finalize(() => this.processingDecision.set(false)),
          );
        }),
        switchMap((result) => {
          if (!result) {
            return of(null);
          }
          const actionText = result.action === 'APPROVED' ? 'approved' : 'rejected';
          this.snackBar.open(`Submission ${this.submissionReference(submission)} ${actionText}.`, 'Dismiss', {
            duration: 2800,
          });

          const id = this.submissionId();
          if (id == null) {
            return of(null);
          }
          return this.loadSubmission(id);
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((updatedSubmission) => {
        if (updatedSubmission) {
          this.submission.set(updatedSubmission);
        }
      });
  }

  private loadSubmission(id: number) {
    if (!Number.isFinite(id) || id < 1) {
      this.loading.set(false);
      this.errorMessage.set('Invalid submission id.');
      this.submissionId.set(null);
      return of(null);
    }

    this.loading.set(true);
    this.errorMessage.set(null);
    this.submissionId.set(id);

    return forkJoin({
      pending: this.moderationService.getSubmissions('PENDING'),
      approved: this.moderationService.getSubmissions('APPROVED'),
      rejected: this.moderationService.getSubmissions('REJECTED'),
    }).pipe(
      map(({ pending, approved, rejected }) => [...pending, ...approved, ...rejected]),
      map((submissions) => submissions.find((submission) => submission.id === id) ?? null),
      catchError((error: unknown) => {
        const apiError = mapApiError(error);
        this.errorMessage.set(apiError.message);
        return of(null);
      }),
      map((submission) => {
        if (!submission && !this.errorMessage()) {
          this.errorMessage.set('Submission not found.');
        }
        return submission;
      }),
      finalize(() => this.loading.set(false)),
    );
  }

  private prefetchProductContext(submission: ModerationSubmissionDto | null): void {
    if (!submission) {
      this.sourceProduct.set(undefined);
      return;
    }

    const productId = this.referenceProductId(submission);
    if (productId == null || productId < 1) {
      this.sourceProduct.set(undefined);
      return;
    }

    this.sourceProduct.set(undefined);
    this.catalogService
      .getProductDetail(productId)
      .pipe(
        catchError(() => of(null)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((detail) => this.sourceProduct.set(detail));
  }

  private referenceProductId(submission: ModerationSubmissionDto): number | null {
    const payload = this.asRecord(submission.payload);
    if (!payload) {
      return null;
    }

    if (submission.type === 'PRODUCT') {
      return this.asNumber(payload['sourceProductId']);
    }

    if (submission.type === 'PRICE' || submission.type === 'NUTRITION') {
      return this.asNumber(payload['productId']);
    }

    return null;
  }

  private flattenPayload(payload: unknown): FlattenedPayloadField[] {
    const fields: FlattenedPayloadField[] = [];

    const walk = (value: unknown, path: string): void => {
      if (value == null) {
        fields.push({ key: path, label: this.toFieldLabel(path), value: '-' });
        return;
      }

      if (Array.isArray(value)) {
        if (value.length === 0) {
          fields.push({ key: path, label: this.toFieldLabel(path), value: '[]' });
          return;
        }

        value.forEach((entry, index) => {
          walk(entry, `${path}[${index}]`);
        });
        return;
      }

      if (typeof value === 'object') {
        const entries = Object.entries(value as Record<string, unknown>);
        if (entries.length === 0) {
          fields.push({ key: path, label: this.toFieldLabel(path), value: '{}' });
          return;
        }

        for (const [childKey, childValue] of entries) {
          const childPath = path ? `${path}.${childKey}` : childKey;
          walk(childValue, childPath);
        }
        return;
      }

      fields.push({
        key: path,
        label: this.toFieldLabel(path),
        value: String(value),
      });
    };

    walk(payload, '');
    return fields;
  }

  private toFieldLabel(path: string): string {
    const normalized = path.length > 0 ? path : 'payload';
    return normalized
      .replaceAll('.', ' / ')
      .replaceAll('_', ' ')
      .replaceAll(/\[(\d+)\]/g, ' [$1]')
      .replace(/\b\w/g, (letter) => letter.toUpperCase());
  }

  private asRecord(value: unknown): Record<string, unknown> | null {
    if (value == null || Array.isArray(value) || typeof value !== 'object') {
      return null;
    }
    return value as Record<string, unknown>;
  }

  private asText(value: unknown, fallback: string): string {
    if (typeof value !== 'string') {
      return fallback;
    }
    const text = value.trim();
    return text.length > 0 ? text : fallback;
  }

  private asNumber(value: unknown): number | null {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === 'string' && value.trim().length > 0) {
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : null;
    }
    return null;
  }

  private typePrefix(type: ModerationSubmissionDto['type']): string {
    switch (type) {
      case 'PRODUCT':
        return 'PRD';
      case 'PRICE':
        return 'PRC';
      case 'NUTRITION':
        return 'NTR';
      default:
        return 'SUB';
    }
  }

  private dateKey(raw: string): string {
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return '00000000';
    }
    const year = String(date.getFullYear()).padStart(4, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}${month}${day}`;
  }

  private compactId(id: number): string {
    const safe = Number.isFinite(id) && id > 0 ? Math.floor(id) : 0;
    return safe.toString(36).toUpperCase().padStart(4, '0');
  }
}
