import { ComponentFixture, TestBed, fakeAsync, tick } from '@angular/core/testing';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { provideRouter } from '@angular/router';
import { of } from 'rxjs';
import { CatalogService } from '../../../core/services/catalog.service';
import { ProductListPageComponent } from './product-list.page';

describe('ProductListPageComponent', () => {
  let fixture: ComponentFixture<ProductListPageComponent>;
  let component: ProductListPageComponent;
  let catalogService: jasmine.SpyObj<CatalogService>;

  const items = [
    {
      id: 1,
      name: 'Milk 3.2% 1L',
      brand: 'Bucen Kozjak',
      barcode: '123',
      category: 'Dairy & Eggs',
      nutrition: null,
      bestPrice: 62,
      bestPriceSupermarket: 'Tinex',
      currency: 'MKD',
    },
  ];

  beforeEach(async () => {
    catalogService = jasmine.createSpyObj<CatalogService>('CatalogService', ['getProducts']);
    catalogService.getProducts.and.returnValue(of(items));

    await TestBed.configureTestingModule({
      imports: [ProductListPageComponent],
      providers: [
        provideNoopAnimations(),
        provideRouter([]),
        { provide: CatalogService, useValue: catalogService },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(ProductListPageComponent);
    component = fixture.componentInstance;
  });

  it('renders products returned by service', fakeAsync(() => {
    fixture.detectChanges();
    tick(350);
    fixture.detectChanges();

    expect(catalogService.getProducts).toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Milk 3.2% 1L');
  }));

  it('triggers new search request when query changes', fakeAsync(() => {
    fixture.detectChanges();
    tick(350);
    component.searchControl.setValue('milk');
    tick(350);

    expect(catalogService.getProducts).toHaveBeenCalledWith('milk');
  }));
});
