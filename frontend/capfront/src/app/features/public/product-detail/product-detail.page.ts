import { Component, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { RouterLink } from '@angular/router';
import { ActivatedRoute } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatDividerModule } from '@angular/material/divider';
import { MatTableModule } from '@angular/material/table';
import { catchError, of, switchMap } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import { ProductDetailDto } from '../../../core/models/catalog.model';
import { CatalogService } from '../../../core/services/catalog.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';

@Component({
  selector: 'app-product-detail-page',
  imports: [
    RouterLink,
    MatButtonModule,
    MatCardModule,
    MatDividerModule,
    MatTableModule,
    EmptyStateComponent,
    LoadingStateComponent,
  ],
  templateUrl: './product-detail.page.html',
  styleUrl: './product-detail.page.css',
})
export class ProductDetailPageComponent {
  private readonly route = inject(ActivatedRoute);
  private readonly catalogService = inject(CatalogService);
  private readonly destroyRef = inject(DestroyRef);

  readonly detail = signal<ProductDetailDto | null>(null);
  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);

  readonly displayedColumns = ['supermarket', 'price', 'observedAt'];

  constructor() {
    this.route.paramMap
      .pipe(
        switchMap((params) => {
          this.loading.set(true);
          this.errorMessage.set(null);
          const id = Number(params.get('id'));
          if (!Number.isFinite(id) || id < 1) {
            this.errorMessage.set('Invalid product id');
            this.loading.set(false);
            return of(null);
          }

          return this.catalogService.getProductDetail(id).pipe(
            catchError((error: unknown) => {
              const apiError = mapApiError(error);
              this.errorMessage.set(apiError.message);
              return of(null);
            }),
          );
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((detail) => {
        this.detail.set(detail);
        this.loading.set(false);
      });
  }

  formatTimestamp(raw: string): string {
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return raw;
    }
    return date.toLocaleString();
  }
}
