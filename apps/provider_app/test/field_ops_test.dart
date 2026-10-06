import 'dart:convert';

import 'package:care_companion_provider/core/api/api_client.dart';
import 'package:care_companion_provider/core/api/token_store.dart';
import 'package:care_companion_provider/core/connectivity.dart';
import 'package:care_companion_provider/core/providers.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/features/field/attendance_controller.dart';
import 'package:care_companion_provider/features/field/attendance_screen.dart';
import 'package:care_companion_provider/features/field/field_repository.dart';
import 'package:care_companion_provider/features/field/route_view.dart';
import 'package:care_companion_provider/features/field/supplies_screen.dart';
import 'package:care_companion_provider/features/offline/offline_queue.dart';
import 'package:care_companion_provider/features/offline/visit_action_service.dart';
import 'package:care_companion_provider/features/offline/visit_cache.dart';
import 'package:care_companion_provider/features/visits/data/provider_repository.dart';
import 'package:care_companion_provider/features/visits/domain/visit_lifecycle.dart';
import 'package:care_companion_provider/models/field_ops.dart';
import 'package:care_companion_provider/models/home_visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

typedef Handler = Future<http.Response> Function(http.Request req, String path);

http.Response jsonRes(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

ApiClient apiWith(Handler handler, {List<http.Request>? log}) {
  final client = MockClient((req) async {
    log?.add(req);
    return handler(req, req.url.path.replaceFirst('/api/v1', ''));
  });
  return ApiClient(baseUrl: 'http://test/api/v1', tokens: TokenStore(MemoryKeyValueStore()), httpClient: client);
}

Map<String, dynamic> stop(int order, String id,
        {double? lat, double? lng, Object? address, num? km, String? eta, String? status = 'accepted'}) =>
    {
      'order': order,
      'status': ?status,
      'visitId': id,
      'serviceName': 'Service $id',
      'window': {'start': '2026-09-29T04:00:00.000Z', 'end': '2026-09-29T05:00:00.000Z'},
      'address': address ?? {'line1': 'House $id', 'city': 'Hyderabad', 'pincode': '500001'},
      'lat': lat,
      'lng': lng,
      'distanceFromPrevKm': km,
      'etaAt': eta,
    };

Map<String, dynamic> routeJson() => {
      'date': '2026-09-29',
      // Deliberately out of order: the app sorts by `order`.
      'stops': [
        stop(3, 'c', lat: 17.44, lng: 78.35, km: 6.2, eta: '2026-09-29T07:10:00.000Z'),
        stop(1, 'a', lat: 17.40, lng: 78.48, km: 2.5, eta: '2026-09-29T04:15:00.000Z'),
        stop(2, 'b', address: '5 Park Lane, Hyderabad', km: 3.8, eta: '2026-09-29T05:30:00.000Z'),
      ],
      'totalKm': 12.5,
      'startLocation': {'lat': 17.38, 'lng': 78.47},
    };

void main() {
  group('route (§48)', () {
    test('maps URL keeps waypoints in visiting order and ends at the last stop', () {
      final plan = RoutePlan.fromJson(routeJson());
      final uri = buildMapsRouteUri(plan.stops, originLat: plan.startLat, originLng: plan.startLng);
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      final q = uri.queryParameters;
      expect(q['api'], '1');
      expect(q['origin'], '17.38,78.47');
      expect(q['waypoints'], '17.4,78.48|5 Park Lane, Hyderabad', reason: 'stop 1 then stop 2 (address fallback)');
      expect(q['destination'], '17.44,78.35');
      expect(q['travelmode'], 'driving');
      expect(q.containsKey('key'), isFalse, reason: 'no API key needed');
    });

    test('maps URL: one stop has no waypoints; long routes are capped', () {
      final one = buildMapsRouteUri([RouteStop.fromJson(stop(1, 'a', lat: 1, lng: 2))]);
      expect(one.queryParameters['destination'], '1.0,2.0');
      expect(one.queryParameters.containsKey('waypoints'), isFalse);
      expect(one.queryParameters.containsKey('origin'), isFalse, reason: 'Maps uses the device location');

      final many = [for (var i = 12; i >= 1; i--) RouteStop.fromJson(stop(i, 's$i', lat: i.toDouble(), lng: 0))];
      final q = buildMapsRouteUri(many).queryParameters;
      expect(q['waypoints']!.split('|'), [for (var i = 1; i <= 9; i++) '${i.toDouble()},0.0']);
      expect(q['destination'], '10.0,0.0');
    });

    testWidgets('route list renders ordered stops, distances, ETA and total km', (tester) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(RouteList(plan: RoutePlan.fromJson(routeJson())), wrap: false));
      await tester.pumpAndSettle();

      expect(find.text('3 stops · 12.5 km in total'), findsOneWidget);
      expect(find.byKey(const Key('routeNavigate')), findsOneWidget);
      final ys = ['a', 'b', 'c'].map((id) => tester.getTopLeft(find.byKey(Key('routeStop.$id'))).dy).toList();
      expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue, reason: 'rendered in order 1, 2, 3');
      expect(find.text('Service a'), findsOneWidget);
      expect(find.textContaining('2.5 km from start'), findsOneWidget);
      expect(find.textContaining('3.8 km from previous stop'), findsOneWidget);
      expect(find.textContaining('ETA'), findsNWidgets(3));
      expect(find.text('5 Park Lane, Hyderabad'), findsOneWidget);
    });

    testWidgets('route view fetches today and pull-to-refresh refetches', (tester) async {
      final log = <http.Request>[];
      final api = apiWith((req, path) async => jsonRes(path == '/provider/route' ? routeJson() : null, 200), log: log);
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: [fieldRepositoryProvider.overrideWithValue(FieldRepository(api))],
        child: testApp(RouteView(now: DateTime(2026, 9, 29, 8)), wrap: false),
      ));
      await tester.pumpAndSettle();
      expect(log.single.url.queryParameters['date'], '2026-09-29');
      expect(find.byKey(const Key('routeSummary')), findsOneWidget);

      await tester.fling(find.byKey(const Key('routeSummary')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(log.length, 2);
    });

    test('B7: finished visits are not stops or Maps waypoints', () {
      final plan = RoutePlan.fromJson({
        'date': '2026-09-29',
        'stops': [
          stop(1, 'done', lat: 1, lng: 1, status: 'completed'),
          stop(2, 'gone', lat: 2, lng: 2, status: 'cancelled'),
          stop(3, 'rej', lat: 3, lng: 3, status: 'rejected'),
          stop(4, 'next', lat: 4, lng: 4, status: 'en_route'),
          stop(5, 'later', lat: 5, lng: 5, status: 'accepted'),
        ],
        'totalKm': 9,
      });
      final remaining = plan.remaining();
      expect(remaining.map((s) => s.visitId), ['next', 'later']);
      final q = buildMapsRouteUri(remaining).queryParameters;
      expect(q['waypoints'], '4.0,4.0');
      expect(q['destination'], '5.0,5.0');
    });

    test('B2: a visit not yet accepted keeps only area + pincode (list and Maps)', () {
      final plan = RoutePlan.fromJson({
        'date': '2026-09-29',
        'stops': [
          stop(1, 'ok', address: {'line1': '1 Known St', 'city': 'Hyderabad', 'pincode': '500001'}),
          stop(2, 'new',
              lat: 17.4,
              lng: 78.5,
              status: 'assigned',
              address: {'line1': '12 Secret Lane', 'landmark': 'Blue gate', 'city': 'Hyderabad', 'pincode': '500034'}),
        ],
        'totalKm': 3,
      });
      final remaining = plan.remaining();
      final hidden = remaining.last;
      expect(hidden.addressHidden, isTrue);
      expect(hidden.addressText, isEmpty);
      expect(hidden.hasCoordinates, isFalse);
      final uri = buildMapsRouteUri(remaining).toString();
      expect(uri, isNot(contains('Secret')));
      expect(uri, isNot(contains('17.4')));
      expect(buildMapsRouteUri(remaining).queryParameters['destination'], 'Hyderabad 500034');
      expect(remaining.first.addressText, '1 Known St, Hyderabad, 500001');
    });

    test('stops without a status use the known visit statuses; unknown means area only', () {
      final plan = RoutePlan.fromJson({
        'date': '2026-09-29',
        'stops': [
          stop(1, 'a', status: null),
          stop(2, 'b', status: null),
          stop(3, 'c', status: null),
        ],
        'totalKm': 0,
      });
      final remaining = plan.remaining({'a': 'completed', 'b': 'arrived'});
      expect(remaining.map((s) => s.visitId), ['b', 'c']);
      expect(remaining[0].addressHidden, isFalse);
      expect(remaining[1].addressHidden, isTrue);
    });

    testWidgets('B2/B7: route list hides finished stops and the street of unaccepted ones', (tester) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final plan = RoutePlan.fromJson({
        'date': '2026-09-29',
        'stops': [
          stop(1, 'done', status: 'completed', address: {'line1': 'Done Road', 'city': 'Hyderabad', 'pincode': '500001'}),
          stop(2, 'new',
              status: 'assigned',
              address: {'line1': '12 Secret Lane', 'landmark': 'Blue gate', 'city': 'Hyderabad', 'pincode': '500034'}),
        ],
        'totalKm': 3,
      });
      await tester.pumpWidget(testApp(RouteList(plan: plan), wrap: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('routeStop.done')), findsNothing);
      expect(find.byKey(const Key('routeStop.new')), findsOneWidget);
      expect(find.textContaining('Secret'), findsNothing);
      expect(find.textContaining('Blue gate'), findsNothing);
      expect(find.text('Hyderabad – 500034'), findsOneWidget);
      expect(find.text('1 stop · 3.0 km in total'), findsOneWidget);
    });

    testWidgets('empty route shows the empty state', (tester) async {
      await tester.pumpWidget(testApp(
          RouteList(plan: RoutePlan.fromJson({'date': '2026-09-29', 'stops': [], 'totalKm': 0, 'startLocation': null})),
          wrap: false));
      expect(find.text('No stops on your route today.'), findsOneWidget);
      expect(find.byKey(const Key('routeNavigate')), findsNothing);
    });
  });

  group('attendance (§48)', () {
    final now = DateTime(2026, 9, 29, 9, 0);

    AttendanceController controller(Handler handler,
            {List<http.Request>? log, ({double lat, double lng})? position = (lat: 17.4, lng: 78.5)}) =>
        AttendanceController(
          repo: FieldRepository(apiWith(handler, log: log)),
          readPosition: () async => position,
          clock: () => now,
        );

    test('status per day row', () {
      expect(AttendanceController.statusFor(null), AttendanceStatus.notCheckedIn);
      expect(AttendanceController.statusFor(AttendanceDay.fromJson({'date': '2026-09-29', 'checkInAt': '2026-09-29T03:30:00Z'})),
          AttendanceStatus.checkedIn);
      expect(
          AttendanceController.statusFor(AttendanceDay.fromJson(
              {'date': '2026-09-29', 'checkInAt': '2026-09-29T03:30:00Z', 'checkOutAt': '2026-09-29T12:00:00Z'})),
          AttendanceStatus.checkedOut);
    });

    test('load reads today from the month, then check in and out with location', () async {
      final log = <http.Request>[];
      final c = controller((req, path) async {
        if (req.method == 'GET') {
          return jsonRes({
            'items': [
              {'date': '2026-09-28', 'checkInAt': '2026-09-28T03:30:00Z', 'checkOutAt': '2026-09-28T12:00:00Z', 'hours': 8.5, 'visits': 4},
            ],
          });
        }
        final action = (jsonDecode(req.body) as Map)['action'];
        return jsonRes({'id': 'att-1', 'action': action, 'at': '2026-09-29T03:31:00.000Z', 'lat': 17.4, 'lng': 78.5});
      }, log: log);

      expect(c.status, AttendanceStatus.unknown);
      await c.load();
      expect(log.first.url.queryParameters['month'], '2026-09');
      expect(c.status, AttendanceStatus.notCheckedIn, reason: "yesterday's row doesn't count");

      await c.checkIn();
      expect(c.status, AttendanceStatus.checkedIn);
      expect(c.checkInAt, DateTime.parse('2026-09-29T03:31:00.000Z'));
      expect(jsonDecode(log.last.body), {'action': 'check_in', 'lat': 17.4, 'lng': 78.5});
      expect(c.lastHadLocation, isTrue);

      await c.checkOut();
      expect(c.status, AttendanceStatus.checkedOut);
      expect((jsonDecode(log.last.body) as Map)['action'], 'check_out');
    });

    test('without location permission the check-in is sent without lat/lng', () async {
      final log = <http.Request>[];
      final c = controller((req, path) async => jsonRes({'id': 'x', 'action': 'check_in', 'at': null}),
          log: log, position: null);
      await c.checkIn();
      expect(jsonDecode(log.single.body), {'action': 'check_in'});
      expect(c.lastHadLocation, isFalse);
      expect(c.status, AttendanceStatus.checkedIn);
    });

    test('a failed check-in keeps the previous state and reports the error', () async {
      final c = controller((req, path) async => jsonRes({'error': {'code': 'CONFLICT', 'message': 'Already checked in'}}, 409));
      await expectLater(c.checkIn(), throwsA(anything));
      expect(c.status, AttendanceStatus.unknown);
      expect(c.busy, isFalse);
      expect(c.error, isNotNull);
    });

    testWidgets('home card checks in, then offers check out', (tester) async {
      final api = apiWith((req, path) async {
        if (req.method == 'GET') return jsonRes({'items': []});
        return jsonRes({'id': 'a', 'action': 'check_in', 'at': '2026-09-29T03:31:00.000Z'});
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          fieldRepositoryProvider.overrideWithValue(FieldRepository(api)),
          positionReaderProvider.overrideWithValue(() async => null),
          clockProvider.overrideWithValue(() => now),
        ],
        child: testApp(const AttendanceCard()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Not checked in today'), findsOneWidget);
      await tester.tap(find.byKey(const Key('attCheckIn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attCheckOut')), findsOneWidget);
      expect(find.textContaining('Checked in at'), findsOneWidget);
      expect(find.textContaining('Location was not available'), findsOneWidget);
    });

    testWidgets('monthly view shows totals and per-day hours and visits', (tester) async {
      final month = AttendanceMonth.fromJson({
        'items': [
          {'date': '2026-09-01', 'checkInAt': '2026-09-01T03:30:00Z', 'checkOutAt': '2026-09-01T12:00:00Z', 'hours': 8.5, 'visits': 4},
          {'date': '2026-09-02', 'checkInAt': '2026-09-02T03:30:00Z', 'checkOutAt': null, 'hours': 0, 'visits': 1},
          {'date': '2026-09-03', 'checkInAt': null, 'checkOutAt': null, 'hours': 0, 'visits': 0},
        ],
      });
      expect(month.daysPresent, 2);
      expect(month.totalHours, 8.5);
      expect(month.totalVisits, 5);
      await tester.pumpWidget(testApp(AttendanceMonthView(month: month), wrap: false));
      expect(find.descendant(of: find.byKey(const Key('att.hours')), matching: find.text('8.5')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('att.visits')), matching: find.text('5')), findsOneWidget);
      expect(find.text('4 visits'), findsOneWidget);
      expect(find.textContaining('not checked out'), findsOneWidget);
      expect(find.text('No check-in'), findsOneWidget);
    });
  });

  group('supplies (§48)', () {
    test('low stock is flagged and listed first', () {
      final items = parseSupplies({
        'items': [
          {'code': 'gloves', 'name': 'Gloves', 'unit': 'pair', 'onHand': 40, 'reorderLevel': 10},
          {'code': 'strips', 'name': 'Glucose strips', 'unit': 'strip', 'onHand': 5, 'reorderLevel': 10},
          {'code': 'swabs', 'name': 'Alcohol swabs', 'unit': 'pc', 'onHand': 0, 'reorderLevel': 20},
        ],
      });
      expect(items.map((i) => i.code), ['swabs', 'strips', 'gloves']);
      expect(items[0].isOut, isTrue);
      expect(items[1].isLow, isTrue);
      expect(items[2].isLow, isFalse);
    });

    testWidgets('supplies screen highlights low and out-of-stock items', (tester) async {
      final api = apiWith((req, path) async => jsonRes({
            'items': [
              {'code': 'gloves', 'name': 'Gloves', 'unit': 'pair', 'onHand': 40, 'reorderLevel': 10},
              {'code': 'strips', 'name': 'Glucose strips', 'unit': 'strip', 'onHand': 5, 'reorderLevel': 10},
            ],
          }));
      await tester.pumpWidget(ProviderScope(
        overrides: [fieldRepositoryProvider.overrideWithValue(FieldRepository(api, store: MemoryKeyValueStore()))],
        child: testApp(const SuppliesScreen(), wrap: false),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('supLowBanner')), findsOneWidget);
      expect(find.byKey(const Key('supTag.strips')), findsOneWidget);
      expect(find.byKey(const Key('supTag.gloves')), findsNothing);
    });

    test('supplies list falls back to the encrypted cache when offline', () async {
      final store = MemoryKeyValueStore();
      var online = true;
      final repo = FieldRepository(
          apiWith((req, path) async {
            if (!online) throw http.ClientException('offline');
            return jsonRes({
              'items': [
                {'code': 'gloves', 'name': 'Gloves', 'unit': 'pair', 'onHand': 40, 'reorderLevel': 10},
              ],
            });
          }),
          store: store);
      expect((await repo.supplies()).fromCache, isFalse);
      online = false;
      final cached = await repo.supplies();
      expect(cached.fromCache, isTrue);
      expect(cached.items.single.code, 'gloves');
      expect(StoreKeys.all, contains(StoreKeys.supplies), reason: 'wiped on logout');
    });

    group('usage through the offline queue', () {
      late List<http.Request> requests;
      late Set<String> executed;
      late bool reachable;
      late bool loseNext;
      late int? failWith;
      late FakeConnectivityService connectivity;
      late VisitActionService service;
      late OfflineQueue queue;

      setUp(() {
        requests = [];
        executed = {};
        reachable = true;
        loseNext = false;
        failWith = null;
        connectivity = FakeConnectivityService(online: false);
        final api = apiWith((req, path) async {
          if (!reachable) throw http.ClientException('offline');
          requests.add(req);
          if (path == '/provider/supplies/usage') {
            if (failWith != null) return jsonRes({'error': {'code': 'FORBIDDEN', 'message': 'no'}}, failWith!);
            executed.add(req.headers['Idempotency-Key']!);
            if (loseNext) {
              loseNext = false;
              throw http.ClientException('connection reset');
            }
            return jsonRes({'items': []});
          }
          return jsonRes(visitJson(status: VisitStatus.inProgress));
        });
        final store = MemoryKeyValueStore();
        queue = OfflineQueue(store: store, sender: ProviderRepository(api).sendAction);
        service = VisitActionService(queue: queue, cache: VisitCache(store), connectivity: connectivity);
      });

      tearDown(() => service.dispose());

      test('queued offline, replayed once with the same Idempotency-Key', () async {
        final v = visit(status: VisitStatus.inProgress);
        final outcome = await service.recordSuppliesUsage(v, {'gloves': 2, 'strips': 0, 'swabs': 3});
        expect(outcome.kind, ActionOutcomeKind.pending);
        expect(outcome.visit!.status, VisitStatus.inProgress, reason: 'not a lifecycle transition');
        expect(requests, isEmpty);
        final queued = queue.items.single;
        expect(queued.type, VisitActionType.suppliesUsage);
        expect(queued.path, '/provider/supplies/usage');

        connectivity.online = true;
        await service.syncNow();
        await service.syncNow(); // nothing left
        expect(requests, hasLength(1));
        final req = requests.single;
        expect(req.method, 'POST');
        expect(req.url.path, '/api/v1/provider/supplies/usage');
        expect(req.headers['Idempotency-Key'], queued.id);
        expect(jsonDecode(req.body), {
          'visitId': 'visit-1',
          'items': [
            {'code': 'gloves', 'qty': 2},
            {'code': 'swabs', 'qty': 3},
          ],
        });
        expect(queue.pendingCount, 0);
      });

      test('a lost response is replayed with the same key', () async {
        connectivity.online = true;
        loseNext = true;
        final outcome = await service.recordSuppliesUsage(visit(status: VisitStatus.inProgress), {'gloves': 1});
        expect(outcome.kind, ActionOutcomeKind.pending);
        await service.syncNow();
        expect(requests.map((r) => r.headers['Idempotency-Key']).toSet(), hasLength(1));
        expect(requests, hasLength(2));
        expect(executed, hasLength(1));
        expect(queue.pendingCount, 0);
      });

      test('a 403 drops only the usage item, not the rest of the visit', () async {
        final v = visit(status: VisitStatus.inProgress);
        await service.recordSuppliesUsage(v, {'gloves': 1});
        await service.perform(v, VisitActionType.observations, {'notes': 'ok', 'checklist': {}});
        expect(queue.pendingCount, 2);
        failWith = 403;
        connectivity.online = true;
        final outcomes = await queue.flush();
        expect(outcomes.values.map((o) => o.kind), [ActionOutcomeKind.rejected, ActionOutcomeKind.synced]);
        expect(queue.pendingCount, 0);
      });
    });
  });
}
