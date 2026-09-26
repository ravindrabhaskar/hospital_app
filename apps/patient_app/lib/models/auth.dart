import 'json.dart';

class OtpRequestResult {
  OtpRequestResult({required this.requestId, this.expiresAt, this.devOtp});
  final String requestId;
  final DateTime? expiresAt;
  final String? devOtp;

  factory OtpRequestResult.fromJson(Json j) => OtpRequestResult(
        requestId: str(j, 'requestId'),
        expiresAt: dateOrNull(j, 'expiresAt'),
        devOtp: strOrNull(j, 'devOtp'),
      );
}

class Me {
  Me({
    required this.id,
    required this.phone,
    required this.name,
    required this.email,
    required this.roles,
    required this.language,
    required this.selfPatientId,
    required this.onboardingComplete,
    required this.mfaRequired,
    required this.providerId,
    this.mfaEnrolled = false,
    this.mfaVerified = false,
  });

  final String id;
  final String phone;
  final String? name;
  final String? email;
  final List<String> roles;
  final String language;
  final String? selfPatientId;
  final bool onboardingComplete;
  final bool mfaRequired;
  final String? providerId;
  final bool mfaEnrolled;
  final bool mfaVerified;

  factory Me.fromJson(Json j) => Me(
        id: str(j, 'id'),
        phone: str(j, 'phone'),
        name: strOrNull(j, 'name'),
        email: strOrNull(j, 'email'),
        roles: strList(j, 'roles'),
        language: str(j, 'language', 'en'),
        selfPatientId: strOrNull(j, 'selfPatientId'),
        onboardingComplete: boolOf(j, 'onboardingComplete'),
        mfaRequired: boolOf(j, 'mfaRequired'),
        providerId: strOrNull(j, 'providerId'),
        mfaEnrolled: boolOf(j, 'mfaEnrolled'),
        mfaVerified: boolOf(j, 'mfaVerified'),
      );
}

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final Me user;

  factory AuthSession.fromJson(Json j) => AuthSession(
        accessToken: str(j, 'accessToken'),
        refreshToken: str(j, 'refreshToken'),
        expiresIn: intOf(j, 'expiresIn'),
        user: Me.fromJson(asJson(j['user'])),
      );
}

class ConsentCatalogItem {
  ConsentCatalogItem({
    required this.purpose,
    required this.version,
    required this.title,
    required this.description,
    required this.required,
  });
  final String purpose;
  final String version;
  final String title;
  final String description;
  final bool required;

  factory ConsentCatalogItem.fromJson(Json j) => ConsentCatalogItem(
        purpose: str(j, 'purpose'),
        version: str(j, 'version'),
        title: str(j, 'title'),
        description: str(j, 'description'),
        required: boolOf(j, 'required'),
      );
}

class Consent {
  Consent({
    required this.id,
    required this.purpose,
    required this.version,
    required this.scope,
    required this.status,
    required this.grantedAt,
    required this.revokedAt,
  });
  final String id;
  final String purpose;
  final String version;
  final String scope;
  final String status;
  final DateTime? grantedAt;
  final DateTime? revokedAt;

  bool get isGranted => status == 'granted';

  factory Consent.fromJson(Json j) => Consent(
        id: str(j, 'id'),
        purpose: str(j, 'purpose'),
        version: str(j, 'version'),
        scope: str(j, 'scope'),
        status: str(j, 'status'),
        grantedAt: dateOrNull(j, 'grantedAt'),
        revokedAt: dateOrNull(j, 'revokedAt'),
      );
}

// ---------- Account deletion & data export (API_CONTRACT §23) ----------

class DeletionRequest {
  DeletionRequest({
    required this.id,
    required this.status,
    required this.reason,
    required this.requestedAt,
    required this.scheduledFor,
    required this.completedAt,
  });
  final String id;
  final String status;
  final String? reason;
  final DateTime? requestedAt;
  final DateTime? scheduledFor;
  final DateTime? completedAt;

  bool get isScheduled => status == 'scheduled';

  factory DeletionRequest.fromJson(Json j) => DeletionRequest(
        id: str(j, 'id'),
        status: str(j, 'status'),
        reason: strOrNull(j, 'reason'),
        requestedAt: dateOrNull(j, 'requestedAt'),
        scheduledFor: dateOrNull(j, 'scheduledFor'),
        completedAt: dateOrNull(j, 'completedAt'),
      );
}

class DataExport {
  DataExport({required this.id, required this.status, required this.createdAt, required this.expiresAt, required this.sizeBytes});
  final String id;
  final String status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final int sizeBytes;

  factory DataExport.fromJson(Json j) => DataExport(
        id: str(j, 'id'),
        status: str(j, 'status'),
        createdAt: dateOrNull(j, 'createdAt'),
        expiresAt: dateOrNull(j, 'expiresAt'),
        sizeBytes: intOf(j, 'sizeBytes'),
      );
}
