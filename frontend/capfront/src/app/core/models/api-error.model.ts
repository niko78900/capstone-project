import { HttpErrorResponse } from '@angular/common/http';

export interface FieldValidationError {
  field: string;
  message: string;
}

export interface ApiError {
  status: number;
  error: string;
  message: string;
  path: string;
  fieldErrors: FieldValidationError[];
}

export function mapApiError(error: unknown): ApiError {
  if (error instanceof HttpErrorResponse) {
    const body = normalizeErrorBody(error.error);
    return {
      status: body.status ?? error.status,
      error: body.error ?? error.statusText ?? 'Error',
      message: body.message ?? error.message ?? 'Unexpected error',
      path: body.path ?? '',
      fieldErrors: body.fieldErrors ?? [],
    };
  }

  return {
    status: 500,
    error: 'Error',
    message: 'Unexpected error',
    path: '',
    fieldErrors: [],
  };
}

export function fieldErrorMap(error: ApiError): Record<string, string> {
  return error.fieldErrors.reduce<Record<string, string>>((acc, curr) => {
    acc[curr.field] = curr.message;
    return acc;
  }, {});
}

interface NormalizedErrorBody {
  status?: number;
  error?: string;
  message?: string;
  path?: string;
  fieldErrors?: FieldValidationError[];
}

function normalizeErrorBody(input: unknown): NormalizedErrorBody {
  if (typeof input !== 'object' || input === null) {
    return {};
  }

  const raw = input as Record<string, unknown>;
  const fieldErrorsRaw = raw['fieldErrors'];
  const fieldErrors = Array.isArray(fieldErrorsRaw)
    ? fieldErrorsRaw
        .filter((item) => typeof item === 'object' && item !== null)
        .map((item) => item as Record<string, unknown>)
        .map((item) => ({
          field: String(item['field'] ?? ''),
          message: String(item['message'] ?? 'Invalid value'),
        }))
    : [];

  return {
    status: typeof raw['status'] === 'number' ? raw['status'] : undefined,
    error: typeof raw['error'] === 'string' ? raw['error'] : undefined,
    message: typeof raw['message'] === 'string' ? raw['message'] : undefined,
    path: typeof raw['path'] === 'string' ? raw['path'] : undefined,
    fieldErrors,
  };
}
