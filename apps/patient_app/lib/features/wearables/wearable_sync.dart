import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/json.dart';
import '../../models/misc.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import 'health_source.dart';

/// How far back the first sync goes (§40: "the last 7 days").
const wearableSyncWindow = Duration(days: 7);

/// Minimum gap between automatic syncs on app resume.
const wearableResumeThrottle = Duration(minutes: 30);

/// Measurements per `POST /wearables/sync` request.
const wearableSyncBatchSize = 200;

final healthDataSourceProvider = Provider<HealthDataSource>((ref) => HealthPackageSource());

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Converts health-store samples into `/wearables/sync` measurements.
///
/// * Steps become one daily total per local day and sleep one total per
///   wake-up day (the store keeps many small intervals).
/// * Heart rate is averaged per 30-minute bucket to keep payloads small.
/// * Other readings are sent as-is. Point readings at or before
///   [pointsAfter] (the previous sync) are skipped; daily totals are always
///   re-sent for the days they cover so today's total stays current.
List<Json> toMeasurements(List<HealthSample> samples, {DateTime? pointsAfter, DateTime? now}) {
  final out = <Json>[];
  final stepsByDay = <DateTime, double>{};
  final stepsLast = <DateTime, DateTime>{};
  final sleepByDay = <DateTime, double>{};
  final sleepLast = <DateTime, DateTime>{};
  final hrBuckets = <int, List<double>>{};
  String iso(DateTime d) => d.toUtc().toIso8601String();
  bool fresh(DateTime at) => pointsAfter == null || at.isAfter(pointsAfter);

  for (final s in samples) {
    switch (s.metric) {
      case HealthMetric.steps:
        final d = _day(s.from);
        stepsByDay[d] = (stepsByDay[d] ?? 0) + s.value;
        final last = stepsLast[d];
        if (last == null || s.to.isAfter(last)) stepsLast[d] = s.to;
      case HealthMetric.sleep:
        final d = _day(s.to);
        sleepByDay[d] = (sleepByDay[d] ?? 0) + s.value;
        final last = sleepLast[d];
        if (last == null || s.to.isAfter(last)) sleepLast[d] = s.to;
      case HealthMetric.heartRate:
        if (!fresh(s.from)) continue;
        final bucket = s.from.millisecondsSinceEpoch ~/ const Duration(minutes: 30).inMilliseconds;
        (hrBuckets[bucket] ??= []).add(s.value);
      case HealthMetric.spo2:
        if (fresh(s.from)) out.add({'type': 'spo2', 'value': _round(s.value), 'unit': '%', 'measuredAt': iso(s.from)});
      case HealthMetric.bloodPressure:
        if (!fresh(s.from)) continue;
        out.add({'type': 'bp_systolic', 'value': _round(s.value), 'unit': 'mmHg', 'measuredAt': iso(s.from)});
        if (s.value2 != null) {
          out.add({'type': 'bp_diastolic', 'value': _round(s.value2!), 'unit': 'mmHg', 'measuredAt': iso(s.from)});
        }
      case HealthMetric.glucose:
        if (fresh(s.from)) {
          out.add({'type': 'blood_glucose', 'value': _round(s.value), 'unit': 'mg/dL', 'measuredAt': iso(s.from)});
        }
      case HealthMetric.weight:
        if (fresh(s.from)) out.add({'type': 'weight', 'value': _round(s.value), 'unit': 'kg', 'measuredAt': iso(s.from)});
    }
  }
  final bucketMs = const Duration(minutes: 30).inMilliseconds;
  for (final e in hrBuckets.entries) {
    final avg = e.value.reduce((a, b) => a + b) / e.value.length;
    out.add({
      'type': 'pulse',
      'value': avg.roundToDouble(),
      'unit': 'bpm',
      'measuredAt': iso(DateTime.fromMillisecondsSinceEpoch(e.key * bucketMs)),
    });
  }
  for (final e in stepsByDay.entries) {
    out.add({'type': 'steps', 'value': e.value.roundToDouble(), 'unit': 'count', 'measuredAt': iso(stepsLast[e.key]!)});
  }
  for (final e in sleepByDay.entries) {
    out.add({'type': 'sleep_minutes', 'value': e.value.roundToDouble(), 'unit': 'min', 'measuredAt': iso(sleepLast[e.key]!)});
  }
  out.sort((a, b) => (a['measuredAt'] as String).compareTo(b['measuredAt'] as String));
  return out;
}

double _round(double v) => (v * 10).roundToDouble() / 10;

/// Splits [items] into chunks of at most [size].
List<List<T>> batches<T>(List<T> items, int size) => [
      for (var i = 0; i < items.length; i += size) items.sublist(i, i + size > items.length ? items.length : i + size),
    ];

class WearableSyncResult {
  const WearableSyncResult({required this.sent, required this.accepted, required this.requests});
  final int sent;
  final int accepted;
  final int requests;
}

/// Reads the last [wearableSyncWindow] (or since the previous sync) from the
/// health store and uploads it in batches.
class WearableSyncService {
  WearableSyncService({
    required this.source,
    required this.upload,
    this.batchSize = wearableSyncBatchSize,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final HealthDataSource source;
  final Future<int> Function(List<Json> batch) upload;
  final int batchSize;
  final DateTime Function() _clock;

  Future<WearableSyncResult> sync({DateTime? lastSyncAt, Set<HealthMetric> metrics = const {...HealthMetric.values}}) async {
    final now = _clock();
    final floor = now.subtract(wearableSyncWindow);
    // Whole days from the previous sync so daily totals are complete.
    var from = lastSyncAt == null ? floor : _day(lastSyncAt);
    if (from.isBefore(floor)) from = floor;
    final samples = await source.read(metrics, from, now);
    final measurements = toMeasurements(samples, pointsAfter: lastSyncAt, now: now);
    var accepted = 0;
    var requests = 0;
    for (final b in batches(measurements, batchSize)) {
      accepted += await upload(b);
      requests++;
    }
    return WearableSyncResult(sent: measurements.length, accepted: accepted, requests: requests);
  }
}

// ------------------------------------------------------------------ state

@immutable
class WearableSyncState {
  const WearableSyncState({this.syncing = false, this.lastSyncedAt, this.error});
  final bool syncing;
  final DateTime? lastSyncedAt;
  final Object? error;
}

/// Per-patient sync state; the last successful sync time is persisted so
/// resume-syncs are throttled to one per [wearableResumeThrottle].
class WearableSyncController extends Notifier<WearableSyncState> {
  static String keyFor(String patientId) => 'cc_wearable_last_sync_$patientId';

  String? _patientId;

  @override
  WearableSyncState build() {
    _patientId = ref.watch(activePatientProvider.select((v) => v.value?.id));
    return WearableSyncState(lastSyncedAt: _stored());
  }

  DateTime? _stored() {
    final id = _patientId;
    if (id == null) return null;
    try {
      final v = ref.read(sharedPrefsProvider).getString(keyFor(id));
      return v == null ? null : DateTime.tryParse(v);
    } catch (_) {
      return null;
    }
  }

  /// The active connection for this device's health store, if any.
  Future<WearableConnection?> _connection(String patientId, String provider) async {
    final list = await ref.read(wearablesRepositoryProvider).connections(patientId);
    for (final c in list) {
      if (c.provider == provider && c.isConnected) return c;
    }
    return null;
  }

  /// Syncs now. With [onlyIfDue], skips when the last sync was less than
  /// [wearableResumeThrottle] ago or no connection exists.
  Future<WearableSyncResult?> sync({bool onlyIfDue = false}) async {
    if (state.syncing) return null;
    final source = ref.read(healthDataSourceProvider);
    final provider = source.providerCode;
    if (provider.isEmpty || !ref.read(featureFlagsProvider).wearables) return null;
    final last = state.lastSyncedAt;
    if (onlyIfDue && last != null && DateTime.now().difference(last) < wearableResumeThrottle) return null;
    final patientId = _patientId ?? (await ref.read(activePatientProvider.future)).id;
    state = WearableSyncState(syncing: true, lastSyncedAt: last);
    try {
      if (onlyIfDue && await _connection(patientId, provider) == null) {
        state = WearableSyncState(lastSyncedAt: last);
        return null;
      }
      if (await source.availability() != HealthAvailability.available) {
        state = WearableSyncState(lastSyncedAt: last);
        return null;
      }
      final repo = ref.read(wearablesRepositoryProvider);
      final result = await WearableSyncService(
        source: source,
        upload: (batch) => repo.sync(patientId, provider, batch),
      ).sync(lastSyncAt: last);
      final now = DateTime.now();
      try {
        await ref.read(sharedPrefsProvider).setString(keyFor(patientId), now.toIso8601String());
      } catch (_) {}
      state = WearableSyncState(lastSyncedAt: now);
      ref.invalidate(insightsTodayProvider);
      ref.invalidate(wearableConnectionsProvider);
      return result;
    } catch (e) {
      state = WearableSyncState(lastSyncedAt: last, error: e);
      if (!onlyIfDue) rethrow;
      return null;
    }
  }

  Future<void> forget() async {
    final id = _patientId;
    if (id == null) return;
    try {
      await ref.read(sharedPrefsProvider).remove(keyFor(id));
    } catch (_) {}
    state = const WearableSyncState();
  }
}

final wearableSyncProvider =
    NotifierProvider<WearableSyncController, WearableSyncState>(WearableSyncController.new);
