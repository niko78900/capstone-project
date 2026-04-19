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
  ];

  beforeEach(async () => {
    catalogService = jasmine.createSpyObj<CatalogService>('CatalogService', ['getProducts', 'getSupermarkets']);
    catalogService.getProducts.and.returnValue(of(items));
    catalogService.getSupermarkets.and.returnValue(
      of([
        { id: 1, name: 'Tinex' },
        { id: 2, name: 'Vero' },
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
  }));

  it('triggers new search request when query changes', fakeAsync(() => {
    createComponent();
    fixture.detectChanges();
    tick(300);

    component.searchControl.setValue('milk');
    tick(300);

    expect(catalogService.getProducts).toHaveBeenCalledWith('milk');
  }));

  it('sorts products by price ascending when selected', fakeAsync(() => {
    createComponent();
    fixture.detectChanges();
    tick(300);

    component.sortControl.setValue('PRICE_ASC');
    fixture.detectChanges();

    expect(component.sortedProducts()[0].id).toBe(2);
  }));

  it('filters products by category and supermarket', fakeAsync(() => {
    createComponent();
    fixture.detectChanges();
    tick(300);

    component.categoryControl.setValue('Fruits & Vegetables');
    component.supermarketControl.setValue('Vero');
    fixture.detectChanges();

    expect(component.sortedProducts().length).toBe(1);
    expect(component.sortedProducts()[0].name).toBe('Apple Gala');
  }));
});
