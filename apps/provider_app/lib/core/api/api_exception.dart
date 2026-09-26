/// Error raised for any failed API call. `statusCode == 0` means the request
/// never got a response (offline, DNS failure, timeout).
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.correlationId,
  });

  const ApiException.network([this.message = 'Network unavailable'])
      : statusCode = 0,
        code = 'NETWORK',
        correlationId = null;

  /// A queued upload whose local file no longer exists (e.g. cleared by the
  /// OS). Not retryable; the item is dropped and the user told.
  const ApiException.localFileMissing()
      : statusCode = -1,
        code = localFileMissingCode,
        message = 'The photo file is no longer on this device',
        correlationId = null;

  static const localFileMissingCode = 'LOCAL_FILE_MISSING';

  final int statusCode;
  final String code;
  final String message;
  final String? correlationId;

  bool get isNetwork => statusCode == 0;
  bool get isUnauthenticated => statusCode == 401;

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
