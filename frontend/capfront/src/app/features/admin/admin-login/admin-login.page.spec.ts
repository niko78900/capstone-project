import { HttpErrorResponse } from '@angular/common/http';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { convertToParamMap, ActivatedRoute, Router } from '@angular/router';
import { of, throwError } from 'rxjs';
import { AuthService } from '../../../core/services/auth.service';
import { AdminLoginPageComponent } from './admin-login.page';

describe('AdminLoginPageComponent', () => {
  let fixture: ComponentFixture<AdminLoginPageComponent>;
  let component: AdminLoginPageComponent;
  let authService: jasmine.SpyObj<AuthService>;
  let router: jasmine.SpyObj<Router>;

  beforeEach(async () => {
    authService = jasmine.createSpyObj<AuthService>('AuthService', ['login', 'logout']);
    router = jasmine.createSpyObj<Router>('Router', ['navigateByUrl']);

    await TestBed.configureTestingModule({
      imports: [AdminLoginPageComponent],
      providers: [
        { provide: AuthService, useValue: authService },
        { provide: Router, useValue: router },
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              queryParamMap: convertToParamMap({}),
            },
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(AdminLoginPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('shows validation errors when form is empty', () => {
    component.submit();
    fixture.detectChanges();
    expect(component.form.invalid).toBeTrue();
    expect(component.form.controls.email.touched).toBeTrue();
    expect(component.form.controls.password.touched).toBeTrue();
  });

  it('renders server message on API login failure', () => {
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

  it('navigates to submissions page when admin login succeeds', () => {
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
});
