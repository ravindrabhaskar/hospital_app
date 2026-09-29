import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device has a network interface. A "true" does not
/// guarantee the API is reachable; the offline queue handles that case too.
abstract class ConnectivityService {
  Future<bool> isOnline();
  Stream<bool> get onStatusChange;
}

class PlusConnectivityService implements ConnectivityService {
  PlusConnectivityService([Connectivity? connectivity]) : _c = connectivity ?? Connectivity();

  final Connectivity _c;

  static bool _online(List<ConnectivityResult> r) => r.isNotEmpty && r.any((e) => e != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async {
    try {
      return _online(await _c.checkConnectivity());
    } catch (_) {
      return true; // unknown: let the request decide
    }
  }

  @override
  Stream<bool> get onStatusChange => _c.onConnectivityChanged.map(_online).handleError((_) {});
}

/// Manually controlled connectivity for tests.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({bool online = true}) : _isOnline = online;

  bool _isOnline;
  final _controller = StreamController<bool>.broadcast();

  set online(bool value) {
    _isOnline = value;
    _controller.add(value);
  }

  @override
  Future<bool> isOnline() async => _isOnline;

  @override
  Stream<bool> get onStatusChange => _controller.stream;
}
