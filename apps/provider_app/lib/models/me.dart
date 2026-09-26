import 'json.dart';

/// `Me` from API contract §2.
class Me {
  const Me({
    required this.id,
    required this.phone,
    required this.name,
    required this.roles,
    required this.language,
    required this.providerId,
  });

  final String id;
  final String phone;
  final String? name;
  final List<String> roles;
  final String language;
  final String? providerId;

  bool get isProvider => roles.contains('provider');

  factory Me.fromJson(Json json) => Me(
        id: strOr(json['id']),
        phone: strOr(json['phone']),
        name: str(json['name']),
        roles: stringList(json['roles']),
        language: strOr(json['language'], 'en'),
        providerId: str(json['providerId']),
      );

  Json toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'roles': roles,
        'language': language,
        'providerId': providerId,
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
