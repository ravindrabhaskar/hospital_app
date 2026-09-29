import 'json.dart';

/// `Me` from API contract §2 (+ §22 MFA fields).
class Me {
  const Me({
    required this.id,
    required this.phone,
    required this.name,
    required this.roles,
    required this.language,
    required this.providerId,
    this.mfaRequired = false,
    this.mfaEnrolled = false,
    this.mfaVerified = false,
  });

  final String id;
  final String phone;
  final String? name;
  final List<String> roles;
  final String language;
  final String? providerId;
  final bool mfaRequired;
  final bool mfaEnrolled;
  final bool mfaVerified;

  bool get isDoctor => roles.contains('doctor');

  /// Staff session that has not passed TOTP yet (only blocks data calls when
  /// the server enforces MFA; the API tells us with `403 MFA_REQUIRED`).
  bool get needsMfa => mfaRequired && !mfaVerified;

  factory Me.fromJson(Json json) => Me(
    id: strOr(json['id']),
    phone: strOr(json['phone']),
    name: str(json['name']),
    roles: stringList(json['roles']),
    language: strOr(json['language'], 'en'),
    providerId: str(json['providerId']),
    mfaRequired: boolOr(json['mfaRequired']),
    mfaEnrolled: boolOr(json['mfaEnrolled']),
    mfaVerified: boolOr(json['mfaVerified']),
  );

  Json toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'roles': roles,
    'language': language,
    'providerId': providerId,
    'mfaRequired': mfaRequired,
    'mfaEnrolled': mfaEnrolled,
    'mfaVerified': mfaVerified,
  };
}

/// Response of `POST /auth/otp/request`.
class OtpRequestResult {
  const OtpRequestResult({required this.requestId, this.expiresAt, this.devOtp});

  final String requestId;
  final DateTime? expiresAt;
  final String? devOtp;

  factory OtpRequestResult.fromJson(Json json) => OtpRequestResult(
    requestId: strOr(json['requestId']),
    expiresAt: dateOrNull(json['expiresAt']),
    devOtp: str(json['devOtp']),
  );
}

/// `AuthSession` from API contract §2.
class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.user});

  final String accessToken;
  final String refreshToken;
  final Me user;

  factory AuthSession.fromJson(Json json) => AuthSession(
    accessToken: strOr(json['accessToken']),
    refreshToken: strOr(json['refreshToken']),
    user: Me.fromJson(asJson(json['user'])),
  );
}

/// `POST /auth/mfa/totp/enroll` (contract §22).
class TotpEnrollment {
  const TotpEnrollment({required this.secret, required this.otpauthUrl});

  final String secret;
  final String otpauthUrl;

  factory TotpEnrollment.fromJson(Json json) =>
      TotpEnrollment(secret: strOr(json['secret']), otpauthUrl: strOr(json['otpauthUrl']));

  /// The secret in groups of four for reading / typing ("ABCD EFGH ...").
  String get groupedSecret {
    final clean = secret.replaceAll(' ', '');
    final parts = <String>[];
    for (var i = 0; i < clean.length; i += 4) {
      parts.add(clean.substring(i, i + 4 > clean.length ? clean.length : i + 4));
    }
    return parts.join(' ');
  }
}
