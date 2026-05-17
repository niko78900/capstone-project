import { ComponentFixture, TestBed } from '@angular/core/testing';
import { convertToParamMap, provideRouter } from '@angular/router';
import { ActivatedRoute } from '@angular/router';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { By } from '@angular/platform-browser';
import { of } from 'rxjs';
import { CatalogService } from '../../../core/services/catalog.service';
import { ProductDetailPageComponent } from './product-detail.page';

describe('ProductDetailPageComponent', () => {
  let fixture: ComponentFixture<ProductDetailPageComponent>;
  let component: ProductDetailPageComponent;
  let catalogService: jasmine.SpyObj<CatalogService>;

  beforeEach(async () => {
    catalogService = jasmine.createSpyObj<CatalogService>('CatalogService', ['getProductDetail']);
    catalogService.getProductDetail.and.returnValue(
      of({
        id: 1,
        name: 'Banana',
        brand: 'Fresh Farms',
        barcode: '1000000000001',
        imageUrl: null,
        category: 'Fruits and Vegetables',
        nutrition: {
          calories: 89,
          proteinG: 1.1,
          carbsG: 22.8,
          fatG: 0.3,
          servingSize: '100 g',
        },
        prices: [
          {
            supermarketId: 1,
            supermarketName: 'Tinex',
            price: 65.5,
            currency: 'MKD',
            observedAt: '2026-04-12T11:00:00Z',
          },
          {
            supermarketId: 99,
            supermarketName: 'Corner Market',
            price: 70,
            currency: 'MKD',
            observedAt: '2026-04-11T11:00:00Z',
          },
        ],
        priceHistory: [
          {
            supermarketId: 1,
            supermarketName: 'Tinex',
            price: 69.5,
            currency: 'MKD',
            observedAt: '2026-03-12T11:00:00Z',
          },
          {
            supermarketId: 1,
            supermarketName: 'Tinex',
            price: 65.5,
            currency: 'MKD',
            observedAt: '2026-04-12T11:00:00Z',
          },
          {
            supermarketId: 2,
            supermarketName: 'Vero',
            price: 72,
            currency: 'MKD',
            observedAt: '2026-04-10T09:00:00Z',
          },
          {
            supermarketId: 99,
            supermarketName: 'Corner Market',
            price: 70,
            currency: 'MKD',
            observedAt: '2026-04-11T11:00:00Z',
          },
        ],
      }),
    );

    await TestBed.configureTestingModule({
      imports: [ProductDetailPageComponent],
      providers: [
        provideNoopAnimations(),
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            paramMap: of(convertToParamMap({ id: '1' })),
          },
        },
        { provide: CatalogService, useValue: catalogService },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(ProductDetailPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('renders product detail with nutrition and prices', () => {
    expect(catalogService.getProductDetail).toHaveBeenCalledWith(1);
    expect(component.detail()?.name).toBe('Banana');
    expect(fixture.nativeElement.textContent).toContain('Verified Supermarket Prices');
    expect(fixture.nativeElement.textContent).toContain('Nutrition Highlights');
    expect(fixture.nativeElement.textContent).toContain('Price History');
    expect(fixture.nativeElement.textContent).toContain('Tinex');
    expect(fixture.nativeElement.textContent).toContain('Vero');
    expect(fixture.nativeElement.querySelector('svg.history-chart')).not.toBeNull();
    expect(
      fixture.nativeElement.querySelector('app-market-logo img[src="/market-logos/tinex.png"]'),
    ).not.toBeNull();
    expect(
      fixture.nativeElement.querySelector('app-market-logo img[src="/market-logos/vero.png"]'),
    ).not.toBeNull();
    expect(fixture.nativeElement.textContent).toContain('CM');
  });

  it('shows a visible price tooltip when a history point is hovered or clicked', () => {
    const point = fixture.debugElement
      .queryAll(By.css('circle.history-point'))
      .find((item) => item.nativeElement.getAttribute('aria-label')?.includes('Tinex'));

    expect(point).toBeDefined();

    point!.triggerEventHandler('mouseenter', {});
    fixture.detectChanges();

    let tooltip = fixture.nativeElement.querySelector('.history-tooltip');
    expect(tooltip).not.toBeNull();
    expect(tooltip.textContent).toContain('Tinex');
    expect(tooltip.textContent).toContain('69.50 MKD');

    point!.triggerEventHandler('click', {});
    fixture.detectChanges();

    tooltip = fixture.nativeElement.querySelector('.history-tooltip');
    expect(tooltip.textContent).toContain('Observed');
  });

  it('shows the latest series price tooltip when a history line is clicked', () => {
    const hitLine = fixture.debugElement.query(By.css('polyline.history-line-hit'));

    expect(hitLine).not.toBeNull();

    hitLine.triggerEventHandler('click', {});
    fixture.detectChanges();

    const tooltip = fixture.nativeElement.querySelector('.history-tooltip');
    expect(tooltip).not.toBeNull();
    expect(tooltip.textContent).toContain('Tinex');
    expect(tooltip.textContent).toContain('65.50 MKD');
  });
});
