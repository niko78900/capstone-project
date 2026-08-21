// File purpose: Implements the Angular page for product list page.
import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import {
  catchError,
  combineLatest,
  debounceTime,
  distinctUntilChanged,
  finalize,
  of,
  startWith,
  switchMap,
} from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import { ProductSummaryDto, SupermarketDto } from '../../../core/models/catalog.model';
import { CatalogService } from '../../../core/services/catalog.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { FilterToolbarComponent } from '../../../shared/components/filter-toolbar/filter-toolbar.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { MarketLogoComponent } from '../../../shared/components/market-logo/market-logo.component';
import { PageHeaderComponent } from '../../../shared/components/page-header/page-header.component';

type ProductSortOrder = 'RELEVANCE' | 'NAME_ASC' | 'PRICE_ASC' | 'PRICE_DESC';
type CategoryFilterValue = 'ALL' | string;
type SupermarketFilterValue = 'ALL' | number;

@Component({
  selector: 'app-product-list-page',
  imports: [
    ReactiveFormsModule,
    RouterLink,
    MatButtonModule,
    MatCardModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatSelectModule,
    EmptyStateComponent,
    FilterToolbarComponent,
    LoadingStateComponent,
    MarketLogoComponent,
    PageHeaderComponent,
  ],
  templateUrl: './product-list.page.html',
  styleUrl: './product-list.page.css',
})
export class ProductListPageComponent {
  private readonly catalogService = inject(CatalogService);
  private readonly destroyRef = inject(DestroyRef);

  readonly searchControl = new FormControl('', { nonNullable: true });
  readonly sortControl = new FormControl<ProductSortOrder>('RELEVANCE', { nonNullable: true });
  readonly categoryControl = new FormControl<CategoryFilterValue>('ALL', { nonNullable: true });
  readonly supermarketControl = new FormControl<SupermarketFilterValue>('ALL', {
    nonNullable: true,
  });

  readonly products = signal<ProductSummaryDto[]>([]);
  readonly supermarkets = signal<SupermarketDto[]>([]);
  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);
  readonly selectedSort = signal<ProductSortOrder>('RELEVANCE');
  readonly selectedCategory = signal<CategoryFilterValue>('ALL');
  readonly selectedSupermarketId = signal<SupermarketFilterValue>('ALL');

  readonly hasQuery = computed(() => this.searchControl.value.trim().length > 0);
  readonly categoryOptions = computed(() => {
    const categories = new Set<string>();
    for (const product of this.products()) {
      categories.add(product.category);
    }
    return ['ALL', ...Array.from(categories).sort()] as CategoryFilterValue[];
  });

  readonly filteredProducts = computed(() => {
    const selectedCategory = this.selectedCategory();
    return this.products().filter((product) => {
      if (selectedCategory !== 'ALL' && product.category !== selectedCategory) {
        return false;
      }
      return true;
    });
  });

  readonly sortedProducts = computed(() => {
    const products = [...this.filteredProducts()];
    const sort = this.selectedSort();
    switch (sort) {
      case 'NAME_ASC':
        return products.sort((a, b) => a.name.localeCompare(b.name));
      case 'PRICE_ASC':
        return products.sort((a, b) => {
          const aValue = a.bestPrice ?? Number.POSITIVE_INFINITY;
          const bValue = b.bestPrice ?? Number.POSITIVE_INFINITY;
          return aValue - bValue;
        });
      case 'PRICE_DESC':
        return products.sort((a, b) => {
          const aValue = a.bestPrice ?? Number.NEGATIVE_INFINITY;
          const bValue = b.bestPrice ?? Number.NEGATIVE_INFINITY;
          return bValue - aValue;
        });
      case 'RELEVANCE':
      default:
        return products;
    }
  });

  readonly hasActiveFilters = computed(
    () => this.selectedCategory() !== 'ALL' || this.selectedSupermarketId() !== 'ALL',
  );

  constructor() {
    this.catalogService
      .getSupermarkets()
      .pipe(
        catchError(() => of([])),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((supermarkets) => {
        this.supermarkets.set(supermarkets);
      });

    combineLatest([
      this.searchControl.valueChanges.pipe(
        startWith(this.searchControl.value),
        debounceTime(260),
        distinctUntilChanged(),
      ),
      this.supermarketControl.valueChanges.pipe(
        startWith(this.supermarketControl.value),
        distinctUntilChanged(),
      ),
    ])
      .pipe(
        switchMap(([query, supermarketId]) => {
          this.selectedSupermarketId.set(supermarketId);
          this.loading.set(true);
          this.errorMessage.set(null);

          return this.catalogService
            .getProducts(query, supermarketId === 'ALL' ? undefined : supermarketId)
            .pipe(
              catchError((error: unknown) => {
                const apiError = mapApiError(error);
                this.errorMessage.set(apiError.message);
                return of([]);
              }),
              finalize(() => this.loading.set(false)),
            );
        }),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe((products) => this.products.set(products));

    this.sortControl.valueChanges
      .pipe(startWith(this.sortControl.value), takeUntilDestroyed(this.destroyRef))
      .subscribe((sort) => this.selectedSort.set(sort));

    this.categoryControl.valueChanges
      .pipe(startWith(this.categoryControl.value), takeUntilDestroyed(this.destroyRef))
      .subscribe((category) => this.selectedCategory.set(category));
  }

  clearSearch(): void {
    this.searchControl.setValue('');
  }

  clearFilters(): void {
    this.categoryControl.setValue('ALL');
    this.supermarketControl.setValue('ALL');
  }

  formatPrice(product: ProductSummaryDto): string {
    if (product.bestPrice == null) {
      return 'No verified price';
    }
    return `${product.bestPrice.toFixed(2)} ${product.currency ?? 'MKD'}`;
  }

  priceHint(product: ProductSummaryDto): string {
    if (product.bestPrice == null) {
      return 'Awaiting verified submissions';
    }
    return product.bestPriceSupermarket ?? 'Verified in catalog';
  }
}
