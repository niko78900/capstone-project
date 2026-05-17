import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { ActivatedRoute, ParamMap, Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatCardModule } from '@angular/material/card';
import { MatDialog } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import {
  catchError,
  debounceTime,
  distinctUntilChanged,
  filter,
  finalize,
  forkJoin,
  of,
  switchMap,
} from 'rxjs';
import { ProductDetailDto } from '../../../core/models/catalog.model';
import { fieldErrorMap, mapApiError } from '../../../core/models/api-error.model';
import {
  ModerationAiSummary,
  ModerationSubmissionDto,
  SubmissionSortToken,
  SubmissionStatus,
  SubmissionType,
} from '../../../core/models/moderation.model';
import { CatalogService } from '../../../core/services/catalog.service';
import { ModerationService } from '../../../core/services/moderation.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { FilterToolbarComponent } from '../../../shared/components/filter-toolbar/filter-toolbar.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { PageHeaderComponent } from '../../../shared/components/page-header/page-header.component';
import { DecisionDialogComponent } from './decision-dialog.component';
import {
  PayloadEditDialogComponent,
  PayloadEditDialogResult,
} from './payload-edit-dialog.component';

interface SubmissionDiffRow {
  key: string;
  label: string;
  before: string;
  after: string;
  changed: boolean;
}

type SubmissionTypeFilter = 'ALL' | SubmissionType;
type SubmissionSortOrder = 'NEWEST' | 'OLDEST';
type PayloadRecord = Record<string, unknown>;

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
  selector: 'app-admin-submissions-page',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatButtonToggleModule,
    MatCardModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatSelectModule,
    MatSnackBarModule,
    EmptyStateComponent,
    FilterToolbarComponent,
    LoadingStateComponent,
    PageHeaderComponent,
  ],
  templateUrl: './admin-submissions.page.html',
  styleUrl: './admin-submissions.page.css',
})
export class AdminSubmissionsPageComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly moderationService = inject(ModerationService);
  private readonly catalogService = inject(CatalogService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly dialog = inject(MatDialog);
  private readonly snackBar = inject(MatSnackBar);

  private readonly requestedProductDetails = new Set<number>();
  private syncingFromRoute = false;

  readonly statusControl = new FormControl<SubmissionStatus>('PENDING', { nonNullable: true });
  readonly searchControl = new FormControl('', { nonNullable: true });
  readonly typeControl = new FormControl<SubmissionTypeFilter>('ALL', { nonNullable: true });
  readonly sortControl = new FormControl<SubmissionSortOrder>('NEWEST', { nonNullable: true });
  readonly pageSizeControl = new FormControl(10, { nonNullable: true });

  readonly submissions = signal<ModerationSubmissionDto[]>([]);
  readonly totalResults = signal(0);
  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);
  readonly processingSubmissionId = signal<number | null>(null);
  readonly processingAction = signal<'approve' | 'reject' | null>(null);
  readonly patchingSubmissionId = signal<number | null>(null);
  readonly payloadModeBySubmission = signal<Record<number, 'details' | 'json'>>({});
  readonly productDetailsById = signal<Record<number, ProductDetailDto | null>>({});
  readonly aiSummaryBySubmissionId = signal<Record<number, ModerationAiSummary | null>>({});
  readonly supermarketNameById = signal<Record<number, string>>({});
  readonly searchQuery = signal('');
  readonly selectedType = signal<SubmissionTypeFilter>('ALL');
  readonly selectedSort = signal<SubmissionSortOrder>('NEWEST');
  readonly selectedPageSize = signal(10);
  readonly pageIndex = signal(0);

  readonly statuses: SubmissionStatus[] = ['PENDING', 'APPROVED', 'REJECTED'];
  readonly submissionTypes: SubmissionTypeFilter[] = [
    'ALL',
    'PRODUCT',
    'PRICE',
    'NUTRITION',
    'AVAILABILITY',
  ];
  readonly pageSizeOptions: number[] = [10, 25, 50];

  readonly hasActiveClientFilters = computed(
    () =>
      this.searchQuery().trim().length > 0 ||
      this.selectedType() !== 'ALL' ||
      this.selectedSort() !== 'NEWEST',
  );

  readonly totalPages = computed(() => {
    const totalItems = this.totalResults();
    const pageSize = this.selectedPageSize();
    return totalItems === 0 ? 1 : Math.ceil(totalItems / pageSize);
  });

  readonly pagedSubmissions = computed(() => this.submissions());

  readonly paginationSummary = computed(() => {
    const total = this.totalResults();
    if (total === 0) {
      return '0 results';
    }
    const page = this.pageIndex();
    const pageSize = this.selectedPageSize();
    const start = page * pageSize + 1;
    const end = Math.min(total, start + this.pagedSubmissions().length - 1);
    return `${start}-${end} of ${total}`;
  });

  constructor() {
    this.loadSupermarkets();

    this.route.queryParamMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((params) => {
      this.applyQueryState(params);
      this.loadSubmissionsFromServer();
    });

    this.searchControl.valueChanges
      .pipe(debounceTime(260), distinctUntilChanged(), takeUntilDestroyed(this.destroyRef))
      .subscribe((query) => {
        this.searchQuery.set(query);
        if (this.syncingFromRoute) {
          return;
        }
        this.pageIndex.set(0);
        this.pushRouteState();
      });

    this.statusControl.valueChanges.pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => {
      if (this.syncingFromRoute) {
        return;
      }
      this.pageIndex.set(0);
      this.pushRouteState();
    });

    this.typeControl.valueChanges.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((type) => {
      this.selectedType.set(type);
      if (this.syncingFromRoute) {
        return;
      }
      this.pageIndex.set(0);
      this.pushRouteState();
    });

    this.sortControl.valueChanges.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((sort) => {
      this.selectedSort.set(sort);
      if (this.syncingFromRoute) {
        return;
      }
      this.pageIndex.set(0);
      this.pushRouteState();
    });

    this.pageSizeControl.valueChanges
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe((pageSize) => {
        this.selectedPageSize.set(pageSize);
        if (this.syncingFromRoute) {
          return;
        }
        this.pageIndex.set(0);
        this.pushRouteState();
      });
  }

  displayDate(raw: string): string {
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return raw;
    }
    return date.toLocaleString();
  }

  refreshCurrentPage(): void {
    this.loadSubmissionsFromServer();
  }

  formatPayload(payload: unknown): string {
    try {
      return JSON.stringify(payload, null, 2);
    } catch {
      return String(payload);
    }
  }

  typeLabel(type: SubmissionTypeFilter): string {
    if (type === 'ALL') {
      return 'All types';
    }
    return type.charAt(0) + type.slice(1).toLowerCase();
  }

  isJsonMode(submissionId: number): boolean {
    return this.payloadModeBySubmission()[submissionId] === 'json';
  }

  togglePayloadMode(submissionId: number): void {
    this.payloadModeBySubmission.update((current) => {
      const nextMode = current[submissionId] === 'json' ? 'details' : 'json';
      return { ...current, [submissionId]: nextMode };
    });
  }

  aiSummary(submissionId: number): ModerationAiSummary | null {
    return this.aiSummaryBySubmissionId()[submissionId] ?? null;
  }

  hasAiWarnings(submissionId: number): boolean {
    const summary = this.aiSummary(submissionId);
    return Boolean(summary && (summary.warnings.length > 0 || summary.flags.length > 0));
  }

  aiStatusLabel(submissionId: number): string {
    const summary = this.aiSummary(submissionId);
    if (!summary) {
      return 'AI: no hint';
    }
    return `AI: ${summary.status}`;
  }

  aiWarningLabel(submissionId: number): string {
    const summary = this.aiSummary(submissionId);
    if (!summary) {
      return 'No warnings';
    }
    return `${summary.warnings.length} warning(s), ${summary.flags.length} flag(s)`;
  }

  detailRows(submission: ModerationSubmissionDto): SubmissionDiffRow[] {
    switch (submission.type) {
      case 'PRODUCT':
        return this.buildProductRows(submission);
      case 'PRICE':
        return this.buildPriceRows(submission);
      case 'NUTRITION':
        return this.buildNutritionRows(submission);
      case 'AVAILABILITY':
        return this.buildAvailabilityRows(submission);
      default:
        return [];
    }
  }

  changedRowCount(rows: SubmissionDiffRow[]): number {
    return rows.filter((row) => row.changed).length;
  }

  contextMessage(submission: ModerationSubmissionDto): string | null {
    const productId = this.referenceProductId(submission);
    if (productId == null) {
      return null;
    }

    const detail = this.productDetailsById()[productId];
    if (detail === undefined) {
      return 'Loading current product snapshot for before and after comparison.';
    }

    if (detail === null) {
      return 'Current product snapshot is unavailable. Review submitted values with caution.';
    }

    return null;
  }

  onApprove(submission: ModerationSubmissionDto): void {
    this.openDecisionDialog('approve', submission);
  }

  onReject(submission: ModerationSubmissionDto): void {
    this.openDecisionDialog('reject', submission);
  }

  onEditPayload(submission: ModerationSubmissionDto): void {
    if (submission.status !== 'PENDING' || this.patchingSubmissionId() !== null) {
      return;
    }

    const dialogRef = this.dialog.open(PayloadEditDialogComponent, {
      width: '760px',
      maxWidth: '95vw',
      panelClass: 'decision-dialog-panel',
      data: {
        submissionId: submission.id,
        submissionRef: this.submissionReference(submission),
        initialPayloadJson: this.formatPayload(submission.payload),
      },
    });

    dialogRef
      .afterClosed()
      .pipe(
        filter((result): result is PayloadEditDialogResult => result !== undefined),
        switchMap((result) => {
          this.patchingSubmissionId.set(submission.id);
          return this.moderationService
            .patchSubmissionPayload(submission.id, {
              payload: result.payload,
              editReason: result.editReason,
              expectedUpdatedAt: submission.updatedAt,
            })
            .pipe(
              catchError((error: unknown) => {
                const apiError = mapApiError(error);
                const fieldErrors = fieldErrorMap(apiError);
                const firstFieldError = Object.entries(fieldErrors)[0];
                const message = firstFieldError
                  ? `${apiError.message} (${firstFieldError[0]}: ${firstFieldError[1]})`
                  : apiError.message;
                this.snackBar.open(message, 'Dismiss', { duration: 5000 });
                if (apiError.status === 409) {
                  this.loadSubmissionsFromServer();
                }
                return of(null);
              }),
              finalize(() => this.patchingSubmissionId.set(null)),
            );
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((result) => {
        if (!result) {
          return;
        }
        this.snackBar.open(
          `Submission ${this.submissionReference(submission)} patched (${result.changedFieldCount} field(s)).`,
          'Dismiss',
          { duration: 3200 },
        );
        this.loadSubmissionsFromServer();
      });
  }

  clearClientFilters(): void {
    this.searchControl.setValue('');
    this.typeControl.setValue('ALL');
    this.sortControl.setValue('NEWEST');
    this.pageIndex.set(0);
    this.pushRouteState();
  }

  goToPreviousPage(): void {
    if (!this.canGoToPreviousPage()) {
      return;
    }
    this.pageIndex.update((current) => (current > 0 ? current - 1 : current));
    this.pushRouteState();
  }

  goToNextPage(): void {
    if (!this.canGoToNextPage()) {
      return;
    }
    const maxIndex = this.totalPages() - 1;
    this.pageIndex.update((current) => (current < maxIndex ? current + 1 : current));
    this.pushRouteState();
  }

  canGoToPreviousPage(): boolean {
    return this.pageIndex() > 0;
  }

  canGoToNextPage(): boolean {
    return this.pageIndex() < this.totalPages() - 1;
  }

  submissionDetailQueryParams(): {
    status: SubmissionStatus;
    q: string;
    type: SubmissionTypeFilter;
    sort: SubmissionSortOrder;
    page: number;
    size: number;
  } {
    return {
      status: this.statusControl.value,
      q: this.searchControl.value,
      type: this.typeControl.value,
      sort: this.sortControl.value,
      page: this.pageIndex(),
      size: this.pageSizeControl.value,
    };
  }

  evidenceImageUrl(submission: ModerationSubmissionDto): string | null {
    const payload = this.asRecord(submission.payload);
    if (payload == null) {
      return null;
    }
    const imageUrl = this.asText(payload['imageUrl'], '');
    return imageUrl.length > 0 ? imageUrl : null;
  }

  isProcessingDecision(submissionId: number, mode: 'approve' | 'reject'): boolean {
    return this.processingSubmissionId() === submissionId && this.processingAction() === mode;
  }

  isPatchingSubmission(submissionId: number): boolean {
    return this.patchingSubmissionId() === submissionId;
  }

  submissionReference(submission: ModerationSubmissionDto): string {
    const typePrefix = this.typePrefix(submission.type);
    const dateKey = this.dateKey(submission.createdAt);
    const compactId = this.compactId(submission.id);
    return `${typePrefix}-${dateKey}-${compactId}`;
  }

  private applyQueryState(params: ParamMap): void {
    const requestedStatus =
      this.normalizeStatus((params.get('status') ?? '').toUpperCase()) ?? 'PENDING';
    const requestedQuery = params.get('q') ?? '';
    const requestedType =
      this.normalizeTypeFilter((params.get('type') ?? '').toUpperCase()) ?? 'ALL';
    const requestedSort =
      this.normalizeSortOrder((params.get('sort') ?? '').toUpperCase()) ?? 'NEWEST';
    const requestedPageRaw = Number(params.get('page') ?? '0');
    const requestedSizeRaw = Number(params.get('size') ?? '10');
    const requestedPage =
      Number.isFinite(requestedPageRaw) && requestedPageRaw >= 0 ? Math.floor(requestedPageRaw) : 0;
    const requestedSize = this.pageSizeOptions.includes(requestedSizeRaw) ? requestedSizeRaw : 10;

    this.syncingFromRoute = true;
    this.statusControl.setValue(requestedStatus, { emitEvent: false });
    this.searchControl.setValue(requestedQuery, { emitEvent: false });
    this.typeControl.setValue(requestedType, { emitEvent: false });
    this.sortControl.setValue(requestedSort, { emitEvent: false });
    this.pageSizeControl.setValue(requestedSize, { emitEvent: false });
    this.syncingFromRoute = false;

    this.searchQuery.set(requestedQuery);
    this.selectedType.set(requestedType);
    this.selectedSort.set(requestedSort);
    this.selectedPageSize.set(requestedSize);
    this.pageIndex.set(requestedPage);
  }

  private pushRouteState(): void {
    if (this.syncingFromRoute) {
      return;
    }

    void this.router.navigate([], {
      relativeTo: this.route,
      replaceUrl: true,
      queryParams: {
        status: this.statusControl.value,
        q: this.searchControl.value.trim().length > 0 ? this.searchControl.value.trim() : null,
        type: this.typeControl.value,
        sort: this.sortControl.value,
        page: this.pageIndex(),
        size: this.pageSizeControl.value,
      },
    });
  }

  private loadSubmissionsFromServer(): void {
    this.loading.set(true);
    this.errorMessage.set(null);

    const status = this.statusControl.value;
    const type = this.typeControl.value === 'ALL' ? undefined : this.typeControl.value;
    const q = this.normalizedServerQuery(this.searchControl.value);
    const sort: SubmissionSortToken =
      this.sortControl.value === 'NEWEST' ? 'createdAt,desc' : 'createdAt,asc';
    const page = this.pageIndex();
    const size = this.pageSizeControl.value;

    this.moderationService
      .listSubmissions({ status, type, q, sort, page, size })
      .pipe(
        catchError((error: unknown) => {
          const apiError = mapApiError(error);
          this.errorMessage.set(apiError.message);
          return of({
            items: [],
            totalElements: 0,
            page,
            size,
            totalPages: 0,
          });
        }),
        finalize(() => this.loading.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((response) => {
        // Keep the requested page in bounds after server-side filtering changes total pages.
        const maxPage = response.totalPages > 0 ? response.totalPages - 1 : 0;
        if (page > maxPage) {
          this.pageIndex.set(maxPage);
          this.pushRouteState();
          return;
        }

        this.submissions.set(response.items);
        this.totalResults.set(response.totalElements);
        this.prefetchComparisonContext(response.items);
        this.loadAiHints(response.items);
      });
  }

  private normalizedServerQuery(raw: string): string | undefined {
    const trimmed = raw.trim();
    if (trimmed.length === 0) {
      return undefined;
    }

    // Support admin reference search (PRD/PRC/NTR/AVL/SUB-YYYYMMDD-<base36Id>) by converting it back to numeric id.
    const refMatch = /^(PRD|PRC|NTR|AVL|SUB)-\d{8}-([0-9A-Z]+)$/i.exec(trimmed);
    if (refMatch) {
      const parsedId = Number.parseInt(refMatch[2], 36);
      if (Number.isFinite(parsedId) && parsedId > 0) {
        return String(parsedId);
      }
    }
    return trimmed;
  }

  private openDecisionDialog(
    mode: 'approve' | 'reject',
    submission: ModerationSubmissionDto,
  ): void {
    const submissionRef = this.submissionReference(submission);
    const dialogRef = this.dialog.open(DecisionDialogComponent, {
      width: '420px',
      panelClass: 'decision-dialog-panel',
      data: { mode, submissionId: submission.id, submissionRef },
    });

    dialogRef
      .afterClosed()
      .pipe(
        filter((reason) => reason !== undefined),
        switchMap((reason) => {
          this.processingSubmissionId.set(submission.id);
          this.processingAction.set(mode);

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
            finalize(() => {
              this.processingSubmissionId.set(null);
              this.processingAction.set(null);
            }),
          );
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((response) => {
        if (!response) {
          return;
        }

        const actionLabel = response.action === 'APPROVED' ? 'approved' : 'rejected';
        this.snackBar.open(`Submission ${submissionRef} ${actionLabel}.`, 'Dismiss', {
          duration: 2800,
        });
        this.loadSubmissionsFromServer();
      });
  }

  private prefetchComparisonContext(submissions: ModerationSubmissionDto[]): void {
    const productIds = new Set<number>();

    for (const submission of submissions) {
      const productId = this.referenceProductId(submission);
      if (productId != null && productId > 0) {
        productIds.add(productId);
      }
    }

    for (const productId of productIds) {
      if (this.requestedProductDetails.has(productId)) {
        continue;
      }

      this.requestedProductDetails.add(productId);
      this.catalogService
        .getProductDetail(productId)
        .pipe(
          catchError(() => of(null)),
          takeUntilDestroyed(this.destroyRef),
        )
        .subscribe((detail) => {
          this.productDetailsById.update((current) => ({ ...current, [productId]: detail }));
        });
    }
  }

  private loadAiHints(submissions: ModerationSubmissionDto[]): void {
    const current = this.aiSummaryBySubmissionId();
    const missingIds = submissions
      .map((submission) => submission.id)
      .filter((submissionId) => !Object.prototype.hasOwnProperty.call(current, submissionId));

    if (missingIds.length === 0) {
      return;
    }

    forkJoin(
      missingIds.map((submissionId) =>
        this.moderationService.getSubmission(submissionId).pipe(catchError(() => of(null))),
      ),
    )
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe((details) => {
        const next = { ...this.aiSummaryBySubmissionId() };
        details.forEach((detail, index) => {
          next[missingIds[index]] = detail?.aiSummary ?? null;
        });
        this.aiSummaryBySubmissionId.set(next);
      });
  }

  private loadSupermarkets(): void {
    this.catalogService
      .getSupermarkets()
      .pipe(
        catchError(() => of([])),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((supermarkets) => {
        const map: Record<number, string> = {};
        for (const supermarket of supermarkets) {
          map[supermarket.id] = supermarket.name;
        }
        this.supermarketNameById.set(map);
      });
  }

  private buildProductRows(submission: ModerationSubmissionDto): SubmissionDiffRow[] {
    const payload = this.asRecord(submission.payload);
    if (payload == null) {
      return [];
    }

    const sourceProductId = this.asNumber(payload['sourceProductId']);
    const isCreate = sourceProductId == null;
    const current =
      sourceProductId == null ? null : (this.productDetailsById()[sourceProductId] ?? null);
    const canCompare = !isCreate && current != null;
    const beforeFallback = isCreate ? '-' : this.snapshotPlaceholder(sourceProductId, current);
    const submittedSupermarketId = this.asNumber(payload['supermarketId']);
    const submittedPrice = this.asNumber(payload['price']);
    const currentPriceForSelectedMarket =
      current?.prices.find(
        (entry) => submittedSupermarketId != null && entry.supermarketId === submittedSupermarketId,
      ) ?? null;

    const rows: SubmissionDiffRow[] = [];

    rows.push(
      this.makeRow(
        'name',
        'Name',
        isCreate ? '-' : (current?.name ?? beforeFallback),
        this.asText(payload['name'], '-'),
        { canCompare, forceChanged: isCreate },
      ),
    );

    rows.push(
      this.makeRow(
        'brand',
        'Brand',
        isCreate ? '-' : this.asText(current?.brand, 'Unbranded'),
        this.asText(payload['brand'], 'Unbranded'),
        { canCompare, forceChanged: isCreate },
      ),
    );

    rows.push(
      this.makeRow(
        'category',
        'Category',
        isCreate ? '-' : (current?.category ?? beforeFallback),
        this.categoryName(payload['categoryId']),
        { canCompare, forceChanged: isCreate },
      ),
    );

    rows.push(
      this.makeRow(
        'barcode',
        'Barcode',
        isCreate ? '-' : this.asText(current?.barcode, 'Not set'),
        this.asText(payload['barcode'], 'Not set'),
        { canCompare, forceChanged: isCreate },
      ),
    );

    rows.push(
      this.makeRow(
        'supermarket',
        'Supermarket',
        currentPriceForSelectedMarket?.supermarketName ?? (isCreate ? '-' : 'No current price'),
        this.supermarketName(submittedSupermarketId),
        { canCompare, forceChanged: isCreate },
      ),
    );

    rows.push(
      this.makeRow(
        'price',
        'Price',
        currentPriceForSelectedMarket
          ? this.formatMoney(
              currentPriceForSelectedMarket.price,
              currentPriceForSelectedMarket.currency,
            )
          : isCreate
            ? '-'
            : 'No current price',
        this.formatMoney(submittedPrice, currentPriceForSelectedMarket?.currency ?? 'MKD'),
        { canCompare, forceChanged: isCreate },
      ),
    );

    rows.push(
      this.makeRow(
        'imageUrl',
        'Image',
        isCreate ? '-' : this.asText(current?.imageUrl, 'No image'),
        this.asText(payload['imageUrl'], 'No image'),
        { canCompare, forceChanged: isCreate },
      ),
    );

    const submittedNutrition = this.asRecord(payload['nutrition']);
    const currentNutrition = current?.nutrition;

    if (submittedNutrition != null) {
      const nutritionComparable = canCompare && currentNutrition != null;

      rows.push(
        this.makeRow(
          'calories',
          'Calories',
          isCreate
            ? '-'
            : currentNutrition
              ? this.formatMeasure(currentNutrition.calories, 'kcal')
              : beforeFallback,
          this.formatMeasure(submittedNutrition['calories'], 'kcal'),
          { canCompare: nutritionComparable, forceChanged: isCreate },
        ),
      );

      rows.push(
        this.makeRow(
          'proteinG',
          'Protein',
          isCreate
            ? '-'
            : currentNutrition
              ? this.formatMeasure(currentNutrition.proteinG, 'g')
              : beforeFallback,
          this.formatMeasure(submittedNutrition['proteinG'], 'g'),
          { canCompare: nutritionComparable, forceChanged: isCreate },
        ),
      );

      rows.push(
        this.makeRow(
          'carbsG',
          'Carbs',
          isCreate
            ? '-'
            : currentNutrition
              ? this.formatMeasure(currentNutrition.carbsG, 'g')
              : beforeFallback,
          this.formatMeasure(submittedNutrition['carbsG'], 'g'),
          { canCompare: nutritionComparable, forceChanged: isCreate },
        ),
      );

      rows.push(
        this.makeRow(
          'fatG',
          'Fat',
          isCreate
            ? '-'
            : currentNutrition
              ? this.formatMeasure(currentNutrition.fatG, 'g')
              : beforeFallback,
          this.formatMeasure(submittedNutrition['fatG'], 'g'),
          { canCompare: nutritionComparable, forceChanged: isCreate },
        ),
      );
    } else {
      rows.push(
        this.makeRow(
          'nutrition',
          'Nutrition',
          isCreate ? '-' : 'Current values',
          'No nutrition change submitted',
          { canCompare: false, forceChanged: false },
        ),
      );
    }

    return rows;
  }

  private buildPriceRows(submission: ModerationSubmissionDto): SubmissionDiffRow[] {
    const payload = this.asRecord(submission.payload);
    if (payload == null) {
      return [];
    }

    const productId = this.asNumber(payload['productId']);
    const supermarketId = this.asNumber(payload['supermarketId']);
    const current = productId == null ? null : (this.productDetailsById()[productId] ?? null);
    const currentPrice =
      current?.prices.find(
        (entry) => supermarketId != null && entry.supermarketId === supermarketId,
      ) ?? null;

    const rows: SubmissionDiffRow[] = [];

    rows.push(
      this.makeRow(
        'product',
        'Product',
        current ? `${current.name} (#${current.id})` : this.productFallback(productId),
        current ? `${current.name} (#${current.id})` : this.productFallback(productId),
        { canCompare: false },
      ),
    );

    rows.push(
      this.makeRow(
        'supermarket',
        'Supermarket',
        currentPrice?.supermarketName ?? this.supermarketFallback(supermarketId),
        currentPrice?.supermarketName ?? this.supermarketFallback(supermarketId),
        { canCompare: false },
      ),
    );

    rows.push(
      this.makeRow(
        'price',
        'Price',
        currentPrice
          ? this.formatMoney(currentPrice.price, currentPrice.currency)
          : 'No verified price',
        this.formatMoney(this.asNumber(payload['price']), currentPrice?.currency ?? 'MKD'),
        { canCompare: currentPrice != null },
      ),
    );

    rows.push(
      this.makeRow(
        'observedAt',
        'Observed at',
        currentPrice?.observedAt ? this.displayDate(currentPrice.observedAt) : '-',
        this.asDateText(payload['observedAt']) ?? 'On approval time',
        { canCompare: false },
      ),
    );

    rows.push(
      this.makeRow(
        'imageUrl',
        'Image',
        '-',
        this.asText(payload['imageUrl'], 'No image'),
        { canCompare: false },
      ),
    );

    return rows;
  }

  private buildNutritionRows(submission: ModerationSubmissionDto): SubmissionDiffRow[] {
    const payload = this.asRecord(submission.payload);
    if (payload == null) {
      return [];
    }

    const productId = this.asNumber(payload['productId']);
    const submittedNutrition = this.asRecord(payload['nutrition']);
    const current = productId == null ? null : (this.productDetailsById()[productId] ?? null);
    const currentNutrition = current?.nutrition;
    const canCompare = currentNutrition != null && submittedNutrition != null;

    const rows: SubmissionDiffRow[] = [];

    rows.push(
      this.makeRow(
        'product',
        'Product',
        current ? `${current.name} (#${current.id})` : this.productFallback(productId),
        current ? `${current.name} (#${current.id})` : this.productFallback(productId),
        { canCompare: false },
      ),
    );

    if (submittedNutrition == null) {
      rows.push(
        this.makeRow('nutrition', 'Nutrition', 'Current values', 'No nutrition payload provided', {
          canCompare: false,
        }),
      );
      return rows;
    }

    rows.push(
      this.makeRow(
        'calories',
        'Calories',
        this.formatMeasure(currentNutrition?.calories, 'kcal'),
        this.formatMeasure(submittedNutrition['calories'], 'kcal'),
        { canCompare },
      ),
    );

    rows.push(
      this.makeRow(
        'proteinG',
        'Protein',
        this.formatMeasure(currentNutrition?.proteinG, 'g'),
        this.formatMeasure(submittedNutrition['proteinG'], 'g'),
        { canCompare },
      ),
    );

    rows.push(
      this.makeRow(
        'carbsG',
        'Carbs',
        this.formatMeasure(currentNutrition?.carbsG, 'g'),
        this.formatMeasure(submittedNutrition['carbsG'], 'g'),
        { canCompare },
      ),
    );

    rows.push(
      this.makeRow(
        'fatG',
        'Fat',
        this.formatMeasure(currentNutrition?.fatG, 'g'),
        this.formatMeasure(submittedNutrition['fatG'], 'g'),
        { canCompare },
      ),
    );

    rows.push(
      this.makeRow(
        'servingSize',
        'Serving size',
        this.asText(currentNutrition?.servingSize, '100 g'),
        this.asText(submittedNutrition['servingSize'], '100 g'),
        { canCompare },
      ),
    );

    return rows;
  }

  private buildAvailabilityRows(submission: ModerationSubmissionDto): SubmissionDiffRow[] {
    const payload = this.asRecord(submission.payload);
    if (payload == null) {
      return [];
    }

    const productId = this.asNumber(payload['productId']);
    const supermarketId = this.asNumber(payload['supermarketId']);
    const available = this.asBoolean(payload['available']);
    const current = productId == null ? null : (this.productDetailsById()[productId] ?? null);
    const currentPrice =
      current?.prices.find(
        (entry) => supermarketId != null && entry.supermarketId === supermarketId,
      ) ?? null;
    const currentUnavailable =
      current?.unavailableMarkets.find(
        (entry) => supermarketId != null && entry.supermarketId === supermarketId,
      ) ?? null;

    return [
      this.makeRow(
        'product',
        'Product',
        current ? `${current.name} (#${current.id})` : this.productFallback(productId),
        current ? `${current.name} (#${current.id})` : this.productFallback(productId),
        { canCompare: false },
      ),
      this.makeRow(
        'supermarket',
        'Supermarket',
        currentPrice?.supermarketName ??
          currentUnavailable?.supermarketName ??
          this.supermarketFallback(supermarketId),
        currentPrice?.supermarketName ??
          currentUnavailable?.supermarketName ??
          this.supermarketFallback(supermarketId),
        { canCompare: false },
      ),
      this.makeRow(
        'availability',
        'Availability',
        currentUnavailable ? 'Not available' : currentPrice ? 'Available with verified price' : 'Unknown',
        available === false ? 'Not available' : available === true ? 'Available' : 'Unknown',
        { canCompare: currentPrice != null || currentUnavailable != null },
      ),
      this.makeRow(
        'observedAt',
        'Observed at',
        currentUnavailable?.observedAt
          ? this.displayDate(currentUnavailable.observedAt)
          : currentPrice?.observedAt
            ? this.displayDate(currentPrice.observedAt)
            : '-',
        this.asDateText(payload['observedAt']) ?? 'On approval time',
        { canCompare: false },
      ),
      this.makeRow(
        'imageUrl',
        'Image',
        '-',
        this.asText(payload['imageUrl'], 'No image'),
        { canCompare: false },
      ),
    ];
  }

  private referenceProductId(submission: ModerationSubmissionDto): number | null {
    const payload = this.asRecord(submission.payload);
    if (payload == null) {
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

  private snapshotPlaceholder(productId: number | null, detail: ProductDetailDto | null): string {
    if (productId == null) {
      return '-';
    }
    if (detail == null) {
      return 'Current value unavailable';
    }
    return '-';
  }

  private categoryName(raw: unknown): string {
    const categoryId = this.asNumber(raw);
    if (categoryId == null) {
      return 'Unknown category';
    }
    return CATEGORY_NAMES[categoryId] ?? `Category #${categoryId}`;
  }

  private supermarketName(supermarketId: number | null): string {
    if (supermarketId == null) {
      return 'Unknown supermarket';
    }
    return this.supermarketNameById()[supermarketId] ?? `Supermarket #${supermarketId}`;
  }

  private makeRow(
    key: string,
    label: string,
    before: string,
    after: string,
    options: { canCompare?: boolean; forceChanged?: boolean } = {},
  ): SubmissionDiffRow {
    const canCompare = options.canCompare ?? true;
    const changed =
      options.forceChanged === true
        ? true
        : canCompare
          ? this.normalizeComparison(before) !== this.normalizeComparison(after)
          : false;

    return {
      key,
      label,
      before,
      after,
      changed,
    };
  }

  private normalizeComparison(value: string): string {
    return value.trim().toLowerCase();
  }

  private asRecord(value: unknown): PayloadRecord | null {
    if (value == null || Array.isArray(value) || typeof value !== 'object') {
      return null;
    }
    return value as PayloadRecord;
  }

  private asText(value: unknown, fallback = '-'): string {
    if (value == null) {
      return fallback;
    }
    const text = String(value).trim();
    if (text.length === 0 || text.toLowerCase() === 'null') {
      return fallback;
    }
    return text;
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

  private asDateText(value: unknown): string | null {
    if (typeof value !== 'string' || value.trim().length === 0) {
      return null;
    }
    return this.displayDate(value);
  }

  private formatMeasure(value: unknown, unit: string): string {
    const numeric = this.asNumber(value);
    if (numeric == null) {
      return '-';
    }
    return `${numeric} ${unit}`;
  }

  private formatMoney(value: number | null, currency: string): string {
    if (value == null || !Number.isFinite(value)) {
      return '-';
    }
    return `${value.toFixed(2)} ${currency}`;
  }

  private productFallback(productId: number | null): string {
    return productId == null ? 'Unknown product' : `Product #${productId}`;
  }

  private supermarketFallback(supermarketId: number | null): string {
    return this.supermarketName(supermarketId);
  }

  private typePrefix(type: ModerationSubmissionDto['type']): string {
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

  private normalizeStatus(value: string): SubmissionStatus | null {
    if (value === 'PENDING' || value === 'APPROVED' || value === 'REJECTED') {
      return value;
    }
    return null;
  }

  private normalizeTypeFilter(value: string): SubmissionTypeFilter | null {
    if (
      value === 'ALL' ||
      value === 'PRODUCT' ||
      value === 'PRICE' ||
      value === 'NUTRITION' ||
      value === 'AVAILABILITY'
    ) {
      return value;
    }
    return null;
  }

  private normalizeSortOrder(value: string): SubmissionSortOrder | null {
    if (value === 'NEWEST' || value === 'OLDEST') {
      return value;
    }
    return null;
  }
}
