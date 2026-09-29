import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/api/api_exception.dart';
import '../../core/connectivity.dart';
import '../../models/field_ops.dart';
import '../../models/home_visit.dart';
import '../visits/data/photo_store.dart';
import '../visits/domain/visit_lifecycle.dart';
import 'offline_queue.dart';
import 'visit_cache.dart';

enum SyncEventKind { synced, accessRevoked, rejected }

/// Background sync notifications for the UI (snackbars, list refresh).
class SyncEvent {
  const SyncEvent(this.kind, {required this.visitId, this.type, this.error, this.foreground = false});
  final SyncEventKind kind;
  final String visitId;

  /// The action involved (null for a visit-wide access revocation).
  final VisitActionType? type;
  final ApiException? error;

  /// True when the screen that triggered the action handles the message itself.
  final bool foreground;
}

/// Single entry point for every provider visit action.
///
/// Every action goes through the [OfflineQueue] (even when online) so ordering
/// and idempotency are identical in both modes:
/// 1. enqueue with a fresh, stable Idempotency-Key,
/// 2. apply the action optimistically to the encrypted cache,
/// 3. flush immediately if the device looks online.
class VisitActionService {
  VisitActionService({
    required this.queue,
    required this.cache,
    required this.connectivity,
    this.photos,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now {
    queue.onSynced = _handleSynced;
    queue.onAccessRevoked = _handleAccessRevoked;
    queue.onRejected = _handleRejected;
    queue.onRemoved = _handleRemoved;
  }

  final OfflineQueue queue;
  final VisitCache cache;
  final ConnectivityService connectivity;
  final PhotoFileStore? photos;
  final Uuid _uuid;
  final DateTime Function() _clock;

  final _events = StreamController<SyncEvent>.broadcast();
  final Set<String> _foreground = {};
  StreamSubscription<bool>? _connectivitySub;
  Timer? _retryTimer;

  Stream<SyncEvent> get events => _events.stream;

  /// Starts replaying on reconnect (and periodically while items are pending,
  /// in case the network is up but the API was briefly unavailable).
  void startAutoSync() {
    _connectivitySub ??= connectivity.onStatusChange.listen((online) {
      if (online) unawaited(syncNow());
    });
    _retryTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (queue.pendingCount > 0) unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  void stopAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> syncNow() async {
    await queue.load();
    if (queue.pendingCount == 0) return;
    if (!await connectivity.isOnline()) return;
    await queue.flush();
  }

  /// Performs (or queues) an action. The returned outcome's `visit` is the
  /// best known copy: the server's on success, the optimistic one if queued.
  Future<ActionOutcome> perform(HomeVisit visit, VisitActionType type, Map<String, dynamic> body) async {
    final now = _clock().toUtc();
    final action = QueuedAction(
      id: _uuid.v4(),
      visitId: visit.id,
      type: type,
      body: body,
      createdAt: now,
    );
    _foreground.add(action.id);
    try {
      await queue.enqueue(action);
      final optimistic = VisitLifecycle.applyOptimistic(visit, type, body, now);
      await cache.saveVisit(optimistic);

      if (!await connectivity.isOnline()) {
        return ActionOutcome(ActionOutcomeKind.pending, visit: optimistic);
      }
      final outcomes = await queue.flush();
      final outcome = outcomes[action.id];
      if (outcome == null || outcome.kind == ActionOutcomeKind.pending) {
        return ActionOutcome(ActionOutcomeKind.pending, visit: optimistic);
      }
      if (outcome.kind == ActionOutcomeKind.rejected) {
        // Roll the optimistic change back.
        await cache.saveVisit(visit);
        return ActionOutcome(ActionOutcomeKind.rejected, visit: visit, error: outcome.error);
      }
      if (outcome.kind == ActionOutcomeKind.synced) {
        final synced = outcome.visit ?? optimistic.copyWith(pendingSync: false);
        return ActionOutcome(ActionOutcomeKind.synced, visit: synced);
      }
      return outcome;
    } finally {
      _foreground.remove(action.id);
    }
  }

  /// Queues a consented visit photo (`POST /records`). The captured file is
  /// first copied into private storage so it survives until replay; the
  /// queued item keeps the same Idempotency-Key for every attempt.
  Future<ActionOutcome> addPhoto(HomeVisit visit, String capturedPath) async {
    final store = photos;
    if (store == null) throw StateError('No photo store configured');
    final path = await store.persist(capturedPath);
    return perform(
      visit,
      VisitActionType.photo,
      photoUploadBody(filePath: path, patientId: visit.patientId, takenAt: _clock()),
    );
  }

  /// Queues `POST /provider/supplies/usage` (§48) for this visit, with the
  /// same Idempotency-Key for every replay. Zero quantities are left out.
  Future<ActionOutcome> recordSuppliesUsage(HomeVisit visit, Map<String, int> quantities) =>
      perform(visit, VisitActionType.suppliesUsage, suppliesUsageBody(visit.id, quantities));

  /// Re-applies still-queued actions on top of a fresh server copy so the UI
  /// doesn't jump backwards while replays are pending.
  HomeVisit withPending(HomeVisit serverVisit) {
    var v = serverVisit;
    for (final a in queue.itemsForVisit(serverVisit.id)) {
      v = VisitLifecycle.applyOptimistic(v, a.type, a.body, a.createdAt);
    }
    return v;
  }

  Future<void> _handleSynced(QueuedAction action, HomeVisit? visit) async {
    if (visit != null) {
      await cache.saveVisit(withPending(visit.copyWith(pendingSync: false)));
    }
    if (action.type == VisitActionType.reject) {
      await cache.purgeVisit(action.visitId);
    }
    _emit(SyncEvent(
      SyncEventKind.synced,
      visitId: action.visitId,
      type: action.type,
      foreground: _foreground.contains(action.id),
    ));
  }

  Future<void> _handleAccessRevoked(String visitId) async {
    await cache.purgeVisit(visitId);
    _emit(SyncEvent(SyncEventKind.accessRevoked, visitId: visitId));
  }

  void _handleRejected(QueuedAction action, ApiException error) {
    _emit(SyncEvent(
      SyncEventKind.rejected,
      visitId: action.visitId,
      type: action.type,
      error: error,
      foreground: _foreground.contains(action.id),
    ));
  }

  Future<void> _handleRemoved(QueuedAction action) async {
    if (action.type != VisitActionType.photo) return;
    final path = action.body['filePath']?.toString();
    if (path != null && path.isNotEmpty) await photos?.delete(path);
  }

  void _emit(SyncEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void dispose() {
    stopAutoSync();
    _events.close();
  }
}
