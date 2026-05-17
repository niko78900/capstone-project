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
    {
      id: 2,
      name: 'Apple Gala',
      brand: 'Fresh Farms',
      barcode: '456',
      category: 'Fruits & Vegetables',
      nutrition: null,
      bestPrice: 45,
      bestPriceSupermarket: 'Vero',
      currency: 'MKD',
    },
    {
      id: 3,
      name: 'Pretzels',
      brand: 'Snack Co',
      barcode: '789',
      category: 'Snacks',
      nutrition: null,
      bestPrice: 85,
      bestPriceSupermarket: 'Corner Market',
      currency: 'MKD',
    },
  ];

  beforeEach(async () => {
    catalogService = jasmine.createSpyObj<CatalogService>('CatalogService', ['getProducts', 'getSupermarkets']);
    catalogService.getProducts.and.returnValue(of(items));
    catalogService.getSupermarkets.and.returnValue(
      of([
        { id: 1, name: 'Tinex' },
        { id: 2, name: 'Vero' },
        { id: 3, name: 'Corner Market' },
      ]),
    );

    await TestBed.configureTestingModule({
      imports: [ProductListPageComponent],
      providers: [
        provideNoopAnimations(),
        provideRouter([]),
        { provide: CatalogService, useValue: catalogService },
      ],
    }).compileComponents();
  });

  function createComponent(): void {
    fixture = TestBed.createComponent(ProductListPageComponent);
    component = fixture.componentInstance;
  }

  it('renders products returned by service', fakeAsync(() => {
    createComponent();
    fixture.detectChanges();
    tick(300);
    fixture.detectChanges();

    expect(catalogService.getProducts).toHaveBeenCalled();
    expect(fixture.nativeElement.textContent).toContain('Milk 3.2% 1L');
    expect(
      fixture.nativeElement.querySelector('app-market-logo img[src="/market-logos/tinex.png"]'),
    ).not.toBeNull();
    expect(
      fixture.nativeElement.querySelector('app-market-logo img[src="/market-logos/vero.png"]'),
    ).not.toBeNull();
    expect(fixture.nativeElement.textContent).toContain('CM');
  }));

  it('triggers new search request when query changes', fakeAsync(() => {
    createComponent();
    fixture.detectChanges();
    tick(300);

    component.searchControl.setValue('milk');
    tick(300);

    expect(catalogService.getProducts).toHaveBeenCalledWith('milk', undefined);
  }));

  it('sorts products by price ascending when selected', fakeAsync(() => {
    createComponent();
    fixture.detectChanges();
    tick(300);

    component.sortControl.setValue('PRICE_ASC');
    fixture.detectChanges();

    expect(component.sortedProducts()[0].id).toBe(2);
  }));

  it('filters products by category client-side', fakeAsync(() => {
    createComponent();
    fixture.detectChanges();
    tick(300);

    component.categoryControl.setValue('Fruits & Vegetables');
    fixture.detectChanges();

    expect(component.sortedProducts().length).toBe(1);
    expect(component.sortedProducts()[0].name).toBe('Apple Gala');
  }));

  it('reloads products by supermarket id instead of filtering by best-price supermarket', fakeAsync(() => {
    const veroAvailableButTinexCheapest = {
      id: 4,
      name: 'Corn Flakes',
      brand: 'Breakfast Co',
      barcode: '111',
      category: 'Cereals',
      nutrition: null,
      bestPrice: 99,
      bestPriceSupermarket: 'Tinex',
      currency: 'MKD',
    };
    catalogService.getProducts.and.callFake((_query?: string, supermarketId?: number) =>
      of(supermarketId === 2 ? [veroAvailableButTinexCheapest] : items),
    );

    createComponent();
    fixture.detectChanges();
    tick(300);
    catalogService.getProducts.calls.reset();

    component.supermarketControl.setValue(2);
    tick();
    fixture.detectChanges();

    expect(catalogService.getProducts).toHaveBeenCalledWith('', 2);
    expect(component.sortedProducts().map((product) => product.name)).toEqual(['Corn Flakes']);
    expect(fixture.nativeElement.textContent).toContain('Tinex');
  }));
});
