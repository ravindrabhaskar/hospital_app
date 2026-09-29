/// Typed error for any failed API call, built from the contract's envelope
/// `{ "error": { "code", "message", "details", "correlationId" } }`.
/// `statusCode == 0` means the request never got a response (offline, DNS
/// failure, timeout).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const {},
    this.correlationId,
  });

  const ApiException.network([this.message = 'Network unavailable'])
    : statusCode = 0,
      code = networkCode,
      details = const {},
      correlationId = null;

  static const networkCode = 'NETWORK';

  final int statusCode;
  final String code;
  final String message;
  final Map<String, dynamic> details;
  final String? correlationId;

  bool get isNetwork => statusCode == 0;
  bool get isUnauthenticated => statusCode == 401;

  /// Staff MFA gate (contract §22): the session must pass TOTP first.
  bool get isMfaRequired => code == 'MFA_REQUIRED';

  /// 403 that is not the MFA gate: the doctor may not act on this resource.
  bool get isForbidden => statusCode == 403 && !isMfaRequired;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidation => code == 'VALIDATION_ERROR';
  bool get isRateLimited => code == 'RATE_LIMITED';
  bool get isConsentRequired => code == 'CONSENT_REQUIRED';
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}
