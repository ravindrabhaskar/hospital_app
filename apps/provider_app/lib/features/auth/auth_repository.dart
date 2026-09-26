import '../../core/api/api_client.dart';
import '../../models/json.dart';
import '../../models/me.dart';

/// API contract §2.
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
      body: {'phone': phone, 'otp': otp, 'deviceName': 'CareCompanion Pro app'},
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
}
