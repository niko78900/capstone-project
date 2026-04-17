import { Component, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { catchError, finalize, forkJoin, of } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import { ModerationSubmissionDto } from '../../../core/models/moderation.model';
import { ModerationService } from '../../../core/services/moderation.service';
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
  private readonly destroyRef = inject(DestroyRef);

  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);
  readonly summary = signal<DashboardSummary>({
    pending: 0,
    approved: 0,
    rejected: 0,
    total: 0,
  });
  readonly recentPending = signal<ModerationSubmissionDto[]>([]);

  constructor() {
    this.loadDashboard();
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

  private loadDashboard(): void {
    this.loading.set(true);
    this.errorMessage.set(null);

    forkJoin({
      pending: this.moderationService.getSubmissions('PENDING'),
      approved: this.moderationService.getSubmissions('APPROVED'),
      rejected: this.moderationService.getSubmissions('REJECTED'),
    })
      .pipe(
        catchError((error: unknown) => {
          const apiError = mapApiError(error);
          this.errorMessage.set(apiError.message);
          return of({
            pending: [],
            approved: [],
            rejected: [],
          });
        }),
        finalize(() => this.loading.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe(({ pending, approved, rejected }) => {
        this.summary.set({
          pending: pending.length,
          approved: approved.length,
          rejected: rejected.length,
          total: pending.length + approved.length + rejected.length,
        });

        const sortedPending = [...pending].sort(
          (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
        );
        this.recentPending.set(sortedPending.slice(0, 6));
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
