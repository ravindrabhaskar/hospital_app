import 'package:care_companion_patient/features/wearables/health_source.dart';
import 'package:care_companion_patient/features/wearables/wearable_sync.dart';
import 'package:care_companion_patient/models/json.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHealthSource implements HealthDataSource {
  FakeHealthSource(this.samples);
  final List<HealthSample> samples;
  final reads = <(DateTime, DateTime)>[];

  @override
  String get providerCode => 'health_connect';

  @override
  Future<HealthAvailability> availability() async => HealthAvailability.available;

  @override
  Future<bool> requestPermissions(Set<HealthMetric> metrics) async => true;

  @override
  Future<List<HealthSample>> read(Set<HealthMetric> metrics, DateTime from, DateTime to) async {
    reads.add((from, to));
    return samples.where((s) => !s.from.isBefore(from) && !s.from.isAfter(to) && metrics.contains(s.metric)).toList();
  }

  @override
  Future<void> revoke() async {}

  @override
  Future<void> openInstall() async {}
}

void main() {
  final now = DateTime(2026, 9, 26, 18, 0);

  HealthSample weight(DateTime at, double kg) =>
      HealthSample(metric: HealthMetric.weight, value: kg, from: at, to: at);

  test('uploads the last 7 days in batches of at most the batch size', () async {
    // 450 weight readings spread over the week → 3 requests of 200/200/50.
    final samples = [
      for (var i = 0; i < 450; i++) weight(now.subtract(Duration(minutes: 20 * i + 1)), 70 + (i % 5) / 10),
    ];
    final source = FakeHealthSource(samples);
    final batches = <List<Json>>[];
    final result = await WearableSyncService(
      source: source,
      clock: () => now,
      upload: (b) async {
        batches.add(b);
        return b.length;
      },
    ).sync();

    expect(source.reads.single.$1, now.subtract(const Duration(days: 7)));
    expect(source.reads.single.$2, now);
    expect(batches.map((b) => b.length).toList(), [200, 200, 50]);
    expect(result.sent, 450);
    expect(result.accepted, 450);
    expect(result.requests, 3);
    expect(batches.first.first.keys.toSet(), {'type', 'value', 'unit', 'measuredAt'});
    expect(batches.first.first['type'], 'weight');
    expect(batches.first.first['unit'], 'kg');
  });

  test('steps and sleep are aggregated per day; heart rate per 30 min; BP split', () {
    final day1 = DateTime(2026, 9, 25);
    final m = toMeasurements([
      HealthSample(metric: HealthMetric.steps, value: 1200, from: day1.add(const Duration(hours: 9)), to: day1.add(const Duration(hours: 10))),
      HealthSample(metric: HealthMetric.steps, value: 800, from: day1.add(const Duration(hours: 17)), to: day1.add(const Duration(hours: 18))),
      HealthSample(metric: HealthMetric.steps, value: 300, from: now.subtract(const Duration(hours: 2)), to: now.subtract(const Duration(hours: 1))),
      HealthSample(metric: HealthMetric.sleep, value: 240, from: day1.add(const Duration(hours: 23)), to: DateTime(2026, 9, 26, 3)),
      HealthSample(metric: HealthMetric.sleep, value: 180, from: DateTime(2026, 9, 26, 3, 30), to: DateTime(2026, 9, 26, 6, 30)),
      HealthSample(metric: HealthMetric.heartRate, value: 70, from: DateTime(2026, 9, 26, 8, 1), to: DateTime(2026, 9, 26, 8, 1)),
      HealthSample(metric: HealthMetric.heartRate, value: 80, from: DateTime(2026, 9, 26, 8, 20), to: DateTime(2026, 9, 26, 8, 20)),
      HealthSample(metric: HealthMetric.bloodPressure, value: 128, value2: 82, from: DateTime(2026, 9, 26, 9), to: DateTime(2026, 9, 26, 9)),
      HealthSample(metric: HealthMetric.spo2, value: 97.04, from: DateTime(2026, 9, 26, 9), to: DateTime(2026, 9, 26, 9)),
      HealthSample(metric: HealthMetric.glucose, value: 110, from: DateTime(2026, 9, 26, 9), to: DateTime(2026, 9, 26, 9)),
    ]);
    List<Json> of(String t) => m.where((e) => e['type'] == t).toList();
    expect(of('steps').map((e) => e['value']), [2000.0, 300.0]);
    expect(of('steps').every((e) => e['unit'] == 'count'), isTrue);
    expect(of('sleep_minutes').single['value'], 420.0); // one wake-up day
    expect(of('pulse').single['value'], 75.0); // averaged in the 08:00–08:30 bucket
    expect(of('bp_systolic').single['value'], 128.0);
    expect(of('bp_diastolic').single['value'], 82.0);
    expect(of('spo2').single['value'], 97.0);
    expect(of('blood_glucose').single['unit'], 'mg/dL');
    // measuredAt is ISO-8601 UTC.
    expect((m.first['measuredAt'] as String).endsWith('Z'), isTrue);
  });

  test('a later sync resumes from the last sync day and skips old point readings', () async {
    final last = now.subtract(const Duration(hours: 3));
    final samples = [
      weight(now.subtract(const Duration(hours: 5)), 70), // before the last sync → skipped
      weight(now.subtract(const Duration(hours: 1)), 71),
      HealthSample(
          metric: HealthMetric.steps,
          value: 500,
          from: now.subtract(const Duration(hours: 6)),
          to: now.subtract(const Duration(hours: 5))),
    ];
    final source = FakeHealthSource(samples);
    final sent = <Json>[];
    await WearableSyncService(
      source: source,
      clock: () => now,
      upload: (b) async {
        sent.addAll(b);
        return b.length;
      },
    ).sync(lastSyncAt: last);
    expect(source.reads.single.$1, DateTime(2026, 9, 26)); // start of that day
    expect(sent.where((e) => e['type'] == 'weight').map((e) => e['value']), [71.0]);
    // Today's step total is re-sent so it stays current.
    expect(sent.where((e) => e['type'] == 'steps').single['value'], 500.0);
  });

  test('batches() splits evenly and handles empty input', () {
    expect(batches<int>([], 3), isEmpty);
    expect(batches([1, 2, 3, 4, 5, 6, 7], 3), [
      [1, 2, 3],
      [4, 5, 6],
      [7],
    ]);
  });

  test('provider code follows the platform (web unsupported)', () {
    expect(healthProviderCodeFor(TargetPlatform.android, web: false), 'health_connect');
    expect(healthProviderCodeFor(TargetPlatform.iOS, web: false), 'apple_health');
    expect(healthProviderCodeFor(TargetPlatform.android, web: true), '');
  });
}
