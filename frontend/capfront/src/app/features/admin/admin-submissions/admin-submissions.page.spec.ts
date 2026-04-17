import { ComponentFixture, TestBed, fakeAsync, tick } from '@angular/core/testing';
import { convertToParamMap, provideRouter } from '@angular/router';
import { ActivatedRoute } from '@angular/router';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { of } from 'rxjs';
import { CatalogService } from '../../../core/services/catalog.service';
import { ModerationService } from '../../../core/services/moderation.service';
import { AdminSubmissionsPageComponent } from './admin-submissions.page';

describe('AdminSubmissionsPageComponent', () => {
  let fixture: ComponentFixture<AdminSubmissionsPageComponent>;
  let component: AdminSubmissionsPageComponent;
  let moderationService: jasmine.SpyObj<ModerationService>;
  let catalogService: jasmine.SpyObj<CatalogService>;
  let dialog: jasmine.SpyObj<MatDialog>;

  const pendingSubmission = {
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
    reviewReason: null,
    submittedByUserId: 2,
    submittedByEmail: 'user@example.com',
    createdAt: '2026-04-15T13:20:00Z',
    updatedAt: '2026-04-15T13:20:00Z',
  };

  const secondPendingSubmission = {
    id: 11,
    type: 'PRICE' as const,
    status: 'PENDING' as const,
    payload: {
      productId: 1,
      supermarketId: 2,
      price: 59.99,
    },
    notes: null,
    reviewReason: 'Already verified by another admin',
    submittedByUserId: 3,
    submittedByEmail: 'another@example.com',
    createdAt: '2026-04-16T08:10:00Z',
    updatedAt: '2026-04-16T08:10:00Z',
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
        return of([pendingSubmission, secondPendingSubmission]);
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
        reason: 'Wrong data',
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
      imports: [AdminSubmissionsPageComponent],
      providers: [
        provideNoopAnimations(),
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            queryParamMap: of(convertToParamMap({ status: 'PENDING' })),
          },
        },
        { provide: ModerationService, useValue: moderationService },
        { provide: CatalogService, useValue: catalogService },
        { provide: MatDialog, useValue: dialog },
        { provide: MatSnackBar, useValue: snackBar },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminSubmissionsPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('loads pending submissions and renders review links', () => {
    expect(moderationService.getSubmissions).toHaveBeenCalledWith('PENDING');
    expect(component.submissions().length).toBe(2);
    expect(fixture.nativeElement.textContent).toContain('Open full review');
  });

  it('filters submissions by text search', fakeAsync(() => {
    component.searchControl.setValue('another@example.com');
    tick();
    fixture.detectChanges();

    expect(component.visibleSubmissions().length).toBe(1);
    expect(component.visibleSubmissions()[0].id).toBe(11);
  }));

  it('approves a submission when dialog returns reason', () => {
    dialog.open.and.returnValue({
      afterClosed: () => of('looks valid'),
    } as never);

    component.onApprove(pendingSubmission);

    expect(moderationService.approve).toHaveBeenCalledWith(10, 'looks valid');
  });

  it('rejects a submission when dialog returns required reason', () => {
    dialog.open.and.returnValue({
      afterClosed: () => of('wrong barcode'),
    } as never);

    component.onReject(pendingSubmission);

    expect(moderationService.reject).toHaveBeenCalledWith(10, 'wrong barcode');
  });

  it('does not call reject when dialog is cancelled', () => {
    dialog.open.and.returnValue({
      afterClosed: () => of(undefined),
    } as never);

    component.onReject(pendingSubmission);

    expect(moderationService.reject).not.toHaveBeenCalled();
  });
});
