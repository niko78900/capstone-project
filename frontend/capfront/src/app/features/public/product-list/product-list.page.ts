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
import { catchError, debounceTime, distinctUntilChanged, finalize, of, startWith, switchMap } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import { ProductSummaryDto } from '../../../core/models/catalog.model';
import { CatalogService } from '../../../core/services/catalog.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { FilterToolbarComponent } from '../../../shared/components/filter-toolbar/filter-toolbar.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';
import { PageHeaderComponent } from '../../../shared/components/page-header/page-header.component';

type ProductSortOrder = 'RELEVANCE' | 'NAME_ASC' | 'PRICE_ASC' | 'PRICE_DESC';

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

  readonly products = signal<ProductSummaryDto[]>([]);
  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);
  readonly selectedSort = signal<ProductSortOrder>('RELEVANCE');

  readonly hasQuery = computed(() => this.searchControl.value.trim().length > 0);
  readonly resultsSummary = computed(() => {
    const count = this.products().length;
    if (count === 0) {
      return this.hasQuery() ? 'No matching products' : 'No products';
    }
    const noun = count === 1 ? 'product' : 'products';
    return `${count} ${noun} shown`;
  });

  readonly sortedProducts = computed(() => {
    const products = [...this.products()];
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

  constructor() {
    this.searchControl.valueChanges
      .pipe(
        startWith(this.searchControl.value),
        debounceTime(260),
        distinctUntilChanged(),
        switchMap((query) => {
          this.loading.set(true);
          this.errorMessage.set(null);

          return this.catalogService.getProducts(query).pipe(
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
  }

  clearSearch(): void {
    this.searchControl.setValue('');
  }

  sortLabel(sort: ProductSortOrder): string {
    switch (sort) {
      case 'NAME_ASC':
        return 'Name (A-Z)';
      case 'PRICE_ASC':
        return 'Price (low-high)';
      case 'PRICE_DESC':
        return 'Price (high-low)';
      case 'RELEVANCE':
      default:
        return this.hasQuery() ? 'Relevance' : 'Default order';
    }
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
