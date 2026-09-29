import 'home_visit.dart';
import 'json.dart';

/// `GET /provider/route?date=` (API contract §48).
class RoutePlan {
  const RoutePlan({required this.date, required this.stops, required this.totalKm, this.startLat, this.startLng});

  final String date;
  final List<RouteStop> stops;
  final num totalKm;
  final double? startLat;
  final double? startLng;

  bool get hasStart => startLat != null && startLng != null;

  /// Stops in visiting order (the server orders them; we sort defensively).
  List<RouteStop> get ordered => [...stops]..sort((a, b) => a.order.compareTo(b.order));

  factory RoutePlan.fromJson(Json json) {
    final start = json['startLocation'] is Map ? asJson(json['startLocation']) : null;
    return RoutePlan(
      date: strOr(json['date']),
      stops: jsonList(json['stops']).map(RouteStop.fromJson).toList(),
      totalKm: numOrNull(json['totalKm']) ?? 0,
      startLat: numOrNull(start?['lat'])?.toDouble(),
      startLng: numOrNull(start?['lng'])?.toDouble(),
    );
  }
}

class RouteStop {
  const RouteStop({
    required this.order,
    required this.visitId,
    required this.serviceName,
    required this.windowStart,
    required this.windowEnd,
    required this.addressText,
    this.lat,
    this.lng,
    this.distanceFromPrevKm,
    this.etaAt,
  });

  final int order;
  final String visitId;
  final String serviceName;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  /// §48 lists `address` without a shape: accept an `Address` object or a string.
  final String addressText;
  final double? lat;
  final double? lng;
  final num? distanceFromPrevKm;
  final DateTime? etaAt;

  bool get hasCoordinates => lat != null && lng != null;

  /// What Google Maps gets for this stop: coordinates when known, else the address.
  String get mapsLocation => hasCoordinates ? '$lat,$lng' : addressText;

  factory RouteStop.fromJson(Json json) {
    final window = asJson(json['window']);
    final rawAddress = json['address'];
    final address = rawAddress is Map ? Address.fromJson(asJson(rawAddress)).fullText : strOr(rawAddress);
    return RouteStop(
      order: intOrNull(json['order']) ?? 0,
      visitId: strOr(json['visitId']),
      serviceName: strOr(json['serviceName']),
      windowStart: dateOrNull(window['start']),
      windowEnd: dateOrNull(window['end']),
      addressText: address,
      lat: numOrNull(json['lat'])?.toDouble(),
      lng: numOrNull(json['lng'])?.toDouble(),
      distanceFromPrevKm: numOrNull(json['distanceFromPrevKm']),
      etaAt: dateOrNull(json['etaAt']),
    );
  }
}

/// Google Maps multi-stop directions (Maps URLs API; no API key needed).
///
/// The last stop is the destination and the ones before it are waypoints, in
/// visiting order. Without an origin, Maps starts from the device location.
/// Maps URLs accept up to 9 waypoints on mobile, so longer routes are cut to
/// the first 10 stops (the provider can re-open navigation later).
Uri buildMapsRouteUri(List<RouteStop> stops, {double? originLat, double? originLng}) {
  final ordered = ([...stops]..sort((a, b) => a.order.compareTo(b.order)))
      .where((s) => s.mapsLocation.isNotEmpty)
      .take(maxMapsStops)
      .toList();
  if (ordered.isEmpty) throw ArgumentError('No stops to navigate to');
  final destination = ordered.last.mapsLocation;
  final waypoints = ordered.sublist(0, ordered.length - 1).map((s) => s.mapsLocation).toList();
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    if (originLat != null && originLng != null) 'origin': '$originLat,$originLng',
    'destination': destination,
    if (waypoints.isNotEmpty) 'waypoints': waypoints.join('|'),
    'travelmode': 'driving',
  });
}

const maxMapsStops = 10;

/// `POST /provider/attendance` response.
class AttendanceEvent {
  const AttendanceEvent({required this.id, required this.action, required this.at});
  final String id;
  final String action;
  final DateTime? at;

  factory AttendanceEvent.fromJson(Json json) =>
      AttendanceEvent(id: strOr(json['id']), action: strOr(json['action']), at: dateOrNull(json['at']));
}

/// One row of `GET /provider/attendance?month=`.
class AttendanceDay {
  const AttendanceDay({required this.date, this.checkInAt, this.checkOutAt, this.hours = 0, this.visits = 0});

  /// `YYYY-MM-DD`.
  final String date;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final num hours;
  final int visits;

  factory AttendanceDay.fromJson(Json json) => AttendanceDay(
        date: strOr(json['date']),
        checkInAt: dateOrNull(json['checkInAt']),
        checkOutAt: dateOrNull(json['checkOutAt']),
        hours: numOrNull(json['hours']) ?? 0,
        visits: intOrNull(json['visits']) ?? 0,
      );
}

class AttendanceMonth {
  const AttendanceMonth(this.days);
  final List<AttendanceDay> days;

  int get daysPresent => days.where((d) => d.checkInAt != null).length;
  num get totalHours => days.fold<num>(0, (sum, d) => sum + d.hours);
  int get totalVisits => days.fold<int>(0, (sum, d) => sum + d.visits);

  AttendanceDay? day(String date) {
    for (final d in days) {
      if (d.date == date) return d;
    }
    return null;
  }

  factory AttendanceMonth.fromJson(Json json) =>
      AttendanceMonth(jsonList(json['items']).map(AttendanceDay.fromJson).toList()
        ..sort((a, b) => b.date.compareTo(a.date)));
}

/// One on-hand supply (`GET /provider/supplies`).
class SupplyItem {
  const SupplyItem({
    required this.code,
    required this.name,
    required this.unit,
    required this.onHand,
    required this.reorderLevel,
  });

  final String code;
  final String name;
  final String unit;
  final num onHand;
  final num reorderLevel;

  bool get isOut => onHand <= 0;
  bool get isLow => onHand <= reorderLevel;

  factory SupplyItem.fromJson(Json json) => SupplyItem(
        code: strOr(json['code']),
        name: strOr(json['name'], strOr(json['code'])),
        unit: strOr(json['unit']),
        onHand: numOrNull(json['onHand']) ?? 0,
        reorderLevel: numOrNull(json['reorderLevel']) ?? 0,
      );

  Json toJson() => {'code': code, 'name': name, 'unit': unit, 'onHand': onHand, 'reorderLevel': reorderLevel};
}

/// Parses `{ items: [...] }` (or a bare list) into supplies, low stock first.
List<SupplyItem> parseSupplies(Object? res) {
  final raw = res is List ? jsonList(res) : jsonList(asJson(res)['items']);
  final items = raw.map(SupplyItem.fromJson).toList()
    ..sort((a, b) {
      if (a.isLow != b.isLow) return a.isLow ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return items;
}

/// Body for `POST /provider/supplies/usage`; zero quantities are left out.
Map<String, dynamic> suppliesUsageBody(String visitId, Map<String, int> quantities) => {
      'visitId': visitId,
      'items': [
        for (final e in quantities.entries)
          if (e.value > 0) {'code': e.key, 'qty': e.value},
      ],
    };
