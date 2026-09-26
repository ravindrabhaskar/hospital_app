import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'config.dart';
import 'connectivity.dart';

/// Posts the device location (`POST /provider/location`) periodically while the
/// provider is on duty. Entirely fail-soft: missing permission, disabled GPS,
/// or network errors just skip that tick.
class LocationReporter {
  LocationReporter({required this.post, required this.connectivity});

  final Future<void> Function(double lat, double lng) post;
  final ConnectivityService connectivity;

  Timer? _timer;
  bool _permissionDenied = false;

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    _permissionDenied = false;
    unawaited(_tick());
    _timer = Timer.periodic(AppConfig.locationInterval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Report immediately (e.g. when starting travel).
  Future<void> reportNow() => _tick();

  Future<void> _tick() async {
    if (_permissionDenied) return;
    try {
      if (!await connectivity.isOnline()) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _permissionDenied = true;
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await post(pos.latitude, pos.longitude);
    } catch (_) {
      // Fail-soft by design.
    }
  }
}
