import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatDialog } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { catchError, filter, finalize, map, of, switchMap } from 'rxjs';
import { ProductDetailDto, SupermarketDto } from '../../../core/models/catalog.model';
import { fieldErrorMap, mapApiError } from '../../../core/models/api-error.model';
import {
  ModerationSubmissionDetail,
  SubmissionHistoryEntry,
  SubmissionStatus,
  SubmissionType,
} from '../../../core/models/moderation.model';
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

interface PatchFieldErrorEntry {
  field: string;
  message: string;
}

interface QueueReturnParams {
  status: SubmissionStatus;
  q: string;
  type: string;
  sort: string;
  page: number;
  size: number;
}

const CATEGORY_NAMES: Record<number, string> = {
  1: 'Fruits and Vegetables',
  2: 'Bakery',
  3: 'Dairy and Eggs',
  4: 'Meat and Fish',
  5: 'Pasta and Rice',
  6: 'Canned and Jarred',
  7: 'Snacks',
  8: 'Beverages',
  9: 'Frozen',
  10: 'Household',
};

@Component({
  selector: 'app-admin-submission-detail-page',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatCardModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatSelectModule,
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
  private readonly formBuilder = inject(FormBuilder);

  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);
  readonly processingDecision = signal(false);
  readonly patching = signal(false);
  readonly showJson = signal(false);
  readonly historyLoading = signal(false);
  readonly historyError = signal<string | null>(null);
  readonly aiRefreshing = signal(false);
  readonly patchMessage = signal<string | null>(null);
  readonly patchFieldErrors = signal<Record<string, string>>({});
  readonly submission = signal<ModerationSubmissionDetail | null>(null);
  readonly sourceProduct = signal<ProductDetailDto | null | undefined>(undefined);
  readonly submissionHistory = signal<SubmissionHistoryEntry[]>([]);
  readonly supermarkets = signal<SupermarketDto[]>([]);
  readonly submissionId = signal<number | null>(null);
  readonly returnQueryParams = signal<QueueReturnParams>({
    status: 'PENDING',
    q: '',
    type: 'ALL',
    sort: 'NEWEST',
    page: 0,
    size: 10,
  });

  readonly categoryOptions = Object.entries(CATEGORY_NAMES).map(([id, name]) => ({
    id: Number(id),
    name,
  }));

  readonly editForm = this.formBuilder.group({
    editReason: ['', [Validators.maxLength(1000)]],
    categoryId: [null as number | null],
    sourceProductId: [null as number | null],
    name: [''],
    brand: [''],
    barcode: [''],
    supermarketId: [null as number | null],
    price: [null as number | null],
    imageUrl: [''],
    productId: [null as number | null],
    branchId: [null as number | null],
    available: [null as boolean | null],
    observedAt: [''],
    calories: [null as number | null],
    proteinG: [null as number | null],
    carbsG: [null as number | null],
    fatG: [null as number | null],
    servingSize: ['100 g'],
  });

  readonly title = computed(() => {
    const submission = this.submission();
    if (!submission) {
      return 'Submission Review';
    }
    return `Ref ${this.submissionReference(submission)} - ${submission.type}`;
  });

  readonly subtitle = computed(() => {
    const submission = this.submission();
    if (!submission) {
      return 'Review and moderate this submission.';
    }
    return `${submission.submittedByEmail} - Created ${this.displayDate(submission.createdAt)}`;
  });

  readonly payloadFields = computed(() => this.flattenPayload(this.submission()?.payload ?? null));
  readonly canEditPayload = computed(() => this.submission()?.status === 'PENDING');
  readonly isProductType = computed(() => this.submission()?.type === 'PRODUCT');
  readonly isPriceType = computed(() => this.submission()?.type === 'PRICE');
  readonly isNutritionType = computed(() => this.submission()?.type === 'NUTRITION');
  readonly isAvailabilityType = computed(() => this.submission()?.type === 'AVAILABILITY');

  readonly imagePreviewUrl = computed(() => {
    const payload = this.asRecord(this.submission()?.payload);
    if (!payload) {
      return null;
    }
    const imageUrl = this.asText(payload['imageUrl'], '');
    return imageUrl.length > 0 ? imageUrl : null;
  });

  constructor() {
    this.loadSupermarkets();

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
        page: Number(params.get('page') ?? '0') || 0,
        size: Number(params.get('size') ?? '10') || 10,
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
        this.patchMessage.set(null);
        this.patchFieldErrors.set({});
        this.prefetchProductContext(submission);
        this.populateEditForm(submission);
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

  submissionReference(submission: ModerationSubmissionDetail): string {
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

  fieldError(field: string): string | null {
    return this.patchFieldErrors()[field] ?? null;
  }

  patchFieldErrorEntries(): PatchFieldErrorEntry[] {
    return Object.entries(this.patchFieldErrors()).map(([field, message]) => ({
      field,
      message,
    }));
  }

  historyLabel(entry: SubmissionHistoryEntry): string {
    return entry.kind === 'EDIT' ? 'Payload edit' : 'Moderation decision';
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

  onRefreshAiReview(): void {
    const submission = this.submission();
    if (!submission || submission.status !== 'PENDING' || this.aiRefreshing()) {
      return;
    }

    this.aiRefreshing.set(true);
    this.moderationService
      .refreshAiReview(submission.id)
      .pipe(
        catchError((error: unknown) => {
          const apiError = mapApiError(error);
          this.snackBar.open(apiError.message, 'Dismiss', { duration: 3600 });
          return of(null);
        }),
        finalize(() => this.aiRefreshing.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((summary) => {
        if (!summary) {
          return;
        }
        this.submission.update((current) => (current ? { ...current, aiSummary: summary } : current));
        this.snackBar.open('AI moderation hints refreshed.', 'Dismiss', { duration: 2600 });
      });
  }

  onPatchPayload(): void {
    const submission = this.submission();
    if (!submission || submission.status !== 'PENDING' || this.patching()) {
      return;
    }

    const validationError = this.validateEditForm(submission.type);
    if (validationError) {
      this.patchMessage.set(validationError);
      return;
    }

    const payload = this.buildPatchedPayload(submission.type);
    if (!payload) {
      this.patchMessage.set('Unable to build payload for submission patch.');
      return;
    }

    const editReason = this.trimToNull(this.editForm.controls.editReason.value ?? '');
    this.patching.set(true);
    this.patchMessage.set(null);
    this.patchFieldErrors.set({});

    this.moderationService
      .patchSubmissionPayload(submission.id, {
        payload,
        editReason,
        expectedUpdatedAt: submission.updatedAt,
      })
      .pipe(
        catchError((error: unknown) => {
          const apiError = mapApiError(error);
          this.patchFieldErrors.set(fieldErrorMap(apiError));
          if (apiError.status === 409) {
            this.patchMessage.set(
              'Submission was updated by another moderator. Reloaded latest version.',
            );
            this.reloadSubmission();
          } else {
            this.patchMessage.set(apiError.message);
          }
          return of(null);
        }),
        finalize(() => this.patching.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((result) => {
        if (!result) {
          return;
        }
        this.submission.set(result.submission);
        this.populateEditForm(result.submission);
        this.patchMessage.set(`Patch saved (${result.changedFieldCount} changed field(s)).`);
        this.loadHistory(result.submission.id);
      });
  }

  private openDecisionDialog(
    mode: 'approve' | 'reject',
    submission: ModerationSubmissionDetail,
  ): void {
    const dialogRef = this.dialog.open(DecisionDialogComponent, {
      width: '420px',
      panelClass: 'decision-dialog-panel',
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
          this.snackBar.open(
            `Submission ${this.submissionReference(submission)} ${actionText}.`,
            'Dismiss',
            { duration: 2800 },
          );

          return this.reloadSubmission();
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe();
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

    return this.moderationService.getSubmission(id).pipe(
      catchError((error: unknown) => {
        const apiError = mapApiError(error);
        this.errorMessage.set(apiError.message);
        return of(null);
      }),
      switchMap((submission) => {
        if (!submission) {
          return of(null);
        }
        this.loadHistory(submission.id);
        return of(submission);
      }),
      finalize(() => this.loading.set(false)),
    );
  }

  private reloadSubmission() {
    const id = this.submissionId();
    if (id == null) {
      return of(null);
    }
    return this.loadSubmission(id).pipe(
      map((submission) => {
        this.submission.set(submission);
        this.prefetchProductContext(submission);
        this.populateEditForm(submission);
        return submission;
      }),
    );
  }

  private loadHistory(submissionId: number): void {
    this.historyLoading.set(true);
    this.historyError.set(null);
    this.moderationService
      .getSubmissionHistory(submissionId)
      .pipe(
        catchError((error: unknown) => {
          const apiError = mapApiError(error);
          this.historyError.set(apiError.message);
          return of({ submissionId, entries: [] });
        }),
        finalize(() => this.historyLoading.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((history) => {
        this.submissionHistory.set(history.entries);
      });
  }

  private loadSupermarkets(): void {
    this.catalogService
      .getSupermarkets()
      .pipe(
        catchError(() => of([])),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((rows) => this.supermarkets.set(rows));
  }

  private populateEditForm(submission: ModerationSubmissionDetail | null): void {
    if (!submission) {
      this.editForm.reset();
      return;
    }

    const payload = this.asRecord(submission.payload) ?? {};
    const nutrition = this.asRecord(payload['nutrition']);

    this.editForm.patchValue(
      {
        editReason: '',
        categoryId: this.asNumber(payload['categoryId']),
        sourceProductId: this.asNumber(payload['sourceProductId']),
        name: this.asText(payload['name'], ''),
        brand: this.asText(payload['brand'], ''),
        barcode: this.asText(payload['barcode'], ''),
        supermarketId: this.asNumber(payload['supermarketId']),
        price: this.asNumber(payload['price']),
        imageUrl: this.asText(payload['imageUrl'], ''),
        productId: this.asNumber(payload['productId']),
        branchId: this.asNumber(payload['branchId']),
        available: this.asBoolean(payload['available']),
        observedAt: this.toDateInputValue(this.asText(payload['observedAt'], '')),
        calories: this.asNumber(nutrition?.['calories']),
        proteinG: this.asNumber(nutrition?.['proteinG']),
        carbsG: this.asNumber(nutrition?.['carbsG']),
        fatG: this.asNumber(nutrition?.['fatG']),
        servingSize: this.asText(nutrition?.['servingSize'], '100 g'),
      },
      { emitEvent: false },
    );
  }

  private validateEditForm(type: SubmissionType): string | null {
    const controls = this.editForm.controls;
    if (type === 'PRODUCT') {
      if (!controls.name.value?.trim()) {
        return 'Product name is required.';
      }
      if (!controls.barcode.value?.trim()) {
        return 'Barcode is required.';
      }
      if (controls.categoryId.value == null) {
        return 'Category is required.';
      }
      if (controls.supermarketId.value == null) {
        return 'Supermarket is required.';
      }
      if (controls.price.value == null || controls.price.value <= 0) {
        return 'Price must be greater than zero.';
      }
    }
    if (type === 'PRICE') {
      if (controls.productId.value == null) {
        return 'Product id is required.';
      }
      if (controls.supermarketId.value == null) {
        return 'Supermarket is required.';
      }
      if (controls.price.value == null || controls.price.value <= 0) {
        return 'Price must be greater than zero.';
      }
    }
    if (type === 'NUTRITION' && controls.productId.value == null) {
      return 'Product id is required.';
    }
    if (type === 'AVAILABILITY') {
      if (controls.productId.value == null) {
        return 'Product id is required.';
      }
      if (controls.supermarketId.value == null) {
        return 'Supermarket is required.';
      }
      if (controls.available.value == null) {
        return 'Availability status is required.';
      }
    }
    return null;
  }

  private buildPatchedPayload(type: SubmissionType): Record<string, unknown> | null {
    const controls = this.editForm.controls;

    if (type === 'PRODUCT') {
      const nutrition = this.buildNutritionPayload();
      return {
        categoryId: controls.categoryId.value,
        sourceProductId: controls.sourceProductId.value,
        name: controls.name.value?.trim() ?? null,
        brand: this.trimToNull(controls.brand.value ?? ''),
        barcode: controls.barcode.value?.trim() ?? null,
        supermarketId: controls.supermarketId.value,
        price: controls.price.value,
        imageUrl: this.trimToNull(controls.imageUrl.value ?? ''),
        nutrition,
      };
    }

    if (type === 'PRICE') {
      return {
        productId: controls.productId.value,
        supermarketId: controls.supermarketId.value,
        branchId: controls.branchId.value,
        price: controls.price.value,
        imageUrl: this.trimToNull(controls.imageUrl.value ?? ''),
        observedAt: this.toIsoInstant(controls.observedAt.value ?? ''),
      };
    }

    if (type === 'NUTRITION') {
      return {
        productId: controls.productId.value,
        nutrition: this.buildNutritionPayload(),
      };
    }

    if (type === 'AVAILABILITY') {
      return {
        productId: controls.productId.value,
        supermarketId: controls.supermarketId.value,
        available: controls.available.value,
        imageUrl: this.trimToNull(controls.imageUrl.value ?? ''),
        observedAt: this.toIsoInstant(controls.observedAt.value ?? ''),
      };
    }

    return null;
  }

  private buildNutritionPayload(): Record<string, unknown> | null {
    const controls = this.editForm.controls;
    const hasValues =
      controls.calories.value != null ||
      controls.proteinG.value != null ||
      controls.carbsG.value != null ||
      controls.fatG.value != null ||
      this.trimToNull(controls.servingSize.value ?? '') != null;

    if (!hasValues) {
      return null;
    }

    return {
      calories: controls.calories.value,
      proteinG: controls.proteinG.value,
      carbsG: controls.carbsG.value,
      fatG: controls.fatG.value,
      servingSize: this.trimToNull(controls.servingSize.value ?? '') ?? '100 g',
    };
  }

  private prefetchProductContext(submission: ModerationSubmissionDetail | null): void {
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

  private referenceProductId(submission: ModerationSubmissionDetail): number | null {
    const payload = this.asRecord(submission.payload);
    if (!payload) {
      return null;
    }

    if (submission.type === 'PRODUCT') {
      return this.asNumber(payload['sourceProductId']);
    }

    if (
      submission.type === 'PRICE' ||
      submission.type === 'NUTRITION' ||
      submission.type === 'AVAILABILITY'
    ) {
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
        value.forEach((entry, index) => walk(entry, `${path}[${index}]`));
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

  private trimToNull(value: string): string | null {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }

  private toDateInputValue(raw: string): string {
    if (!raw) {
      return '';
    }
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return '';
    }
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  }

  private toIsoInstant(raw: string): string | null {
    const trimmed = raw.trim();
    if (!trimmed) {
      return null;
    }
    const date = new Date(trimmed);
    if (Number.isNaN(date.getTime())) {
      return null;
    }
    return date.toISOString();
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
    return text.length > 0 && text.toLowerCase() !== 'null' ? text : fallback;
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

  private asBoolean(value: unknown): boolean | null {
    if (typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'string') {
      const normalized = value.trim().toLowerCase();
      if (normalized === 'true') {
        return true;
      }
      if (normalized === 'false') {
        return false;
      }
    }
    return null;
  }

  private typePrefix(type: ModerationSubmissionDetail['type']): string {
    switch (type) {
      case 'PRODUCT':
        return 'PRD';
      case 'PRICE':
        return 'PRC';
      case 'NUTRITION':
        return 'NTR';
      case 'AVAILABILITY':
        return 'AVL';
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
