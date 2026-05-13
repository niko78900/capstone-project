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
        size: 50,
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
      size: 50,
    });
    expect(component.requests()).toEqual([pendingRequest]);
    expect(fixture.nativeElement.textContent).toContain('user@example.com');
  });

  it('approves a pending request and reloads the list', () => {
    component.approve(pendingRequest);

    expect(passwordResetService.approveAdminRequest).toHaveBeenCalledWith(7);
    expect(passwordResetService.listAdminRequests).toHaveBeenCalledTimes(2);
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
