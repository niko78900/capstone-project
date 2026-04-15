import { ComponentFixture, TestBed } from '@angular/core/testing';
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
    type: 'PRICE' as const,
    status: 'PENDING' as const,
    payload: { productId: 1, price: 55.5 },
    notes: null,
    submittedByUserId: 2,
    submittedByEmail: 'user@example.com',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
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

    moderationService.getSubmissions.and.returnValue(of([pendingSubmission]));
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
        reason: 'Wrong value',
        reviewedAt: new Date().toISOString(),
      }),
    );
    catalogService.getProductDetail.and.returnValue(
      of({
        id: 1,
        name: 'Test Product',
        brand: 'Test Brand',
        barcode: '1234567890',
        imageUrl: null,
        category: 'Dairy & Eggs',
        nutrition: null,
        prices: [],
      }),
    );

    await TestBed.configureTestingModule({
      imports: [AdminSubmissionsPageComponent],
      providers: [
        provideNoopAnimations(),
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

  it('loads pending submissions on init', () => {
    expect(moderationService.getSubmissions).toHaveBeenCalledWith('PENDING');
    expect(component.submissions().length).toBe(1);
  });

  it('reloads submissions when status filter changes', () => {
    component.statusControl.setValue('APPROVED');
    expect(moderationService.getSubmissions).toHaveBeenCalledWith('APPROVED');
  });

  it('approves submission with reason from dialog', () => {
    dialog.open.and.returnValue({
      afterClosed: () => of('looks valid'),
    } as never);

    component.onApprove(pendingSubmission);

    expect(moderationService.approve).toHaveBeenCalledWith(10, 'looks valid');
  });

  it('approves submission when dialog reason is blank', () => {
    dialog.open.and.returnValue({
      afterClosed: () => of(''),
    } as never);

    component.onApprove(pendingSubmission);

    expect(moderationService.approve).toHaveBeenCalledWith(10, '');
  });
});
