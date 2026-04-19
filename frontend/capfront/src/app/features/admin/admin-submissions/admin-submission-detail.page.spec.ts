import { ComponentFixture, TestBed } from '@angular/core/testing';
import { convertToParamMap, provideRouter } from '@angular/router';
import { ActivatedRoute } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { MatDialog } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { of, throwError } from 'rxjs';
import { CatalogService } from '../../../core/services/catalog.service';
import { ModerationService } from '../../../core/services/moderation.service';
import { AdminSubmissionDetailPageComponent } from './admin-submission-detail.page';

describe('AdminSubmissionDetailPageComponent', () => {
  let fixture: ComponentFixture<AdminSubmissionDetailPageComponent>;
  let component: AdminSubmissionDetailPageComponent;
  let moderationService: jasmine.SpyObj<ModerationService>;
  let catalogService: jasmine.SpyObj<CatalogService>;
  let dialog: jasmine.SpyObj<MatDialog>;

  const detail = {
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
    contributorScore: 12,
    createdAt: '2026-04-15T13:20:00Z',
    updatedAt: '2026-04-15T13:20:00Z',
    aiSummary: null,
  };

  beforeEach(async () => {
    moderationService = jasmine.createSpyObj<ModerationService>('ModerationService', [
      'getSubmission',
      'getSubmissionHistory',
      'patchSubmissionPayload',
      'refreshAiReview',
      'approve',
      'reject',
    ]);
    catalogService = jasmine.createSpyObj<CatalogService>('CatalogService', [
      'getProductDetail',
      'getSupermarkets',
    ]);
    dialog = jasmine.createSpyObj<MatDialog>('MatDialog', ['open']);
    const snackBar = jasmine.createSpyObj<MatSnackBar>('MatSnackBar', ['open']);

    moderationService.getSubmission.and.returnValue(of(detail));
    moderationService.getSubmissionHistory.and.returnValue(
      of({
        submissionId: 10,
        entries: [],
      }),
    );
    moderationService.patchSubmissionPayload.and.returnValue(
      of({
        submission: detail,
        changedFieldCount: 1,
      }),
    );
    moderationService.refreshAiReview.and.returnValue(
      of({
        analysisId: 11,
        analysisType: 'REVIEW',
        status: 'COMPLETED',
        model: 'gpt-4.1-mini',
        promptVersion: 'v1',
        confidence: 0.88,
        flags: [],
        warnings: ['Potential outlier price'],
        updatedAt: '2026-04-17T10:00:00Z',
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
    catalogService.getSupermarkets.and.returnValue(of([{ id: 2, name: 'Tinex' }]));

    await TestBed.configureTestingModule({
      imports: [AdminSubmissionDetailPageComponent],
      providers: [
        provideNoopAnimations(),
        provideRouter([]),
        {
          provide: ActivatedRoute,
          useValue: {
            paramMap: of(convertToParamMap({ id: '10' })),
            queryParamMap: of(convertToParamMap({ status: 'PENDING', page: '0', size: '10' })),
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

  it('loads direct submission detail and history', () => {
    expect(moderationService.getSubmission).toHaveBeenCalledWith(10);
    expect(moderationService.getSubmissionHistory).toHaveBeenCalledWith(10);
    expect(component.submission()?.id).toBe(10);
  });

  it('patches payload from typed form', () => {
    component.editForm.patchValue({
      name: 'Edited Banana 2',
      barcode: '1000000000001',
      categoryId: 1,
      supermarketId: 2,
      price: 70,
    });

    component.onPatchPayload();

    expect(moderationService.patchSubmissionPayload).toHaveBeenCalled();
  });

  it('refreshes ai review hints', () => {
    component.onRefreshAiReview();
    expect(moderationService.refreshAiReview).toHaveBeenCalledWith(10);
  });

  it('rejects with a required reason from decision dialog', () => {
    dialog.open.and.returnValue({
      afterClosed: () => of('incorrect values'),
    } as never);

    component.onReject();

    expect(moderationService.reject).toHaveBeenCalledWith(10, 'incorrect values');
  });

  it('shows field-level patch errors from backend validation', () => {
    moderationService.patchSubmissionPayload.and.returnValue(
      throwError(
        () =>
          new HttpErrorResponse({
            status: 400,
            error: {
              status: 400,
              message: 'Validation failed',
              fieldErrors: [{ field: 'payload.price', message: 'must be greater than zero' }],
            },
          }),
      ),
    );

    component.editForm.patchValue({
      name: 'Edited Banana 2',
      barcode: '1000000000001',
      categoryId: 1,
      supermarketId: 2,
      price: 70,
    });

    component.onPatchPayload();

    expect(component.patchFieldErrorEntries().length).toBe(1);
    expect(component.patchFieldErrorEntries()[0].field).toBe('payload.price');
  });

  it('handles optimistic concurrency conflicts by reloading latest detail', () => {
    moderationService.patchSubmissionPayload.and.returnValue(
      throwError(
        () =>
          new HttpErrorResponse({
            status: 409,
            error: {
              status: 409,
              message: 'Conflict',
              fieldErrors: [],
            },
          }),
      ),
    );

    component.editForm.patchValue({
      name: 'Edited Banana 2',
      barcode: '1000000000001',
      categoryId: 1,
      supermarketId: 2,
      price: 70,
    });

    component.onPatchPayload();

    expect(component.patchMessage()).toContain('updated by another moderator');
    expect(moderationService.getSubmission).toHaveBeenCalledTimes(2);
  });
});
