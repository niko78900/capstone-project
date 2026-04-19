import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { catchError, finalize, forkJoin, of, startWith, switchMap } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import { LeaderboardEntryDto, RewardWindow } from '../../../core/models/rewards.model';
import { RewardsService } from '../../../core/services/rewards.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { PageHeaderComponent } from '../../../shared/components/page-header/page-header.component';
import { StatCardComponent } from '../../../shared/components/stat-card/stat-card.component';

@Component({
  selector: 'app-admin-rewards-page',
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
    StatCardComponent,
  ],
  templateUrl: './admin-rewards.page.html',
  styleUrl: './admin-rewards.page.css',
})
export class AdminRewardsPageComponent {
  private readonly rewardsService = inject(RewardsService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly snackBar = inject(MatSnackBar);

  readonly windowControl = new FormControl<RewardWindow>('ALL_TIME', { nonNullable: true });
  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);
  readonly recomputing = signal(false);
  readonly leaderboard = signal<LeaderboardEntryDto[]>([]);
  readonly myStats = signal<{
    score: number;
    approvedTotalCount: number;
    rejectedCount: number;
    lastEventAt: string | null;
  } | null>(null);

  readonly hasLeaderboardRows = computed(() => this.leaderboard().length > 0);

  constructor() {
    this.windowControl.valueChanges
      .pipe(
        startWith(this.windowControl.value),
        switchMap((window) => this.load(window)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe();
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

  onRecompute(): void {
    if (this.recomputing()) {
      return;
    }

    this.recomputing.set(true);
    this.rewardsService
      .recompute()
      .pipe(
        catchError((error: unknown) => {
          const apiError = mapApiError(error);
          this.snackBar.open(apiError.message, 'Dismiss', { duration: 3600 });
          return of(null);
        }),
        finalize(() => this.recomputing.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((result) => {
        if (!result) {
          return;
        }

        this.snackBar.open(
          `Rewards recomputed (${result.rebuiltEvents} event(s), ${result.rebuiltStats} contributor(s)).`,
          'Dismiss',
          { duration: 3200 },
        );
        this.windowControl.setValue(this.windowControl.value, { emitEvent: true });
      });
  }

  private load(window: RewardWindow) {
    this.loading.set(true);
    this.errorMessage.set(null);

    return forkJoin({
      leaderboard: this.rewardsService.getLeaderboard(window, 50),
      me: this.rewardsService.getMe(),
    }).pipe(
      catchError((error: unknown) => {
        const apiError = mapApiError(error);
        this.errorMessage.set(apiError.message);
        this.leaderboard.set([]);
        this.myStats.set(null);
        return of(null);
      }),
      finalize(() => this.loading.set(false)),
      switchMap((result) => {
        if (!result) {
          return of(null);
        }
        this.leaderboard.set(result.leaderboard.entries);
        this.myStats.set({
          score: result.me.stats.score,
          approvedTotalCount: result.me.stats.approvedTotalCount,
          rejectedCount: result.me.stats.rejectedCount,
          lastEventAt: result.me.stats.lastEventAt,
        });
        return of(null);
      }),
    );
  }
}
