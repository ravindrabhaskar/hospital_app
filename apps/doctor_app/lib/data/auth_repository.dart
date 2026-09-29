import '../core/api/api_client.dart';
import '../models/json.dart';
import '../models/me.dart';

/// API contract §2 (OTP login) and §22 (staff TOTP MFA).
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<OtpRequestResult> requestOtp(String phone) async {
    final res = await _api.post('/auth/otp/request', body: {'phone': phone}, auth: false);
    return OtpRequestResult.fromJson(asJson(res));
  }

  Future<AuthSession> verifyOtp(String phone, String otp) async {
    final res = await _api.post(
      '/auth/otp/verify',
      body: {'phone': phone, 'otp': otp, 'deviceName': 'CareCompanion Doctor app'},
      auth: false,
    );
    return AuthSession.fromJson(asJson(res));
  }

  Future<Me> me() async => Me.fromJson(asJson(await _api.get('/me')));

  Future<void> updateLanguage(String language) async {
    await _api.patch('/me', body: {'language': language});
  }

  Future<void> logout(String refreshToken) async {
    await _api.post('/auth/logout', body: {'refreshToken': refreshToken}, auth: false);
  }

  /// Starts TOTP enrolment: the secret + otpauth link (CONFLICT if enrolled).
  Future<TotpEnrollment> enrollTotp() async =>
      TotpEnrollment.fromJson(asJson(await _api.post('/auth/mfa/totp/enroll')));

  /// Confirms enrolment with the first code: recovery codes + an MFA-verified
  /// session.
  Future<({List<String> recoveryCodes, AuthSession session})> confirmTotp(String code) async {
    final res = asJson(await _api.post('/auth/mfa/totp/confirm', body: {'code': code}));
    return (recoveryCodes: stringList(res['recoveryCodes']), session: AuthSession.fromJson(asJson(res['session'])));
  }

  /// Verifies a TOTP code or a single-use recovery code.
  Future<AuthSession> verifyMfa({String? code, String? recoveryCode}) async {
    final res = await _api.post('/auth/mfa/verify', body: {'code': ?code, 'recoveryCode': ?recoveryCode});
    return AuthSession.fromJson(asJson(res));
  }
}
