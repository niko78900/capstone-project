// File purpose: Covers Angular tests for admin submissions page spec behavior.
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
    contributorScore: 3,
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
      imageUrl: '/uploads/price-evidence.jpg',
    },
    notes: null,
    reviewReason: 'Already verified by another admin',
    submittedByUserId: 3,
    submittedByEmail: 'another@example.com',
    contributorScore: 0,
    createdAt: '2026-04-16T08:10:00Z',
    updatedAt: '2026-04-16T08:10:00Z',
  };

  beforeEach(async () => {
    moderationService = jasmine.createSpyObj<ModerationService>('ModerationService', [
      'listSubmissions',
      'getSubmission',
      'patchSubmissionPayload',
      'approve',
      'reject',
    ]);
    catalogService = jasmine.createSpyObj<CatalogService>('CatalogService', [
      'getProductDetail',
      'getSupermarkets',
    ]);
    dialog = jasmine.createSpyObj<MatDialog>('MatDialog', ['open']);
    const snackBar = jasmine.createSpyObj<MatSnackBar>('MatSnackBar', ['open']);

    moderationService.listSubmissions.and.returnValue(
      of({
        items: [pendingSubmission, secondPendingSubmission],
        totalElements: 2,
        page: 0,
        size: 10,
        totalPages: 1,
      }),
    );

    moderationService.getSubmission.and.returnValue(
      of({
        ...pendingSubmission,
        contributorScore: 3,
        aiSummary: {
          analysisId: 1,
          analysisType: 'REVIEW',
          status: 'COMPLETED',
          model: 'gpt-4.1-mini',
          promptVersion: 'v1',
          confidence: 0.92,
          flags: [],
          warnings: [],
          updatedAt: '2026-04-17T08:10:00Z',
        },
      }),
    );

    moderationService.approve.and.returnValue(
      of({
        submissionId: 10,
        status: 'APPROVED',
        action: 'APPROVED',
        reason: null,
        rejectionSeverity: null,
        reviewedAt: new Date().toISOString(),
      }),
    );

    moderationService.patchSubmissionPayload.and.returnValue(
      of({
        submission: {
          ...pendingSubmission,
          contributorScore: 3,
          aiSummary: null,
          payload: {
            ...pendingSubmission.payload,
            name: 'Banana edited in queue',
          },
          updatedAt: '2026-04-17T08:30:00Z',
        },
        changedFieldCount: 1,
      }),
    );

    moderationService.reject.and.returnValue(
      of({
        submissionId: 10,
        status: 'REJECTED',
        action: 'REJECTED',
        reason: 'Wrong data',
        rejectionSeverity: 'BAD',
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
        priceHistory: [],
        unavailableMarkets: [],
      }),
    );
    catalogService.getSupermarkets.and.returnValue(of([{ id: 2, name: 'Tinex' }]));

    await TestBed.configureTestingModule({
      imports: [AdminSubmissionsPageComponent],
      providers: [
        provideNoopAnimations(),
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            queryParamMap: of(
              convertToParamMap({
                status: 'PENDING',
                type: 'ALL',
                sort: 'NEWEST',
                page: '0',
                size: '10',
              }),
            ),
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

  it('loads server-driven submissions', () => {
    expect(moderationService.listSubmissions).toHaveBeenCalled();
    expect(moderationService.listSubmissions).toHaveBeenCalledWith({
      status: 'PENDING',
      type: undefined,
      q: undefined,
      sort: 'createdAt,desc',
      page: 0,
      size: 10,
    });
    expect(component.totalResults()).toBe(2);
    expect(component.pagedSubmissions().length).toBe(2);
  });

  it('exposes evidence image urls for price submissions', () => {
    expect(component.evidenceImageUrl(secondPendingSubmission)).toBe('/uploads/price-evidence.jpg');
  });

  it('updates search query and triggers route sync', fakeAsync(() => {
    component.searchControl.setValue('another@example.com');
    tick(300);
    expect(component.searchQuery()).toBe('another@example.com');
  }));

  it('approves a submission when dialog returns reason', () => {
    dialog.open.and.returnValue({
      afterClosed: () => of({ reason: 'looks valid' }),
    } as never);

    component.onApprove(pendingSubmission);

    expect(moderationService.approve).toHaveBeenCalledWith(10, 'looks valid');
  });

  it('rejects a submission when dialog returns required reason', () => {
    dialog.open.and.returnValue({
      afterClosed: () => of({ reason: 'wrong barcode', rejectionSeverity: 'BAD' }),
    } as never);

    component.onReject(pendingSubmission);

    expect(moderationService.reject).toHaveBeenCalledWith(10, 'wrong barcode', 'BAD');
  });

  it('maps contributor score sort to server token', () => {
    moderationService.listSubmissions.calls.reset();

    component.sortControl.setValue('CONTRIBUTOR_SCORE', { emitEvent: false });
    (component as unknown as { loadSubmissionsFromServer: () => void }).loadSubmissionsFromServer();

    expect(moderationService.listSubmissions).toHaveBeenCalledWith({
      status: 'PENDING',
      type: undefined,
      q: undefined,
      sort: 'contributorScore,desc',
      page: 0,
      size: 10,
    });
  });

  it('patches submission payload when edit dialog returns updated payload', () => {
    dialog.open.and.returnValue({
      afterClosed: () =>
        of({
          payload: {
            ...pendingSubmission.payload,
            name: 'Banana edited in queue',
          },
          editReason: 'Fix typo',
        }),
    } as never);

    component.onEditPayload(pendingSubmission);

    expect(moderationService.patchSubmissionPayload).toHaveBeenCalledWith(10, {
      payload: {
        ...pendingSubmission.payload,
        name: 'Banana edited in queue',
      },
      editReason: 'Fix typo',
      expectedUpdatedAt: pendingSubmission.updatedAt,
    });
  });
});
