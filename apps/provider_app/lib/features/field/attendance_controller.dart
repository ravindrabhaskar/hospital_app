import 'package:flutter/foundation.dart';

import '../../core/location_reporter.dart';
import '../../models/care_plans.dart' show ymd;
import '../../models/field_ops.dart';
import 'field_repository.dart';

enum AttendanceStatus {
  /// Not loaded yet (or the load failed).
  unknown,
  notCheckedIn,
  checkedIn,
  checkedOut,
}

/// `YYYY-MM` for the attendance query.
String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Today's check-in/check-out state (contract §48).
///
/// Loaded from `GET /provider/attendance?month=` (today's row) and advanced
/// from each `POST /provider/attendance` response. Location is attached only
/// when the device grants it; a missing fix never blocks attendance.
class AttendanceController extends ChangeNotifier {
  AttendanceController({required this.repo, required this.readPosition, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FieldRepository repo;
  final PositionReader readPosition;
  final DateTime Function() _clock;

  AttendanceStatus _status = AttendanceStatus.unknown;
  DateTime? _checkInAt;
  DateTime? _checkOutAt;
  bool _busy = false;
  Object? _error;
  bool? _lastHadLocation;

  AttendanceStatus get status => _status;
  DateTime? get checkInAt => _checkInAt;
  DateTime? get checkOutAt => _checkOutAt;
  bool get busy => _busy;
  Object? get error => _error;

  /// Whether the last check-in/out carried a location (null before any).
  bool? get lastHadLocation => _lastHadLocation;

  static AttendanceStatus statusFor(AttendanceDay? day) {
    if (day == null || day.checkInAt == null) return AttendanceStatus.notCheckedIn;
    if (day.checkOutAt == null) return AttendanceStatus.checkedIn;
    return AttendanceStatus.checkedOut;
  }

  Future<void> load() async {
    final now = _clock();
    try {
      final month = await repo.attendanceMonth(monthKey(now));
      final today = month.day(ymd(now));
      _status = statusFor(today);
      _checkInAt = today?.checkInAt;
      _checkOutAt = today?.checkOutAt;
      _error = null;
    } catch (e) {
      _error = e;
    }
    notifyListeners();
  }

  Future<void> checkIn() => _act('check_in');
  Future<void> checkOut() => _act('check_out');

  Future<void> _act(String action) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final pos = await readPosition();
      _lastHadLocation = pos != null;
      final event = await repo.attendance(action, lat: pos?.lat, lng: pos?.lng);
      final at = event.at ?? _clock().toUtc();
      if (action == 'check_in') {
        _status = AttendanceStatus.checkedIn;
        _checkInAt = at;
        _checkOutAt = null;
      } else {
        _status = AttendanceStatus.checkedOut;
        _checkOutAt = at;
      }
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
