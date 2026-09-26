import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../models/earnings.dart';
import '../../../models/home_visit.dart';
import '../../../models/json.dart';
import '../../../models/provider_profile.dart';
import '../../offline/offline_queue.dart';
import '../domain/visit_lifecycle.dart';
import 'photo_store.dart';

enum VisitScope { today, upcoming, completed }

/// API contract §8 (provider actions) and §17 (provider app).
class ProviderRepository {
  ProviderRepository(this._api, {this.photos});
  final ApiClient _api;

  /// Needed to replay queued photo uploads.
  final PhotoFileStore? photos;

  Future<ProviderProfile> me() async => ProviderProfile.fromJson(asJson(await _api.get('/provider/me')));

  Future<ProviderProfile> setDuty(bool onDuty) async =>
      ProviderProfile.fromJson(asJson(await _api.post('/provider/duty', body: {'onDuty': onDuty})));

  /// Follows `nextCursor` for a few pages; providers have few visits per scope.
  Future<List<HomeVisit>> visits(VisitScope scope) async {
    final result = <HomeVisit>[];
    String? cursor;
    for (var page = 0; page < 5; page++) {
      final res = asJson(await _api.get('/provider/visits', query: {
        'scope': scope.name,
        'limit': '50',
        'cursor': ?cursor,
      }));
      result.addAll(jsonList(res['items']).map(HomeVisit.fromJson));
      cursor = str(res['nextCursor']);
      if (cursor == null || cursor.isEmpty) break;
    }
    return result;
  }

  Future<HomeVisit> visit(String id) async => HomeVisit.fromJson(asJson(await _api.get('/home-visits/$id')));

  /// `GET /provider/earnings?from=&to=` (contract §32), dates `YYYY-MM-DD`.
  Future<Earnings> earnings({required String from, required String to}) async =>
      Earnings.fromJson(asJson(await _api.get('/provider/earnings', query: {'from': from, 'to': to})));

  /// `POST /me/photo` (contract §29): multipart `image`, jpg/png/webp ≤ 5 MB.
  Future<String?> uploadPhoto({required List<int> bytes, required String filename, required String mimeType}) async {
    final res = asJson(await _api.postMultipart(
      '/me/photo',
      fields: const {},
      file: MultipartFilePart(field: 'image', bytes: bytes, filename: filename, contentType: mimeType),
    ));
    return str(res['photoUrl']);
  }

  Future<void> postLocation(double lat, double lng) async {
    await _api.post('/provider/location', body: {'lat': lat, 'lng': lng});
  }

  /// Sends a queued action. Every action carries its stable Idempotency-Key
  /// (the contract requires it for vitals; sending it on the other provider
  /// actions is harmless and lets the server de-duplicate replays).
  Future<HomeVisit?> sendAction(QueuedAction action) async {
    if (action.type == VisitActionType.photo) {
      await _uploadPhoto(action);
      return null;
    }
    final res = await _api.post(action.path, body: action.body, idempotencyKey: action.idempotencyKey);
    if (res is Map && res['id'] != null) return HomeVisit.fromJson(asJson(res));
    return null;
  }
}

extension on ProviderRepository {
  /// `POST /records` (multipart). The file is read at send time; if it has
  /// disappeared the item is dropped (see [ApiException.localFileMissing]).
  Future<void> _uploadPhoto(QueuedAction action) async {
    final b = action.body;
    final path = str(b['filePath']) ?? '';
    final bytes = path.isEmpty ? null : await photos?.read(path);
    if (bytes == null) throw const ApiException.localFileMissing();
    final name = path.split(RegExp(r'[\\/]')).last;
    await _api.postMultipart(
      '/records',
      fields: {
        'patientId': strOr(b['patientId']),
        'type': strOr(b['recordType'], 'other'),
        'title': strOr(b['title'], 'Home visit photo'),
        'recordDate': strOr(b['recordDate']),
      },
      file: MultipartFilePart(
        field: 'file',
        bytes: bytes,
        filename: name,
        contentType: strOr(b['mimeType'], 'image/jpeg'),
      ),
      idempotencyKey: action.idempotencyKey,
    );
  }
}
