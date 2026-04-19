import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { catchError, of, switchMap } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import { ProductDetailDto, ProductNutritionDto, ProductPriceDto } from '../../../core/models/catalog.model';
import { CatalogService } from '../../../core/services/catalog.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { PageHeaderComponent } from '../../../shared/components/page-header/page-header.component';

interface NutritionRow {
  label: string;
  value: string;
}

@Component({
  selector: 'app-product-detail-page',
  imports: [
    RouterLink,
    MatButtonModule,
    MatCardModule,
    MatIconModule,
    EmptyStateComponent,
    LoadingStateComponent,
    PageHeaderComponent,
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
  readonly imageLoadFailed = signal(false);

  readonly subtitle = computed(() => {
    const detail = this.detail();
    if (!detail) {
      return 'Read-only public product profile';
    }
    const brand = detail.brand || 'Unbranded';
    return `${brand} | ${detail.category}`;
  });

  readonly sortedPrices = computed(() => {
    const detail = this.detail();
    if (!detail) {
      return [];
    }

    return [...detail.prices].sort((a, b) => {
      if (a.price !== b.price) {
        return a.price - b.price;
      }
      return new Date(b.observedAt).getTime() - new Date(a.observedAt).getTime();
    });
  });

  readonly bestPrice = computed(() => this.sortedPrices()[0] ?? null);

  constructor() {
    this.route.paramMap
      .pipe(
        switchMap((params) => {
          this.loading.set(true);
          this.errorMessage.set(null);
          this.imageLoadFailed.set(false);

          const id = Number(params.get('id'));
          if (!Number.isFinite(id) || id < 1) {
            this.errorMessage.set('Invalid product id.');
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

  nutritionRows(nutrition: ProductNutritionDto | null): NutritionRow[] {
    if (!nutrition) {
      return [];
    }

    return [
      { label: 'Calories', value: this.formatMeasure(nutrition.calories, 'kcal') },
      { label: 'Protein', value: this.formatMeasure(nutrition.proteinG, 'g') },
      { label: 'Carbs', value: this.formatMeasure(nutrition.carbsG, 'g') },
      { label: 'Fat', value: this.formatMeasure(nutrition.fatG, 'g') },
      { label: 'Serving', value: nutrition.servingSize || '100 g' },
    ];
  }

  formatTimestamp(raw: string): string {
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return raw;
    }
    return date.toLocaleString();
  }

  formatMoney(price: number, currency: string): string {
    return `${price.toFixed(2)} ${currency}`;
  }

  priceRowClass(price: ProductPriceDto): string {
    const best = this.bestPrice();
    if (best && best.supermarketId === price.supermarketId && best.price === price.price) {
      return 'price-row-best';
    }
    return '';
  }

  onImageError(): void {
    this.imageLoadFailed.set(true);
  }

  private formatMeasure(value: number | null, unit: string): string {
    if (value == null || !Number.isFinite(value)) {
      return '-';
    }
    return `${value} ${unit}`;
  }
}
