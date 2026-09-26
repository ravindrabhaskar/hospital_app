import 'dart:convert';

import 'package:care_companion_provider/core/api/api_exception.dart';
import 'package:care_companion_provider/core/connectivity.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/features/offline/offline_queue.dart';
import 'package:care_companion_provider/features/offline/visit_action_service.dart';
import 'package:care_companion_provider/features/offline/visit_cache.dart';
import 'package:care_companion_provider/features/visits/domain/visit_lifecycle.dart';
import 'package:care_companion_provider/models/home_visit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Simulates the API's idempotency behaviour: a repeated Idempotency-Key
/// returns the stored response without re-executing the side effect.
class FakeServer {
  bool reachable = true;

  /// Status to return for every request (e.g. 403 after reassignment).
  int? failWith;

  /// Execute the request but drop the response (lost ACK).
  bool loseNextResponse = false;

  final List<String> receivedKeys = [];
  final List<String> executedKeys = [];
  final Map<String, HomeVisit> _responses = {};

  Future<HomeVisit?> send(QueuedAction a) async {
    if (!reachable) throw const ApiException.network();
    receivedKeys.add(a.idempotencyKey);
    if (failWith != null) {
      throw ApiException(statusCode: failWith!, code: failWith == 403 ? 'FORBIDDEN' : 'X', message: 'fail');
    }
    final stored = _responses[a.idempotencyKey];
    if (stored != null) return stored;
    executedKeys.add(a.idempotencyKey);
    final status = VisitLifecycle.statusAfter(a.type) ?? VisitStatus.inProgress;
    final response = visit(id: a.visitId, status: status);
    _responses[a.idempotencyKey] = response;
    if (loseNextResponse) {
      loseNextResponse = false;
      throw const ApiException.network('connection reset');
    }
    return response;
  }
}

QueuedAction action(String id, {String visitId = 'visit-1', VisitActionType type = VisitActionType.vitals}) =>
    QueuedAction(
      id: id,
      visitId: visitId,
      type: type,
      body: type == VisitActionType.vitals
          ? {
              'measurements': [
                {'type': 'pulse', 'value': 72, 'unit': 'bpm', 'measuredAt': '2026-09-26T09:40:00.000Z'},
              ],
            }
          : <String, dynamic>{},
      createdAt: DateTime.utc(2026, 9, 26, 9, 40),
    );

void main() {
  group('OfflineQueue', () {
    late MemoryKeyValueStore store;
    late FakeServer server;
    late OfflineQueue queue;

    setUp(() {
      store = MemoryKeyValueStore();
      server = FakeServer();
      queue = OfflineQueue(store: store, sender: server.send);
    });

    test('enqueue offline -> replay once with the same idempotency key -> no duplicates', () async {
      server.reachable = false;
      await queue.enqueue(action('key-1'));

      final offline = await queue.flush();
      expect(offline['key-1']!.kind, ActionOutcomeKind.pending);
      expect(queue.pendingCount, 1);
      expect(server.receivedKeys, isEmpty);

      server.reachable = true;
      final results = await Future.wait([queue.flush(), queue.flush()]); // concurrent flushes share one run
      expect(results.first['key-1']!.kind, ActionOutcomeKind.synced);
      expect(queue.pendingCount, 0);

      await queue.flush(); // nothing left to send
      expect(server.receivedKeys, ['key-1']);
      expect(server.executedKeys, ['key-1']);
    });

    test('lost response is replayed with the same key and executed only once', () async {
      server.loseNextResponse = true;
      await queue.enqueue(action('key-lost'));

      final first = await queue.flush();
      expect(first['key-lost']!.kind, ActionOutcomeKind.pending);
      expect(queue.pendingCount, 1, reason: 'kept for replay');

      final second = await queue.flush();
      expect(second['key-lost']!.kind, ActionOutcomeKind.synced);
      expect(server.receivedKeys, ['key-lost', 'key-lost'], reason: 'same Idempotency-Key reused');
      expect(server.executedKeys, ['key-lost'], reason: 'server-side effect happened once');
    });

    test('enqueuing the same action id twice is a no-op', () async {
      server.reachable = false;
      await queue.enqueue(action('dup'));
      await queue.enqueue(action('dup'));
      expect(queue.pendingCount, 1);
    });

    test('queue is persisted (as JSON) and restored with the same keys', () async {
      server.reachable = false;
      await queue.enqueue(action('a1', type: VisitActionType.arrived));
      await queue.enqueue(action('a2'));

      final raw = store.data[StoreKeys.offlineQueue]!;
      expect((jsonDecode(raw) as List).length, 2);

      final restored = OfflineQueue(store: store, sender: server.send);
      await restored.load();
      expect(restored.items.map((a) => a.id), ['a1', 'a2']);
      expect(restored.items.first.type, VisitActionType.arrived);

      server.reachable = true;
      await restored.flush();
      expect(server.receivedKeys, ['a1', 'a2'], reason: 'FIFO order preserved');
      expect(store.data.containsKey(StoreKeys.offlineQueue), isFalse);
    });

    test('a retryable failure stops the flush so later actions never overtake', () async {
      await queue.enqueue(action('first', type: VisitActionType.verifyIdentity));
      await queue.enqueue(action('second'));
      server.failWith = 503;
      await queue.flush();
      expect(server.receivedKeys, ['first']);
      expect(queue.items.map((a) => a.id), ['first', 'second']);
    });

    test('non-retryable rejection (409) drops only that action and continues', () async {
      final rejected = <String>[];
      queue.onRejected = (a, e) => rejected.add(a.id);
      await queue.enqueue(action('bad', type: VisitActionType.accept));
      server.failWith = 409;
      await queue.flush();
      expect(rejected, ['bad']);
      expect(queue.pendingCount, 0);
    });
  });

  group('403/404 during replay (visit reassigned / access revoked)', () {
    late MemoryKeyValueStore store;
    late FakeServer server;
    late OfflineQueue queue;
    late VisitCache cache;
    late FakeConnectivityService connectivity;
    late VisitActionService service;

    setUp(() {
      store = MemoryKeyValueStore();
      server = FakeServer();
      queue = OfflineQueue(store: store, sender: server.send);
      cache = VisitCache(store);
      connectivity = FakeConnectivityService(online: false);
      service = VisitActionService(queue: queue, cache: cache, connectivity: connectivity);
    });

    tearDown(() => service.dispose());

    test('403 drops all queued items for the visit, purges cached patient data and notifies', () async {
      final v = visit(status: VisitStatus.inProgress);
      await cache.saveList('today', [v, visit(id: 'visit-2', status: VisitStatus.accepted)]);

      // Offline: vitals + observations queued for visit-1, one action for visit-2.
      final vitals = await service.perform(v, VisitActionType.vitals, action('x').body);
      expect(vitals.kind, ActionOutcomeKind.pending);
      await service.perform(vitals.visit!, VisitActionType.observations, {
        'notes': 'Alert',
        'checklist': {'alert_and_oriented': true},
      });
      await service.perform(visit(id: 'visit-2', status: VisitStatus.accepted), VisitActionType.enRoute,
          {'etaMinutes': 15});
      expect(queue.pendingCount, 3);
      expect((await cache.getVisit('visit-1'))!.vitals, hasLength(1), reason: 'optimistic local copy');

      final events = <SyncEvent>[];
      final sub = service.events.listen(events.add);

      // Back online, but visit-1 has been reassigned.
      server.failWith = 403;
      connectivity.online = true;
      await service.syncNow();
      await Future<void>.delayed(Duration.zero);

      expect(queue.itemsForVisit('visit-1'), isEmpty);
      expect(await cache.getVisit('visit-1'), isNull, reason: 'cached PHI purged');
      expect((await cache.getList('today'))!.map((e) => e.id), isNot(contains('visit-1')));
      expect(events.where((e) => e.kind == SyncEventKind.accessRevoked).map((e) => e.visitId), contains('visit-1'));
      await sub.cancel();
    });

    test('online action returns synced and applies server copy; offline action advances optimistically', () async {
      final v = visit(status: VisitStatus.assigned);
      final queued = await service.perform(v, VisitActionType.accept, const {});
      expect(queued.kind, ActionOutcomeKind.pending);
      expect(queued.visit!.status, VisitStatus.accepted);
      expect(queued.visit!.pendingSync, isTrue);
      expect(server.receivedKeys, isEmpty);

      connectivity.online = true;
      final synced = await service.perform(queued.visit!, VisitActionType.enRoute, {'etaMinutes': 10});
      expect(synced.kind, ActionOutcomeKind.synced);
      expect(server.executedKeys, hasLength(2), reason: 'accept replayed first, then en-route');
      expect(queue.pendingCount, 0);
    });
  });

  group('VisitCache retention', () {
    test('completed visits older than 24h are purged; recent ones kept; clear wipes all', () async {
      final now = DateTime.utc(2026, 9, 26, 12);
      final store = MemoryKeyValueStore();
      final cache = VisitCache(store, clock: () => now);
      await cache.saveVisit(visit(id: 'old', status: VisitStatus.completed, completedAt: now.subtract(const Duration(hours: 25))));
      await cache.saveVisit(visit(id: 'recent', status: VisitStatus.completed, completedAt: now.subtract(const Duration(hours: 2))));
      await cache.saveVisit(visit(id: 'active', status: VisitStatus.inProgress));

      await cache.purgeExpired();
      expect(await cache.getVisit('old'), isNull);
      expect(await cache.getVisit('recent'), isNotNull);
      expect(await cache.getVisit('active'), isNotNull);

      await cache.clear();
      expect(store.data.containsKey(StoreKeys.visitCache), isFalse);
      expect(await cache.getVisit('active'), isNull);
    });
  });
}
