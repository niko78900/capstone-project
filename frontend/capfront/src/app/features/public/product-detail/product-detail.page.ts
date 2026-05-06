import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { catchError, of, switchMap } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import {
  ProductDetailDto,
  ProductNutritionDto,
  ProductPriceDto,
  ProductPriceHistoryPointDto,
} from '../../../core/models/catalog.model';
import { CatalogService } from '../../../core/services/catalog.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { PageHeaderComponent } from '../../../shared/components/page-header/page-header.component';

interface NutritionRow {
  label: string;
  value: string;
}

interface PriceHistoryChartPoint {
  key: string;
  cx: number;
  cy: number;
  label: string;
}

interface PriceHistorySeries {
  supermarketId: number;
  supermarketName: string;
  color: string;
  points: PriceHistoryChartPoint[];
  svgPoints: string;
  latestPrice: number;
  currency: string;
}

interface PriceHistoryChart {
  series: PriceHistorySeries[];
  minPriceLabel: string;
  maxPriceLabel: string;
  startDateLabel: string;
  endDateLabel: string;
}

interface ParsedHistoryPoint extends ProductPriceHistoryPointDto {
  timeMs: number;
}

const CHART_LEFT = 58;
const CHART_RIGHT = 700;
const CHART_TOP = 24;
const CHART_BOTTOM = 210;
const CHART_COLORS = [
  '#1a7f64',
  '#2563eb',
  '#dc2626',
  '#9333ea',
  '#ca8a04',
  '#0891b2',
  '#db2777',
  '#4f46e5',
];

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
  readonly priceHistoryChart = computed<PriceHistoryChart | null>(() => {
    const detail = this.detail();
    const rawHistory = detail?.priceHistory ?? [];
    const parsed = rawHistory
      .map((point): ParsedHistoryPoint | null => {
        const timeMs = new Date(point.observedAt).getTime();
        if (!Number.isFinite(timeMs) || !Number.isFinite(point.price)) {
          return null;
        }
        return { ...point, timeMs };
      })
      .filter((point): point is ParsedHistoryPoint => point !== null)
      .sort((a, b) => a.timeMs - b.timeMs);

    if (parsed.length === 0) {
      return null;
    }

    const minTime = Math.min(...parsed.map((point) => point.timeMs));
    const maxTime = Math.max(...parsed.map((point) => point.timeMs));
    const minPriceRaw = Math.min(...parsed.map((point) => point.price));
    const maxPriceRaw = Math.max(...parsed.map((point) => point.price));
    const pricePadding = Math.max((maxPriceRaw - minPriceRaw) * 0.08, 1);
    const minPrice = Math.max(0, minPriceRaw - pricePadding);
    const maxPrice = maxPriceRaw + pricePadding;
    const grouped = new Map<number, ParsedHistoryPoint[]>();

    for (const point of parsed) {
      const list = grouped.get(point.supermarketId) ?? [];
      list.push(point);
      grouped.set(point.supermarketId, list);
    }

    const series = Array.from(grouped.entries())
      .map(([supermarketId, points], index) => {
        const chartPoints = points.map((point) => {
          const cx = this.scale(point.timeMs, minTime, maxTime, CHART_LEFT, CHART_RIGHT);
          const cy = this.scale(point.price, minPrice, maxPrice, CHART_BOTTOM, CHART_TOP);
          return {
            key: `${point.supermarketId}-${point.observedAt}-${point.price}`,
            cx,
            cy,
            label: `${point.supermarketName}: ${this.formatMoney(point.price, point.currency)} on ${this.formatShortDate(point.observedAt)}`,
          };
        });
        const latest = points[points.length - 1];
        return {
          supermarketId,
          supermarketName: latest.supermarketName,
          color: this.marketColor(supermarketId, index),
          points: chartPoints,
          svgPoints: chartPoints.map((point) => `${point.cx},${point.cy}`).join(' '),
          latestPrice: latest.price,
          currency: latest.currency || 'MKD',
        };
      })
      .sort((a, b) => a.supermarketName.localeCompare(b.supermarketName));

    return {
      series,
      minPriceLabel: this.formatMoney(minPriceRaw, parsed[0].currency || 'MKD'),
      maxPriceLabel: this.formatMoney(maxPriceRaw, parsed[0].currency || 'MKD'),
      startDateLabel: this.formatShortDate(new Date(minTime).toISOString()),
      endDateLabel: this.formatShortDate(new Date(maxTime).toISOString()),
    };
  });

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

  formatShortDate(raw: string): string {
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) {
      return raw;
    }
    return date.toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  }

  onImageError(): void {
    this.imageLoadFailed.set(true);
  }

  private scale(
    value: number,
    min: number,
    max: number,
    targetMin: number,
    targetMax: number,
  ): number {
    if (max <= min) {
      return (targetMin + targetMax) / 2;
    }
    return targetMin + ((value - min) / (max - min)) * (targetMax - targetMin);
  }

  private marketColor(supermarketId: number, index: number): string {
    if (index < CHART_COLORS.length) {
      return CHART_COLORS[index];
    }
    const hue = Math.abs(supermarketId * 47) % 360;
    return `hsl(${hue} 68% 42%)`;
  }

  private formatMeasure(value: number | null, unit: string): string {
    if (value == null || !Number.isFinite(value)) {
      return '-';
    }
    return `${value} ${unit}`;
  }
}
