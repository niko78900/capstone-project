import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { API_BASE } from '../config/api.config';
import { ProductDetailDto, ProductSummaryDto } from '../models/catalog.model';

@Injectable({ providedIn: 'root' })
export class CatalogService {
  private readonly http = inject(HttpClient);

  getProducts(query?: string): Observable<ProductSummaryDto[]> {
    const params = query ? new HttpParams().set('q', query) : undefined;
    return this.http.get<ProductSummaryDto[]>(`${API_BASE}/products`, { params });
  }

  getProductDetail(id: number): Observable<ProductDetailDto> {
    return this.http.get<ProductDetailDto>(`${API_BASE}/products/${id}`);
  }
}
