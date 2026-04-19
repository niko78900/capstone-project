import { Component, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { catchError, finalize, forkJoin, of } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import { ModerationSubmissionDto, SubmissionSortToken } from '../../../core/models/moderation.model';
import { LeaderboardEntryDto } from '../../../core/models/rewards.model';
import { ModerationService } from '../../../core/services/moderation.service';
import { RewardsService } from '../../../core/services/rewards.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { PageHeaderComponent } from '../../../shared/components/page-header/page-header.component';
import { StatCardComponent } from '../../../shared/components/stat-card/stat-card.component';

interface DashboardSummary {
  pending: number;
  approved: number;
  rejected: number;
  total: number;
}

@Component({
  selector: 'app-admin-dashboard-page',
  imports: [
    RouterLink,
    MatButtonModule,
    MatCardModule,
    PageHeaderComponent,
    StatCardComponent,
    EmptyStateComponent,
    LoadingStateComponent,
  ],
  templateUrl: './admin-dashboard.page.html',
  styleUrl: './admin-dashboard.page.css',
})
export class AdminDashboardPageComponent {
  private readonly moderationService = inject(ModerationService);
  private readonly rewardsService = inject(RewardsService);
  private readonly destroyRef = inject(DestroyRef);

  readonly summaryLoading = signal(true);
  readonly summaryError = signal<string | null>(null);
  readonly leaderboardLoading = signal(true);
  readonly leaderboardError = signal<string | null>(null);
  readonly summary = signal<DashboardSummary>({
    pending: 0,
    approved: 0,
    rejected: 0,
    total: 0,
  });
  readonly oldestPendingCreatedAt = signal<string | null>(null);
  readonly newestPendingCreatedAt = signal<string | null>(null);
  readonly recentPending = signal<ModerationSubmissionDto[]>([]);
  readonly topContributors = signal<LeaderboardEntryDto[]>([]);

  constructor() {
    this.refreshAll();
  }

  refreshAll(): void {
    this.loadDashboard();
    this.loadTopContributors();
  }

  submissionReference(submission: ModerationSubmissionDto): string {
    const typePrefix = this.typePrefix(submission.type);
    const dateKey = this.dateKey(submission.createdAt);
    const compactId = this.compactId(submission.id);
    return `${typePrefix}-${dateKey}-${compactId}`;
  }

  displayDate(raw: string): string {
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return raw;
    }
    return date.toLocaleString();
  }

  queueOldestCreatedAt(): string {
    const createdAt = this.oldestPendingCreatedAt();
    if (!createdAt) {
      return '-';
    }
    return this.displayDate(createdAt);
  }

  queueNewestCreatedAt(): string {
    const createdAt = this.newestPendingCreatedAt();
    if (!createdAt) {
      return '-';
    }
    return this.displayDate(createdAt);
  }

  oldestPendingAgeHours(): string {
    const createdAt = this.oldestPendingCreatedAt();
    if (!createdAt) {
      return '-';
    }
    const ageMs = Date.now() - new Date(createdAt).getTime();
    if (!Number.isFinite(ageMs) || ageMs < 0) {
      return '-';
    }
    return `${Math.floor(ageMs / (1000 * 60 * 60))} h`;
  }

  private loadDashboard(): void {
    this.summaryLoading.set(true);
    this.summaryError.set(null);
    const newestSort: SubmissionSortToken = 'createdAt,desc';
    const oldestSort: SubmissionSortToken = 'createdAt,asc';

    // Pull only the data needed for dashboard cards instead of loading full submission lists.
    forkJoin({
      pendingSnapshot: this.moderationService.listSubmissions({
        status: 'PENDING',
        page: 0,
        size: 6,
        sort: newestSort,
      }),
      pendingOldest: this.moderationService.listSubmissions({
        status: 'PENDING',
        page: 0,
        size: 1,
        sort: oldestSort,
      }),
      approvedCount: this.moderationService.countSubmissions('APPROVED'),
      rejectedCount: this.moderationService.countSubmissions('REJECTED'),
    })
      .pipe(
        catchError((error: unknown) => {
          const apiError = mapApiError(error);
          this.summaryError.set(apiError.message);
          return of({
            pendingSnapshot: {
              items: [],
              totalElements: 0,
              page: 0,
              size: 6,
              totalPages: 0,
            },
            pendingOldest: {
              items: [],
              totalElements: 0,
              page: 0,
              size: 1,
              totalPages: 0,
            },
            approvedCount: 0,
            rejectedCount: 0,
          });
        }),
        finalize(() => this.summaryLoading.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe(({ pendingSnapshot, pendingOldest, approvedCount, rejectedCount }) => {
        const pendingCount = pendingSnapshot.totalElements;
        this.summary.set({
          pending: pendingCount,
          approved: approvedCount,
          rejected: rejectedCount,
          total: pendingCount + approvedCount + rejectedCount,
        });

        this.recentPending.set(pendingSnapshot.items);
        this.newestPendingCreatedAt.set(pendingSnapshot.items[0]?.createdAt ?? null);
        this.oldestPendingCreatedAt.set(pendingOldest.items[0]?.createdAt ?? null);
      });
  }

  private loadTopContributors(): void {
    this.leaderboardLoading.set(true);
    this.leaderboardError.set(null);

    this.rewardsService
      .getLeaderboard('ALL_TIME', 5)
      .pipe(
        catchError((error: unknown) => {
          const apiError = mapApiError(error);
          this.leaderboardError.set(apiError.message);
          return of({
            window: 'ALL_TIME',
            limit: 5,
            entries: [],
          });
        }),
        finalize(() => this.leaderboardLoading.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((result) => {
        this.topContributors.set(result.entries);
      });
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
