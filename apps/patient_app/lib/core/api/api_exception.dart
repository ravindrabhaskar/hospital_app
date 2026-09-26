/// Typed error built from the contract's error envelope:
/// `{ "error": { "code", "message", "details", "correlationId" } }`.
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const {},
    this.correlationId,
  });

  /// Client-side code used when the device could not reach the server.
  static const String network = 'NETWORK_ERROR';

  /// Client-side code used when the response body was not understood.
  static const String badResponse = 'BAD_RESPONSE';

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic> details;
  final String? correlationId;

  bool get isOffline => code == network;
  bool get isUnauthenticated => code == 'UNAUTHENTICATED';
  bool get isForbidden => code == 'FORBIDDEN';
  bool get isConsentRequired => code == 'CONSENT_REQUIRED';
  bool get isSlotUnavailable => code == 'SLOT_UNAVAILABLE';
  bool get isNotServiceable => code == 'NOT_SERVICEABLE';
  bool get isValidation => code == 'VALIDATION_ERROR';
  bool get isNotFound => code == 'NOT_FOUND';
  bool get isRateLimited => code == 'RATE_LIMITED';
  bool get isConflict => code == 'CONFLICT';

  /// Staff accounts must pass MFA before using data endpoints (§22). The
  /// patient app has no MFA flow, so it points them to the staff portal.
  bool get isMfaRequired => code == 'MFA_REQUIRED';
  bool get isServerError =>
      code == 'INTERNAL' || code == 'DEPENDENCY_UNAVAILABLE';

  factory ApiException.fromEnvelope(int status, Object? body) {
    if (body is Map && body['error'] is Map) {
      final e = Map<String, dynamic>.from(body['error'] as Map);
      return ApiException(
        code: (e['code'] as String?) ?? _codeForStatus(status),
        message: (e['message'] as String?) ?? 'Request failed',
        statusCode: status,
        details: e['details'] is Map
            ? Map<String, dynamic>.from(e['details'] as Map)
            : const {},
        correlationId: e['correlationId'] as String?,
      );
    }
    return ApiException(
      code: _codeForStatus(status),
      message: 'Request failed ($status)',
      statusCode: status,
    );
  }

  static String _codeForStatus(int status) {
    switch (status) {
      case 400:
        return 'VALIDATION_ERROR';
      case 401:
        return 'UNAUTHENTICATED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return 'NOT_FOUND';
      case 409:
        return 'CONFLICT';
      case 422:
        return 'VALIDATION_ERROR';
      case 429:
        return 'RATE_LIMITED';
      case 503:
        return 'DEPENDENCY_UNAVAILABLE';
      default:
        return status >= 500 ? 'INTERNAL' : badResponse;
    }
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
