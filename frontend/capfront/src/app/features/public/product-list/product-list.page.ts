import { Component, DestroyRef, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { catchError, debounceTime, distinctUntilChanged, finalize, of, startWith, switchMap } from 'rxjs';
import { mapApiError } from '../../../core/models/api-error.model';
import { ProductSummaryDto } from '../../../core/models/catalog.model';
import { CatalogService } from '../../../core/services/catalog.service';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LoadingStateComponent } from '../../../shared/components/loading-state/loading-state.component';

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
    EmptyStateComponent,
    LoadingStateComponent,
  ],
  templateUrl: './product-list.page.html',
  styleUrl: './product-list.page.css',
})
export class ProductListPageComponent {
  private readonly catalogService = inject(CatalogService);
  private readonly destroyRef = inject(DestroyRef);

  readonly searchControl = new FormControl('', { nonNullable: true });

  readonly products = signal<ProductSummaryDto[]>([]);
  readonly loading = signal(true);
  readonly errorMessage = signal<string | null>(null);

  constructor() {
    this.searchControl.valueChanges
      .pipe(
        startWith(this.searchControl.value),
        debounceTime(300),
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
  }

  formatPrice(product: ProductSummaryDto): string {
    if (product.bestPrice == null) {
      return 'No verified price';
    }
    return `${product.bestPrice.toFixed(2)} ${product.currency ?? 'MKD'}`;
  }
}
