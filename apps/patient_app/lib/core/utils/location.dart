import 'package:geolocator/geolocator.dart';

/// Best-effort current location. Never throws; returns null when location
/// services are off, permission is denied or it takes too long.
Future<({double lat, double lng})?> tryGetLocation({Duration timeout = const Duration(seconds: 6)}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: timeout),
    ).timeout(timeout + const Duration(seconds: 1));
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (lat: last.latitude, lng: last.longitude);
    } catch (_) {}
    return null;
  }
}
