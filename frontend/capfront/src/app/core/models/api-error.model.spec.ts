// File purpose: Covers Angular tests for api error model spec behavior.
import { HttpErrorResponse } from '@angular/common/http';
import { fieldErrorMap, mapApiError } from './api-error.model';

describe('api-error.model', () => {
  it('maps HttpErrorResponse body to ApiError shape', () => {
    const error = new HttpErrorResponse({
      status: 422,
      error: {
        status: 422,
        error: 'Unprocessable Entity',
        message: 'Validation failed',
        path: '/api/v1/submissions/product',
        fieldErrors: [{ field: 'name', message: 'Product name is required' }],
      },
    });

    const mapped = mapApiError(error);
    expect(mapped.status).toBe(422);
    expect(mapped.message).toBe('Validation failed');
    expect(fieldErrorMap(mapped)['name']).toBe('Product name is required');
  });

  it('returns fallback shape for unknown errors', () => {
    const mapped = mapApiError('bad');
    expect(mapped.status).toBe(500);
    expect(mapped.fieldErrors.length).toBe(0);
  });
});
