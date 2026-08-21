// File purpose: Covers Angular tests for admin users page spec behavior.
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { of, throwError } from 'rxjs';
import { PasswordResetService } from '../../../core/services/password-reset.service';
import { AdminUsersPageComponent } from './admin-users.page';

describe('AdminUsersPageComponent', () => {
  let fixture: ComponentFixture<AdminUsersPageComponent>;
  let component: AdminUsersPageComponent;
  let passwordResetService: jasmine.SpyObj<PasswordResetService>;

  const pendingRequest = {
    id: 7,
    requesterEmail: 'user@example.com',
    matchedUserId: 3,
    matchedUserDisplayName: 'Reset User',
    status: 'PENDING' as const,
    expiresAt: '2026-05-14T10:00:00Z',
    decidedByEmail: null,
    decisionReason: null,
    decisionAt: null,
    completedAt: null,
    createdAt: '2026-05-13T10:00:00Z',
    updatedAt: '2026-05-13T10:00:00Z',
  };

  beforeEach(async () => {
    passwordResetService = jasmine.createSpyObj<PasswordResetService>('PasswordResetService', [
      'listAdminRequests',
      'approveAdminRequest',
      'denyAdminRequest',
    ]);
    passwordResetService.listAdminRequests.and.returnValue(
      of({
        items: [pendingRequest],
        totalElements: 1,
        page: 0,
        size: 10,
        totalPages: 1,
      }),
    );
    passwordResetService.approveAdminRequest.and.returnValue(
      of({ ...pendingRequest, status: 'APPROVED' as const }),
    );
    passwordResetService.denyAdminRequest.and.returnValue(
      of({ ...pendingRequest, status: 'DENIED' as const }),
    );

    await TestBed.configureTestingModule({
      imports: [AdminUsersPageComponent],
      providers: [
        provideNoopAnimations(),
        { provide: PasswordResetService, useValue: passwordResetService },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminUsersPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  afterEach(() => {
    TestBed.resetTestingModule();
  });

  it('loads pending password reset requests', () => {
    expect(passwordResetService.listAdminRequests).toHaveBeenCalledWith({
      status: 'PENDING',
      page: 0,
      size: 10,
    });
    expect(component.requests()).toEqual([pendingRequest]);
    expect(fixture.nativeElement.textContent).toContain('user@example.com');
  });

  it('loads the next page with current size and status', () => {
    passwordResetService.listAdminRequests.calls.reset();
    passwordResetService.listAdminRequests.and.returnValue(
      of({
        items: [],
        totalElements: 22,
        page: 1,
        size: 10,
        totalPages: 3,
      }),
    );
    component.totalResults.set(22);

    component.goToNextPage();

    expect(passwordResetService.listAdminRequests).toHaveBeenCalledWith({
      status: 'PENDING',
      page: 1,
      size: 10,
    });
  });

  it('resets to the first page when page size changes', () => {
    passwordResetService.listAdminRequests.calls.reset();
    passwordResetService.listAdminRequests.and.returnValue(
      of({
        items: [pendingRequest],
        totalElements: 1,
        page: 0,
        size: 25,
        totalPages: 1,
      }),
    );
    component.pageIndex.set(2);

    component.pageSizeControl.setValue(25);

    expect(component.pageIndex()).toBe(0);
    expect(passwordResetService.listAdminRequests).toHaveBeenCalledWith({
      status: 'PENDING',
      page: 0,
      size: 25,
    });
  });

  it('resets to the first page when status filter changes', () => {
    passwordResetService.listAdminRequests.calls.reset();
    passwordResetService.listAdminRequests.and.returnValue(
      of({
        items: [],
        totalElements: 0,
        page: 0,
        size: 10,
        totalPages: 0,
      }),
    );
    component.pageIndex.set(2);

    component.statusControl.setValue('APPROVED');

    expect(component.pageIndex()).toBe(0);
    expect(passwordResetService.listAdminRequests).toHaveBeenCalledWith({
      status: 'APPROVED',
      page: 0,
      size: 10,
    });
  });

  it('omits status when all statuses filter is selected', () => {
    passwordResetService.listAdminRequests.calls.reset();
    passwordResetService.listAdminRequests.and.returnValue(
      of({
        items: [pendingRequest],
        totalElements: 1,
        page: 0,
        size: 10,
        totalPages: 1,
      }),
    );

    component.statusControl.setValue('ALL');

    expect(passwordResetService.listAdminRequests).toHaveBeenCalledWith({
      status: undefined,
      page: 0,
      size: 10,
    });
  });

  it('approves a pending request and reloads the list', () => {
    component.approve(pendingRequest);

    expect(passwordResetService.approveAdminRequest).toHaveBeenCalledWith(7);
    expect(passwordResetService.listAdminRequests).toHaveBeenCalledTimes(2);
  });

  it('reloads previous page when approve empties the current page', () => {
    passwordResetService.listAdminRequests.calls.reset();
    passwordResetService.listAdminRequests.and.returnValues(
      of({
        items: [],
        totalElements: 10,
        page: 1,
        size: 10,
        totalPages: 1,
      }),
      of({
        items: [pendingRequest],
        totalElements: 10,
        page: 0,
        size: 10,
        totalPages: 1,
      }),
    );
    component.pageIndex.set(1);

    component.approve(pendingRequest);

    expect(passwordResetService.listAdminRequests.calls.argsFor(0)[0]).toEqual({
      status: 'PENDING',
      page: 1,
      size: 10,
    });
    expect(passwordResetService.listAdminRequests.calls.argsFor(1)[0]).toEqual({
      status: 'PENDING',
      page: 0,
      size: 10,
    });
  });

  it('denies a pending request and reloads the list', () => {
    component.deny(pendingRequest);

    expect(passwordResetService.denyAdminRequest).toHaveBeenCalledWith(7);
    expect(passwordResetService.listAdminRequests).toHaveBeenCalledTimes(2);
  });

  it('renders service errors', () => {
    passwordResetService.listAdminRequests.and.returnValue(
      throwError(() => ({ status: 500, message: 'Failed' })),
    );

    component.refresh();
    fixture.detectChanges();

    expect(component.errorMessage()).toBe('Unexpected error');
  });
});
