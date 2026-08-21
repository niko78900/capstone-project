// File purpose: Covers Angular tests for app spec behavior.
import { TestBed } from '@angular/core/testing';
import { App } from './app';
import { provideRouter } from '@angular/router';
import { signal } from '@angular/core';
import { AuthService } from './core/services/auth.service';
import { AuthSessionService } from './core/services/auth-session.service';
import { ThemeService } from './core/services/theme.service';

describe('App', () => {
  beforeEach(async () => {
    const sessionSignal = signal(null);
    const isAuthenticatedSignal = signal(false);
    const isAdminSignal = signal(false);
    const isDarkSignal = signal(false);

    await TestBed.configureTestingModule({
      imports: [App],
      providers: [
        provideRouter([]),
        { provide: AuthService, useValue: { logout: jasmine.createSpy('logout') } },
        {
          provide: AuthSessionService,
          useValue: {
            session: sessionSignal.asReadonly(),
            isAuthenticated: isAuthenticatedSignal.asReadonly(),
            isAdmin: isAdminSignal.asReadonly(),
          },
        },
        {
          provide: ThemeService,
          useValue: {
            isDark: isDarkSignal.asReadonly(),
            toggle: jasmine.createSpy('toggle'),
          },
        },
      ],
    }).compileComponents();
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(App);
    const app = fixture.componentInstance;
    expect(app).toBeTruthy();
  });

  it('should render top navigation title', () => {
    const fixture = TestBed.createComponent(App);
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('Skopje Price Compass');
    expect(compiled.textContent).toContain('Products');
    expect(compiled.textContent).toContain('Log In');
  });
});
