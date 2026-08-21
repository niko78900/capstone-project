// File purpose: Covers Angular tests for catalog service spec behavior.
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { CatalogService } from './catalog.service';

describe('CatalogService', () => {
  let service: CatalogService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(CatalogService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('sends query and supermarket id when listing products', () => {
    service.getProducts(' milk ', 2).subscribe((products) => {
      expect(products).toEqual([]);
    });

    const request = httpMock.expectOne(
      (req) =>
        req.url === '/api/v1/products' &&
        req.params.get('q') === 'milk' &&
        req.params.get('supermarketId') === '2',
    );

    expect(request.request.method).toBe('GET');
    request.flush([]);
  });
});
