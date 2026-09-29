import 'dart:convert';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/storage/key_value_store.dart';
import '../../models/care_plans.dart' show ymd;
import '../../models/field_ops.dart';
import '../../models/json.dart';

/// Route planning, attendance and supplies (API contract §48, role `provider`).
class FieldRepository {
  FieldRepository(this._api, {this.store});
  final ApiClient _api;

  /// Keeps the last supplies list (encrypted) so usage can be recorded offline.
  final KeyValueStore? store;

  Future<RoutePlan> route(DateTime date) async =>
      RoutePlan.fromJson(asJson(await _api.get('/provider/route', query: {'date': ymd(date)})));

  Future<AttendanceEvent> attendance(String action, {double? lat, double? lng}) async =>
      AttendanceEvent.fromJson(asJson(await _api.post('/provider/attendance', body: {
        'action': action,
        'lat': ?lat,
        'lng': ?lng,
      })));

  /// `month` is `YYYY-MM`.
  Future<AttendanceMonth> attendanceMonth(String month) async =>
      AttendanceMonth.fromJson(asJson(await _api.get('/provider/attendance', query: {'month': month})));

  /// Network first; on a network error, the last list seen (if any).
  Future<({List<SupplyItem> items, bool fromCache})> supplies() async {
    try {
      final items = parseSupplies(await _api.get('/provider/supplies'));
      await store?.write(StoreKeys.supplies, jsonEncode(items.map((i) => i.toJson()).toList()));
      return (items: items, fromCache: false);
    } on ApiException catch (e) {
      if (e.isNetwork) {
        final cached = await cachedSupplies();
        if (cached != null) return (items: cached, fromCache: true);
      }
      rethrow;
    }
  }

  Future<List<SupplyItem>?> cachedSupplies() async {
    final raw = await store?.read(StoreKeys.supplies);
    if (raw == null || raw.isEmpty) return null;
    try {
      return parseSupplies(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
