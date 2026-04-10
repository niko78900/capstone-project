import { HttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { authInterceptor } from './auth.interceptor';
import { AuthSessionService } from '../services/auth-session.service';

describe('authInterceptor', () => {
  it('adds bearer token when session has token', () => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
        {
          provide: AuthSessionService,
          useValue: { token: 'jwt-token', clear: jasmine.createSpy('clear') },
        },
        {
          provide: Router,
          useValue: { url: '/products', navigate: jasmine.createSpy('navigate') },
        },
      ],
    });

    const http = TestBed.inject(HttpClient);
    const httpMock = TestBed.inject(HttpTestingController);

    http.get('/api/v1/products').subscribe();
    const req = httpMock.expectOne('/api/v1/products');
    expect(req.request.headers.get('Authorization')).toBe('Bearer jwt-token');
    req.flush([]);
    httpMock.verify();
  });

  it('clears session and redirects admin route on 401', () => {
    const clearSpy = jasmine.createSpy('clear');
    const navigateSpy = jasmine.createSpy('navigate');

    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
        {
          provide: AuthSessionService,
          useValue: { token: 'jwt-token', clear: clearSpy },
        },
        {
          provide: Router,
          useValue: { url: '/admin/submissions', navigate: navigateSpy },
        },
      ],
    });

    const http = TestBed.inject(HttpClient);
    const httpMock = TestBed.inject(HttpTestingController);

    http.get('/api/v1/admin/submissions').subscribe({
      error: () => undefined,
    });
    const req = httpMock.expectOne('/api/v1/admin/submissions');
    req.flush({ message: 'Authentication required' }, { status: 401, statusText: 'Unauthorized' });

    expect(clearSpy).toHaveBeenCalled();
    expect(navigateSpy).toHaveBeenCalledWith(['/admin/login']);
    httpMock.verify();
  });
});
