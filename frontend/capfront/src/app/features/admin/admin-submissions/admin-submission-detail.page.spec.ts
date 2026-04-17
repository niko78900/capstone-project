import { ComponentFixture, TestBed } from '@angular/core/testing';
import { convertToParamMap, provideRouter } from '@angular/router';
import { ActivatedRoute } from '@angular/router';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { of } from 'rxjs';
import { CatalogService } from '../../../core/services/catalog.service';
import { ModerationService } from '../../../core/services/moderation.service';
import { AdminSubmissionDetailPageComponent } from './admin-submission-detail.page';

describe('AdminSubmissionDetailPageComponent', () => {
  let fixture: ComponentFixture<AdminSubmissionDetailPageComponent>;
  let component: AdminSubmissionDetailPageComponent;
  let moderationService: jasmine.SpyObj<ModerationService>;
  let catalogService: jasmine.SpyObj<CatalogService>;
  let dialog: jasmine.SpyObj<MatDialog>;

  const submission = {
    id: 10,
    type: 'PRODUCT' as const,
    status: 'PENDING' as const,
    payload: {
      categoryId: 1,
      sourceProductId: 1,
      name: 'Edited Banana',
      brand: 'Fresh Farms',
      barcode: '1000000000001',
      supermarketId: 2,
      price: 66.2,
      imageUrl: '/uploads/evidence-banana.jpg',
    },
    notes: 'Looks fresh',
    submittedByUserId: 2,
    submittedByEmail: 'user@example.com',
    createdAt: '2026-04-15T13:20:00Z',
    updatedAt: '2026-04-15T13:20:00Z',
  };

  beforeEach(async () => {
    moderationService = jasmine.createSpyObj<ModerationService>('ModerationService', [
      'getSubmissions',
      'approve',
      'reject',
    ]);
    catalogService = jasmine.createSpyObj<CatalogService>('CatalogService', ['getProductDetail']);
    dialog = jasmine.createSpyObj<MatDialog>('MatDialog', ['open']);
    const snackBar = jasmine.createSpyObj<MatSnackBar>('MatSnackBar', ['open']);

    moderationService.getSubmissions.and.callFake((status) => {
      if (status === 'PENDING') {
        return of([submission]);
      }
      return of([]);
    });

    moderationService.approve.and.returnValue(
      of({
        submissionId: 10,
        status: 'APPROVED',
        action: 'APPROVED',
        reason: null,
        reviewedAt: new Date().toISOString(),
      }),
    );

    moderationService.reject.and.returnValue(
      of({
        submissionId: 10,
        status: 'REJECTED',
        action: 'REJECTED',
        reason: 'Incorrect payload',
        reviewedAt: new Date().toISOString(),
      }),
    );

    catalogService.getProductDetail.and.returnValue(
      of({
        id: 1,
        name: 'Banana',
        brand: 'Fresh Farms',
        barcode: '1000000000001',
        imageUrl: null,
        category: 'Fruits and Vegetables',
        nutrition: null,
        prices: [],
      }),
    );

    await TestBed.configureTestingModule({
      imports: [AdminSubmissionDetailPageComponent],
      providers: [
        provideNoopAnimations(),
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            paramMap: of(convertToParamMap({ id: '10' })),
            queryParamMap: of(convertToParamMap({ status: 'PENDING' })),
          },
        },
        { provide: ModerationService, useValue: moderationService },
        { provide: CatalogService, useValue: catalogService },
        { provide: MatDialog, useValue: dialog },
        { provide: MatSnackBar, useValue: snackBar },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminSubmissionDetailPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('loads and renders full submission detail', () => {
    expect(component.submission()?.id).toBe(10);
    expect(component.payloadFields().length).toBeGreaterThan(0);
    expect(fixture.nativeElement.textContent).toContain('Submitted Fields');
  });

  it('approves the submission from detail view', () => {
    dialog.open.and.returnValue({
      afterClosed: () => of('ready'),
    } as never);

    component.onApprove();

    expect(moderationService.approve).toHaveBeenCalledWith(10, 'ready');
  });
});
