export type ErrorCode =
  | 'VALIDATION_ERROR'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'INVALID_STATE_TRANSITION'
  | 'SLOT_UNAVAILABLE'
  | 'IDEMPOTENCY_MISMATCH'
  | 'RATE_LIMITED'
  | 'NOT_SERVICEABLE'
  | 'CONSENT_REQUIRED'
  | 'MFA_REQUIRED'
  | 'FILE_REJECTED'
  | 'INTERNAL'
  | 'DEPENDENCY_UNAVAILABLE';

export const STATUS_BY_CODE: Record<ErrorCode, number> = {
  VALIDATION_ERROR: 400,
  UNAUTHENTICATED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  INVALID_STATE_TRANSITION: 409,
  SLOT_UNAVAILABLE: 409,
  IDEMPOTENCY_MISMATCH: 422,
  RATE_LIMITED: 429,
  NOT_SERVICEABLE: 422,
  CONSENT_REQUIRED: 403,
  MFA_REQUIRED: 403,
  FILE_REJECTED: 422,
  INTERNAL: 500,
  DEPENDENCY_UNAVAILABLE: 503,
};

export class AppError extends Error {
  readonly status: number;
  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly details: Record<string, unknown> = {},
  ) {
    super(message);
    this.name = 'AppError';
    this.status = STATUS_BY_CODE[code];
  }
}

export const errors = {
  validation: (message: string, details: Record<string, unknown> = {}) => new AppError('VALIDATION_ERROR', message, details),
  unauthenticated: (message = 'Authentication required') => new AppError('UNAUTHENTICATED', message),
  forbidden: (message = 'You do not have access to this resource') => new AppError('FORBIDDEN', message),
  notFound: (what = 'Resource') => new AppError('NOT_FOUND', `${what} not found`),
  conflict: (message: string, details: Record<string, unknown> = {}) => new AppError('CONFLICT', message, details),
  invalidTransition: (from: string, to: string) =>
    new AppError('INVALID_STATE_TRANSITION', `Cannot move from ${from} to ${to}`, { from, to }),
  consentRequired: (purpose: string) => new AppError('CONSENT_REQUIRED', `Consent '${purpose}' is required`, { purpose }),
  mfaRequired: () => new AppError('MFA_REQUIRED', 'Multi-factor authentication is required for this account'),
  dependency: (message: string, details: Record<string, unknown> = {}) => new AppError('DEPENDENCY_UNAVAILABLE', message, details),
  featureDisabled: (flag: string) => new AppError('FORBIDDEN', `Feature '${flag}' is disabled`, { flag }),
};
