import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'storage/key_value_store.dart';

/// Where location access stands for this app.
enum LocationAccess {
  /// Allowed (while in use or always).
  granted,

  /// Not allowed yet; the system prompt can still be shown.
  denied,

  /// Blocked; only the system Settings can allow it now.
  deniedForever,

  /// The phone's location service (GPS) is switched off.
  serviceOff,

  /// Could not be determined (no plugin, e.g. tests); never prompts.
  unknown,
}

/// Thin seam over the platform permission API (tests swap it).
abstract class LocationPermissions {
  Future<LocationAccess> check();
  Future<LocationAccess> request();

  /// Opens the app's system settings (blocked permission) or the location
  /// settings (GPS off). Returns false when nothing could be opened.
  Future<bool> openSettings({bool locationService = false});
}

class GeolocatorPermissions implements LocationPermissions {
  const GeolocatorPermissions();

  static LocationAccess _map(LocationPermission p) => switch (p) {
        LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.denied => LocationAccess.denied,
        _ => LocationAccess.unknown,
      };

  @override
  Future<LocationAccess> check() async {
    try {
      final permission = _map(await Geolocator.checkPermission());
      if (permission == LocationAccess.granted && !await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceOff;
      }
      return permission;
    } catch (_) {
      return LocationAccess.unknown;
    }
  }

  @override
  Future<LocationAccess> request() async {
    try {
      return _map(await Geolocator.requestPermission());
    } catch (_) {
      return LocationAccess.unknown;
    }
  }

  @override
  Future<bool> openSettings({bool locationService = false}) async {
    try {
      return locationService ? await Geolocator.openLocationSettings() : await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

/// Location permission flow: the app explains why it needs location (in-app
/// rationale) before the system prompt, asks automatically at most once, and
/// afterwards only when the provider taps "Turn on location" (Route tab,
/// Profile). Background reporting never prompts.
class LocationAccessController extends ChangeNotifier {
  LocationAccessController({required this.permissions, required this.store, this.onGranted});

  final LocationPermissions permissions;
  final KeyValueStore store;

  /// Called whenever access turns out to be granted (e.g. resume reporting).
  VoidCallback? onGranted;

  /// Device-level preference; deliberately not part of the logout wipe.
  static const askedKey = 'location.rationaleShown';

  LocationAccess _access = LocationAccess.unknown;
  LocationAccess get access => _access;

  /// Access is missing and the provider can do something about it.
  bool get needsAction =>
      _access == LocationAccess.denied ||
      _access == LocationAccess.deniedForever ||
      _access == LocationAccess.serviceOff;

  void _set(LocationAccess a) {
    final wasGranted = _access == LocationAccess.granted;
    if (a != _access) {
      _access = a;
      notifyListeners();
    }
    if (a == LocationAccess.granted && !wasGranted) onGranted?.call();
  }

  Future<LocationAccess> refresh() async {
    _set(await permissions.check());
    return _access;
  }

  /// True when the one-time automatic rationale should be shown now.
  Future<bool> shouldAutoPrompt() async {
    final a = await refresh();
    if (a != LocationAccess.denied) return false;
    return await store.read(askedKey) == null;
  }

  Future<void> markAsked() => store.write(askedKey, '1');

  /// User-initiated "Turn on location": system prompt, or Settings when the
  /// permission is blocked / GPS is off. Returns the resulting access.
  Future<LocationAccess> requestFromUser() async {
    await markAsked();
    switch (_access) {
      case LocationAccess.deniedForever:
        await permissions.openSettings();
        break;
      case LocationAccess.serviceOff:
        await permissions.openSettings(locationService: true);
        break;
      default:
        final r = await permissions.request();
        if (r != LocationAccess.granted) {
          _set(r);
          return r;
        }
    }
    return refresh();
  }
}
