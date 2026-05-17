import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { API_BASE } from '../config/api.config';
import { ProductDetailDto, ProductSummaryDto, SupermarketDto } from '../models/catalog.model';

@Injectable({ providedIn: 'root' })
export class CatalogService {
  private readonly http = inject(HttpClient);

  getProducts(query?: string, supermarketId?: number): Observable<ProductSummaryDto[]> {
    let params = new HttpParams();
    const normalizedQuery = query?.trim();
    if (normalizedQuery) {
      params = params.set('q', normalizedQuery);
    }
    if (supermarketId != null) {
      params = params.set('supermarketId', String(supermarketId));
    }
    return this.http.get<ProductSummaryDto[]>(`${API_BASE}/products`, { params });
  }

  getProductDetail(id: number): Observable<ProductDetailDto> {
    return this.http.get<ProductDetailDto>(`${API_BASE}/products/${id}`);
  }

  getSupermarkets(): Observable<SupermarketDto[]> {
    return this.http.get<SupermarketDto[]>(`${API_BASE}/supermarkets`);
  }
}
