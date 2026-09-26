import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../models/json.dart';
import '../../models/provider_application.dart';
import 'document_picker.dart';

/// Result of `POST /home-visit/serviceability` (contract §8).
class ServiceabilityResult {
  const ServiceabilityResult({required this.serviceable, this.zoneId, this.zoneName, required this.message});
  final bool serviceable;
  final String? zoneId;
  final String? zoneName;
  final String message;
}

class Specialty {
  const Specialty({required this.code, required this.name});
  final String code;
  final String name;
}

/// Onboarding applications (contract §30).
class ApplicationRepository {
  ApplicationRepository(this._api);
  final ApiClient _api;

  /// The caller's application, or null when there is none (404).
  Future<ProviderApplication?> mine() async {
    try {
      return ProviderApplication.fromJson(asJson(await _api.get('/provider-applications/me')));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ProviderApplication> create(ApplicationDraft draft) async =>
      ProviderApplication.fromJson(asJson(await _api.post('/provider-applications', body: draft.toJson())));

  /// Edits and resubmits (only while `submitted`/`changes_requested`).
  Future<ProviderApplication> update(ApplicationDraft draft) async =>
      ProviderApplication.fromJson(asJson(await _api.patch('/provider-applications/me', body: draft.toJson())));

  Future<ProviderApplication> uploadDocument(String docType, PickedDocument file, {UploadProgress? onProgress}) async =>
      ProviderApplication.fromJson(asJson(await _api.postMultipart(
        '/provider-applications/me/documents',
        fields: {'docType': docType},
        file: MultipartFilePart(field: 'file', bytes: file.bytes, filename: file.name, contentType: file.mimeType),
        onProgress: onProgress,
      )));

  Future<ProviderApplication> deleteDocument(String docId) async =>
      ProviderApplication.fromJson(asJson(await _api.delete('/provider-applications/me/documents/$docId')));

  /// Zones are admin-only, so a preferred area is resolved from a pincode.
  Future<ServiceabilityResult> serviceability(String pincode) async {
    final res = asJson(await _api.post('/home-visit/serviceability', body: {'pincode': pincode}));
    return ServiceabilityResult(
      serviceable: boolOr(res['serviceable']),
      zoneId: str(res['zoneId']),
      zoneName: str(res['zoneName']),
      message: strOr(res['message']),
    );
  }

  /// `GET /specialties` (contract §6), needed for doctor applications.
  Future<List<Specialty>> specialties() async {
    final res = asJson(await _api.get('/specialties'));
    return [
      for (final s in jsonList(res['items'])) Specialty(code: strOr(s['code']), name: strOr(s['name'], strOr(s['code']))),
    ];
  }
}
