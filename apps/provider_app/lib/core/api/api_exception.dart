/// Error raised for any failed API call. `statusCode == 0` means the request
/// never got a response (offline, DNS failure, timeout).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.correlationId,
    this.details = const {},
    this.authenticated = true,
  });

  const ApiException.network([this.message = 'Network unavailable'])
      : statusCode = 0,
        code = 'NETWORK',
        correlationId = null,
        details = const {},
        authenticated = true;

  /// A queued upload whose local file no longer exists (e.g. cleared by the
  /// OS). Not retryable; the item is dropped and the user told.
  const ApiException.localFileMissing()
      : statusCode = -1,
        code = localFileMissingCode,
        message = 'The photo file is no longer on this device',
        correlationId = null,
        details = const {},
        authenticated = true;

  static const localFileMissingCode = 'LOCAL_FILE_MISSING';

  final int statusCode;
  final String code;
  final String message;
  final String? correlationId;

  /// The error envelope's `details` object (e.g. `attemptsRemaining`).
  final Map<String, dynamic> details;

  /// False when the failed call was sent without a session (OTP request and
  /// verify, refresh). A 401 there is a wrong/expired code, not an expired
  /// session.
  final bool authenticated;

  /// `details.attemptsRemaining` (wrong OTP / visit code), when present.
  int? get attemptsRemaining {
    final v = details['attemptsRemaining'];
    return v is num ? v.toInt() : null;
  }

  bool get isNetwork => statusCode == 0;
  bool get isUnauthenticated => statusCode == 401;

  /// A 401 on a call made with a session: the session is gone.
  bool get isSessionExpired => statusCode == 401 && authenticated;

  /// Staff MFA gate (contract §22). Providers are not MFA-enforced, but the
  /// app explains it clearly if the server ever asks for it.
  bool get isMfaRequired => code == 'MFA_REQUIRED';

  /// 403/404: the resource is gone or no longer ours (e.g. visit reassigned).
  /// `MFA_REQUIRED` is a session problem, not a lost visit, so it is excluded.
  bool get isAccessLost => (statusCode == 403 && !isMfaRequired) || statusCode == 404;

  /// Worth retrying later without user action.
  /// `MFA_REQUIRED` keeps queued work until the session is sorted out.
  bool get isRetryable =>
      isMfaRequired ||
      isNetwork || statusCode == 401 || statusCode == 408 || statusCode == 429 || statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}
