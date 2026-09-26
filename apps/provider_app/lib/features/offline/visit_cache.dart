import 'dart:convert';

import '../../core/config.dart';
import '../../core/storage/key_value_store.dart';
import '../../models/home_visit.dart';

/// Encrypted local copy of the provider's visits (for offline viewing).
///
/// Holds only what the API already returned to this provider. Removed on
/// logout, when access to a visit is lost (403/404), and for completed
/// visits older than 24h.
class VisitCache {
  VisitCache(this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _clock;

  Map<String, HomeVisit> _visits = {};
  Map<String, List<String>> _lists = {};
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _store.read(StoreKeys.visitCache);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _visits = (decoded['visits'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, HomeVisit.fromJson(Map<String, dynamic>.from(v as Map))),
      );
      _lists = (decoded['lists'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
      );
    } catch (_) {
      _visits = {};
      _lists = {};
    }
  }

  Future<void> _persist() async {
    if (_visits.isEmpty && _lists.isEmpty) {
      await _store.delete(StoreKeys.visitCache);
      return;
    }
    await _store.write(
      StoreKeys.visitCache,
      jsonEncode({
        'visits': _visits.map((k, v) => MapEntry(k, v.toJson())),
        'lists': _lists,
      }),
    );
  }

  Future<void> saveList(String scope, List<HomeVisit> visits) async {
    await _load();
    for (final v in visits) {
      _visits[v.id] = v;
    }
    _lists[scope] = visits.map((v) => v.id).toList();
    _purgeExpiredInMemory();
    await _persist();
  }

  Future<List<HomeVisit>?> getList(String scope) async {
    await _load();
    final ids = _lists[scope];
    if (ids == null) return null;
    return ids.map((id) => _visits[id]).whereType<HomeVisit>().toList();
  }

  Future<void> saveVisit(HomeVisit visit) async {
    await _load();
    _visits[visit.id] = visit;
    await _persist();
  }

  Future<HomeVisit?> getVisit(String id) async {
    await _load();
    return _visits[id];
  }

  /// Removes all cached data for one visit (e.g. after it was reassigned).
  Future<void> purgeVisit(String id) async {
    await _load();
    _visits.remove(id);
    for (final list in _lists.values) {
      list.remove(id);
    }
    await _persist();
  }

  /// Drops completed visits older than the retention window.
  Future<void> purgeExpired() async {
    await _load();
    if (_purgeExpiredInMemory()) await _persist();
  }

  bool _purgeExpiredInMemory() {
    final cutoff = _clock().subtract(AppConfig.completedVisitRetention);
    final expired = _visits.values
        .where((v) {
          if (v.status != VisitStatus.completed) return false;
          final doneAt = v.completedAt ?? v.preferredEnd;
          return doneAt == null || doneAt.isBefore(cutoff);
        })
        .map((v) => v.id)
        .toList();
    for (final id in expired) {
      _visits.remove(id);
      for (final list in _lists.values) {
        list.remove(id);
      }
    }
    return expired.isNotEmpty;
  }

  Future<void> clear() async {
    _visits = {};
    _lists = {};
    _loaded = true;
    await _store.delete(StoreKeys.visitCache);
  }
}
