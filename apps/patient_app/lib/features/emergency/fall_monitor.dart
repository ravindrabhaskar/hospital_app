import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/utils/location.dart';
import '../../state/core_providers.dart';
import 'fall_detection_screen.dart' show FallCheckScreen;
import 'fall_detector.dart';

/// The user's opt-in for on-device fall detection (persisted locally).
class FallDetectionOptIn extends Notifier<bool> {
  static const key = 'cc_fall_detection_opt_in';

  @override
  bool build() {
    try {
      return ref.read(sharedPrefsProvider).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      await ref.read(sharedPrefsProvider).setBool(key, on);
    } catch (_) {}
  }
}

final fallDetectionOptInProvider = NotifierProvider<FallDetectionOptIn, bool>(FallDetectionOptIn.new);

/// Phone accelerometer as [AccelSample]s (m/s² incl. gravity). Overridable
/// in tests.
final accelerometerSamplesProvider = Provider<Stream<AccelSample> Function()>((ref) => () {
      final clock = Stopwatch()..start();
      return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .map((e) => AccelSample(clock.elapsed, e.x, e.y, e.z));
    });

/// Fall detection runs only when the server flag is on, the user opted in,
/// a user is signed in and the platform has an accelerometer we use
/// (Android/iOS).
final fallDetectionActiveProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;
  final platform = ref.watch(appPlatformProvider);
  if (platform != 'android' && platform != 'ios') return false;
  return ref.watch(featureFlagsProvider).fallDetection &&
      ref.watch(fallDetectionOptInProvider) &&
      ref.watch(sessionProvider.select((s) => s.isAuthenticated && !s.needsOnboarding));
});

/// Listens to the accelerometer **only while the app is in the foreground**
/// (no background service) and opens the "Are you OK?" flow on a detection.
class FallDetectionHost extends ConsumerStatefulWidget {
  const FallDetectionHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<FallDetectionHost> createState() => _FallDetectionHostState();
}

class _FallDetectionHostState extends ConsumerState<FallDetectionHost> with WidgetsBindingObserver {
  StreamSubscription<AccelSample>? _sub;
  FallDetector _detector = FallDetector();
  bool _foreground = true;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  void _update() {
    if (!mounted) return;
    final shouldRun = _foreground && ref.read(fallDetectionActiveProvider);
    if (shouldRun && _sub == null) {
      _detector = FallDetector();
      try {
        _sub = ref.read(accelerometerSamplesProvider)().listen(_onSample, onError: (_) {
          _sub?.cancel();
          _sub = null;
        });
      } catch (_) {
        _sub = null;
      }
    } else if (!shouldRun && _sub != null) {
      _sub?.cancel();
      _sub = null;
    }
  }

  void _onSample(AccelSample s) {
    if (_handling) return;
    if (_detector.add(s)) _onFall();
  }

  Future<void> _onFall() async {
    _handling = true;
    try {
      final patient = await ref.read(activePatientProvider.future);
      final loc = await tryGetLocation(timeout: const Duration(seconds: 3));
      final ev = await ref
          .read(safetyRepositoryProvider)
          .reportFall(patient.id, source: 'phone_sensor', lat: loc?.lat, lng: loc?.lng);
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => FallCheckScreen(event: ev)),
      );
    } catch (_) {
      // Offline or server error: nothing actionable here; SOS stays one tap away.
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(fallDetectionActiveProvider, (_, _) => _update());
    return widget.child;
  }
}
