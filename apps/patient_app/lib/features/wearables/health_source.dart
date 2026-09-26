import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// The seven readings the app may import (§40), each with explicit consent.
enum HealthMetric { steps, heartRate, sleep, spo2, bloodPressure, glucose, weight }

enum HealthAvailability {
  available,

  /// Android: Health Connect is not installed.
  notInstalled,

  /// Android: Health Connect must be updated.
  updateRequired,

  /// Web / desktop / unsupported device.
  unsupported,
}

/// One reading from the phone's health store, already in contract units:
/// steps (count), heart rate (bpm), sleep (minutes asleep), SpO2 (%),
/// blood pressure (mmHg, [value] systolic / [value2] diastolic),
/// glucose (mg/dL), weight (kg).
class HealthSample {
  const HealthSample({
    required this.metric,
    required this.value,
    required this.from,
    required this.to,
    this.value2,
  });
  final HealthMetric metric;
  final double value;
  final double? value2;
  final DateTime from;
  final DateTime to;
}

/// Abstraction over Health Connect / HealthKit so sync logic is testable.
abstract class HealthDataSource {
  /// Contract provider code: `health_connect` | `apple_health` | '' (none).
  String get providerCode;

  Future<HealthAvailability> availability();

  /// Asks the OS for per-type read access. Returns false when denied.
  Future<bool> requestPermissions(Set<HealthMetric> metrics);

  Future<List<HealthSample>> read(Set<HealthMetric> metrics, DateTime from, DateTime to);

  /// Revokes the app's access (Android). iOS users revoke in Settings.
  Future<void> revoke();

  /// Opens the Play Store listing for Health Connect.
  Future<void> openInstall();
}

String healthProviderCodeFor(TargetPlatform platform, {bool web = kIsWeb}) {
  if (web) return '';
  return switch (platform) {
    TargetPlatform.android => 'health_connect',
    TargetPlatform.iOS => 'apple_health',
    _ => '',
  };
}

/// `health` package implementation (Android Health Connect / iOS HealthKit).
class HealthPackageSource implements HealthDataSource {
  HealthPackageSource({TargetPlatform? platform}) : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;
  late final Health _health = Health();
  bool _configured = false;

  bool get _android => !kIsWeb && _platform == TargetPlatform.android;
  bool get _ios => !kIsWeb && _platform == TargetPlatform.iOS;

  @override
  String get providerCode => healthProviderCodeFor(_platform);

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  static List<HealthDataType> typesFor(HealthMetric m) => switch (m) {
        HealthMetric.steps => const [HealthDataType.STEPS],
        HealthMetric.heartRate => const [HealthDataType.HEART_RATE],
        HealthMetric.sleep => const [HealthDataType.SLEEP_ASLEEP],
        HealthMetric.spo2 => const [HealthDataType.BLOOD_OXYGEN],
        HealthMetric.bloodPressure => const [
            HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
            HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
          ],
        HealthMetric.glucose => const [HealthDataType.BLOOD_GLUCOSE],
        HealthMetric.weight => const [HealthDataType.WEIGHT],
      };

  List<HealthDataType> _types(Set<HealthMetric> metrics) => [for (final m in metrics) ...typesFor(m)];

  @override
  Future<HealthAvailability> availability() async {
    if (!_android && !_ios) return HealthAvailability.unsupported;
    if (_ios) return HealthAvailability.available;
    try {
      await _configure();
      final status = await _health.getHealthConnectSdkStatus();
      return switch (status) {
        HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => HealthAvailability.updateRequired,
        _ => HealthAvailability.notInstalled,
      };
    } catch (_) {
      return HealthAvailability.notInstalled;
    }
  }

  @override
  Future<bool> requestPermissions(Set<HealthMetric> metrics) async {
    if (metrics.isEmpty) return false;
    await _configure();
    final types = _types(metrics);
    try {
      return await _health.requestAuthorization(types,
          permissions: List.filled(types.length, HealthDataAccess.READ));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<HealthSample>> read(Set<HealthMetric> metrics, DateTime from, DateTime to) async {
    await _configure();
    final out = <HealthSample>[];
    for (final m in metrics) {
      if (m == HealthMetric.bloodPressure) {
        out.addAll(await _readBloodPressure(from, to));
        continue;
      }
      final points = await _safeRead(typesFor(m), from, to);
      for (final p in points) {
        final v = p.value;
        if (v is! NumericHealthValue) continue;
        var value = v.numericValue.toDouble();
        switch (m) {
          case HealthMetric.sleep:
            // Minutes asleep; derive from the interval to avoid unit quirks.
            value = p.dateTo.difference(p.dateFrom).inSeconds / 60;
          case HealthMetric.spo2:
            // HealthKit reports a 0–1 fraction, Health Connect a percentage.
            if (value <= 1.0) value *= 100;
          case HealthMetric.glucose:
            if (p.unit == HealthDataUnit.MILLIMOLES_PER_LITER) value *= 18.0;
          default:
            break;
        }
        out.add(HealthSample(metric: m, value: value, from: p.dateFrom, to: p.dateTo));
      }
    }
    return out;
  }

  Future<List<HealthDataPoint>> _safeRead(List<HealthDataType> types, DateTime from, DateTime to) async {
    try {
      final pts = await _health.getHealthDataFromTypes(types: types, startTime: from, endTime: to);
      return pts; // already de-duplicated by the plugin
    } catch (_) {
      // A type the user did not grant, or unsupported on this device.
      return const [];
    }
  }

  Future<List<HealthSample>> _readBloodPressure(DateTime from, DateTime to) async {
    final sys = await _safeRead(const [HealthDataType.BLOOD_PRESSURE_SYSTOLIC], from, to);
    final dia = await _safeRead(const [HealthDataType.BLOOD_PRESSURE_DIASTOLIC], from, to);
    final byTime = <int, double>{
      for (final d in dia)
        if (d.value is NumericHealthValue)
          d.dateFrom.millisecondsSinceEpoch: (d.value as NumericHealthValue).numericValue.toDouble(),
    };
    return [
      for (final s in sys)
        if (s.value is NumericHealthValue)
          HealthSample(
            metric: HealthMetric.bloodPressure,
            value: (s.value as NumericHealthValue).numericValue.toDouble(),
            value2: byTime[s.dateFrom.millisecondsSinceEpoch],
            from: s.dateFrom,
            to: s.dateTo,
          ),
    ];
  }

  @override
  Future<void> revoke() async {
    if (!_android) return;
    try {
      await _configure();
      await _health.revokePermissions();
    } catch (_) {}
  }

  @override
  Future<void> openInstall() async {
    if (!_android) return;
    try {
      await _configure();
      await _health.installHealthConnect();
    } catch (_) {}
  }
}
