// File purpose: Covers Angular tests for admin login page spec behavior.
import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap } from '@angular/router';
import { of, throwError } from 'rxjs';
import { AuthService } from '../../../core/services/auth.service';
import { PasswordResetService } from '../../../core/services/password-reset.service';
import { AdminLoginPageComponent } from './admin-login.page';

describe('AdminLoginPageComponent', () => {
  let fixture: ComponentFixture<AdminLoginPageComponent>;
  let component: AdminLoginPageComponent;
  let authService: jasmine.SpyObj<AuthService>;
  let passwordResetService: jasmine.SpyObj<PasswordResetService>;
  let router: jasmine.SpyObj<Router>;

  async function createComponent(reason?: string): Promise<void> {
    authService = jasmine.createSpyObj<AuthService>('AuthService', ['login', 'logout']);
    passwordResetService = jasmine.createSpyObj<PasswordResetService>('PasswordResetService', [
      'requestReset',
      'checkStoredStatus',
      'clearStoredToken',
      'completeStoredReset',
    ]);
    passwordResetService.checkStoredStatus.and.returnValue(null);
    router = jasmine.createSpyObj<Router>('Router', ['navigateByUrl']);

    await TestBed.configureTestingModule({
      imports: [AdminLoginPageComponent],
      providers: [
        { provide: AuthService, useValue: authService },
        { provide: PasswordResetService, useValue: passwordResetService },
        { provide: Router, useValue: router },
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              queryParamMap: convertToParamMap(reason ? { reason } : {}),
            },
            queryParamMap: of(convertToParamMap(reason ? { reason } : {})),
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminLoginPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  }

  afterEach(() => {
    TestBed.resetTestingModule();
  });

  it('shows validation errors when form is empty', async () => {
    await createComponent();

    component.submit();
    fixture.detectChanges();

    expect(component.form.invalid).toBeTrue();
    expect(component.form.controls.email.touched).toBeTrue();
    expect(component.form.controls.password.touched).toBeTrue();
  });

  it('renders server message on API login failure', async () => {
    await createComponent();

    authService.login.and.returnValue(
      throwError(
        () =>
          new HttpErrorResponse({
            status: 401,
            error: { message: 'Invalid email or password', fieldErrors: [] },
          }),
      ),
    );

    component.form.setValue({ email: 'admin@example.com', password: 'password123' });
    component.submit();
    fixture.detectChanges();

    expect(component.serverMessage()).toBe('Invalid email or password');
  });

  it('navigates to moderation queue when admin login succeeds', async () => {
    await createComponent();

    authService.login.and.returnValue(
      of({
        accessToken: 'token',
        tokenType: 'Bearer',
        expiresInMs: 3600000,
        user: { id: 1, email: 'admin@example.com', displayName: 'Admin', role: 'ADMIN' as const },
      }),
    );

    component.form.setValue({ email: 'admin@example.com', password: 'password123' });
    component.submit();

    expect(router.navigateByUrl).toHaveBeenCalledWith('/admin/submissions');
  });

  it('navigates to products when regular user logs in', async () => {
    await createComponent();

    authService.login.and.returnValue(
      of({
        accessToken: 'token',
        tokenType: 'Bearer',
        expiresInMs: 3600000,
        user: { id: 2, email: 'user@example.com', displayName: 'User', role: 'USER' as const },
      }),
    );

    component.form.setValue({ email: 'user@example.com', password: 'password123' });
    component.submit();

    expect(router.navigateByUrl).toHaveBeenCalledWith('/products');
  });

  it('shows reason notice when redirected due expired session', async () => {
    await createComponent('sessionExpired');

    expect(component.noticeMessage()).toContain('session expired');
  });

  it('submits a forgot password request and stores pending state', async () => {
    await createComponent();
    passwordResetService.requestReset.and.returnValue(
      of({
        requestToken: 'reset-token',
        status: 'PENDING',
        expiresAt: '2026-05-14T10:00:00Z',
      }),
    );

    component.showResetRequest();
    component.resetRequestForm.setValue({ email: 'user@example.com' });
    component.submitResetRequest();

    expect(passwordResetService.requestReset).toHaveBeenCalledWith('user@example.com');
    expect(component.mode()).toBe('pendingReset');
    expect(component.resetMessage()).toContain('admin review');
  });

  it('shows reset form for an approved stored request', async () => {
    passwordResetService = jasmine.createSpyObj<PasswordResetService>('PasswordResetService', [
      'requestReset',
      'checkStoredStatus',
      'clearStoredToken',
      'completeStoredReset',
    ]);
    passwordResetService.checkStoredStatus.and.returnValue(
      of({
        status: 'APPROVED',
        email: 'approved@example.com',
        expiresAt: '2026-05-14T10:00:00Z',
        updatedAt: '2026-05-13T10:00:00Z',
      }),
    );
    authService = jasmine.createSpyObj<AuthService>('AuthService', ['login', 'logout']);
    router = jasmine.createSpyObj<Router>('Router', ['navigateByUrl']);

    await TestBed.configureTestingModule({
      imports: [AdminLoginPageComponent],
      providers: [
        { provide: AuthService, useValue: authService },
        { provide: PasswordResetService, useValue: passwordResetService },
        { provide: Router, useValue: router },
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: { queryParamMap: convertToParamMap({}) },
            queryParamMap: of(convertToParamMap({})),
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminLoginPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();

    expect(component.mode()).toBe('completeReset');
    expect(component.resetCompleteForm.controls.email.value).toBe('approved@example.com');
  });

  it('keeps stored reset token when status check fails transiently', async () => {
    await createComponent();
    passwordResetService.checkStoredStatus.and.returnValue(
      throwError(
        () =>
          new HttpErrorResponse({
            status: 500,
            error: { message: 'Server unavailable' },
          }),
      ),
    );

    component.checkStoredResetStatus();

    expect(passwordResetService.clearStoredToken).not.toHaveBeenCalled();
    expect(component.resetError()).toBe('Server unavailable');
  });

  it('clears stored reset token when status check returns not found', async () => {
    await createComponent();
    passwordResetService.checkStoredStatus.and.returnValue(
      throwError(
        () =>
          new HttpErrorResponse({
            status: 404,
            error: { message: 'Reset request not found' },
          }),
      ),
    );

    component.checkStoredResetStatus();

    expect(passwordResetService.clearStoredToken).toHaveBeenCalled();
    expect(component.resetError()).toBe('Reset request not found');
  });

  [
    { status: 'DENIED' as const, notice: 'denied' },
    { status: 'COMPLETED' as const, notice: 'completed' },
    { status: 'EXPIRED' as const, notice: 'expired' },
  ].forEach(({ status, notice }) => {
    it(`clears stored reset token when status is ${status}`, async () => {
      await createComponent();
      passwordResetService.checkStoredStatus.and.returnValue(
        of({
          status,
          email: 'user@example.com',
          expiresAt: '2026-05-14T10:00:00Z',
          updatedAt: '2026-05-13T10:00:00Z',
        }),
      );

      component.checkStoredResetStatus();

      expect(passwordResetService.clearStoredToken).toHaveBeenCalled();
      expect(component.mode()).toBe('login');
      expect(component.noticeMessage()?.toLowerCase()).toContain(notice);
    });
  });

  it('completes password reset when confirmation matches', async () => {
    await createComponent();
    passwordResetService.completeStoredReset.and.returnValue(
      of({
        status: 'COMPLETED',
        message: 'Password reset completed',
      }),
    );

    component.mode.set('completeReset');
    component.resetCompleteForm.setValue({
      email: 'user@example.com',
      newPassword: 'Password123!',
      confirmPassword: 'Password123!',
    });
    component.submitNewPassword();

    expect(passwordResetService.completeStoredReset).toHaveBeenCalledWith(
      'user@example.com',
      'Password123!',
    );
    expect(component.mode()).toBe('login');
    expect(component.noticeMessage()).toContain('completed');
  });
});
