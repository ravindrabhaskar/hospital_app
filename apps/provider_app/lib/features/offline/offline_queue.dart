import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/key_value_store.dart';
import '../../models/home_visit.dart';
import '../visits/domain/visit_lifecycle.dart';

/// One provider action waiting to reach the server.
///
/// [id] doubles as the `Idempotency-Key`: it is generated once when the action
/// is created and reused for every replay, so the server can de-duplicate a
/// request whose response was lost.
class QueuedAction {
  QueuedAction({
    required this.id,
    required this.visitId,
    required this.type,
    required this.body,
    required this.createdAt,
    this.attempts = 0,
  });

  final String id;
  final String visitId;
  final VisitActionType type;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  int attempts;

  String get idempotencyKey => id;
  String get path => type == VisitActionType.photo ? '/records' : '/home-visits/$visitId/${type.pathSegment}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'visitId': visitId,
        'type': type.name,
        'body': body,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'attempts': attempts,
      };

  static QueuedAction? fromJson(Map<String, dynamic> json) {
    final type = VisitActionType.fromName((json['type'] ?? '').toString());
    if (type == null) return null;
    return QueuedAction(
      id: json['id'].toString(),
      visitId: json['visitId'].toString(),
      type: type,
      body: Map<String, dynamic>.from(json['body'] as Map? ?? const {}),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now().toUtc(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Sends an action to the server; throws [ApiException] on failure.
typedef ActionSender = Future<HomeVisit?> Function(QueuedAction action);

enum ActionOutcomeKind {
  /// Accepted by the server.
  synced,

  /// Still queued (offline / server unavailable).
  pending,

  /// 403/404: visit reassigned or access revoked. Dropped, cache purged.
  accessRevoked,

  /// Server refused it (validation, invalid transition…). Dropped.
  rejected,
}

class ActionOutcome {
  const ActionOutcome(this.kind, {this.visit, this.error});
  final ActionOutcomeKind kind;
  final HomeVisit? visit;
  final ApiException? error;
}

/// Ordered, persistent queue of provider actions.
///
/// Persisted as JSON inside [KeyValueStore] (flutter_secure_storage in the
/// app, so it is encrypted at rest). Replay is strictly FIFO; the first
/// retryable failure stops the flush so later actions never overtake earlier
/// ones (e.g. vitals before "verify identity").
class OfflineQueue extends ChangeNotifier {
  OfflineQueue({
    required this.store,
    required this.sender,
    this.onAccessRevoked,
    this.onRejected,
    this.onSynced,
  });

  final KeyValueStore store;
  ActionSender sender;

  /// Called after items for [visitId] were dropped because of 403/404.
  Future<void> Function(String visitId)? onAccessRevoked;

  /// Called for every action removed from the queue for any reason (synced,
  /// rejected, dropped, cleared), e.g. to delete a queued photo's file.
  Future<void> Function(QueuedAction action)? onRemoved;
  void Function(QueuedAction action, ApiException error)? onRejected;
  void Function(QueuedAction action, HomeVisit? visit)? onSynced;

  final List<QueuedAction> _items = [];
  bool _loaded = false;
  Future<Map<String, ActionOutcome>>? _flushing;

  List<QueuedAction> get items => List.unmodifiable(_items);
  int get pendingCount => _items.length;
  bool get isFlushing => _flushing != null;
  bool contains(String id) => _items.any((a) => a.id == id);
  List<QueuedAction> itemsForVisit(String visitId) =>
      _items.where((a) => a.visitId == visitId).toList();

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await store.read(StoreKeys.offlineQueue);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final e in decoded) {
          final action = QueuedAction.fromJson(Map<String, dynamic>.from(e as Map));
          if (action != null && !contains(action.id)) _items.add(action);
        }
      }
    } catch (_) {
      // Unreadable queue: start clean rather than crash.
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_items.isEmpty) {
      await store.delete(StoreKeys.offlineQueue);
    } else {
      await store.write(StoreKeys.offlineQueue, jsonEncode(_items.map((a) => a.toJson()).toList()));
    }
  }

  /// Adds an action. Enqueuing the same id twice is a no-op.
  Future<void> enqueue(QueuedAction action) async {
    await load();
    if (contains(action.id)) return;
    _items.add(action);
    await _persist();
    notifyListeners();
  }

  /// Replays queued actions in order. Concurrent calls share one run, so an
  /// action is never sent twice in parallel.
  Future<Map<String, ActionOutcome>> flush() {
    final running = _flushing;
    if (running != null) return running;
    final future = _doFlush();
    _flushing = future;
    return future.whenComplete(() => _flushing = null);
  }

  Future<Map<String, ActionOutcome>> _doFlush() async {
    await load();
    final outcomes = <String, ActionOutcome>{};
    while (_items.isNotEmpty) {
      final action = _items.first;
      action.attempts += 1;
      try {
        final visit = await sender(action);
        _items.removeAt(0);
        await _persist();
        await _removed(action);
        outcomes[action.id] = ActionOutcome(ActionOutcomeKind.synced, visit: visit);
        onSynced?.call(action, visit);
        notifyListeners();
      } on ApiException catch (e) {
        if (e.isAccessLost && action.type.isVisitScoped) {
          // Visit reassigned / access revoked: drop everything for this visit.
          final dropped = itemsForVisit(action.visitId);
          _items.removeWhere((a) => a.visitId == action.visitId);
          await _persist();
          for (final d in dropped) {
            await _removed(d);
            outcomes[d.id] = ActionOutcome(ActionOutcomeKind.accessRevoked, error: e);
          }
          notifyListeners();
          await onAccessRevoked?.call(action.visitId);
        } else if (e.isRetryable) {
          await _persist(); // keep attempt count
          for (final a in _items) {
            outcomes.putIfAbsent(a.id, () => const ActionOutcome(ActionOutcomeKind.pending));
          }
          break;
        } else {
          _items.removeAt(0);
          await _persist();
          await _removed(action);
          outcomes[action.id] = ActionOutcome(ActionOutcomeKind.rejected, error: e);
          notifyListeners();
          onRejected?.call(action, e);
        }
      } catch (e) {
        // Unexpected client error: treat as transient.
        for (final a in _items) {
          outcomes.putIfAbsent(a.id, () => const ActionOutcome(ActionOutcomeKind.pending));
        }
        break;
      }
    }
    return outcomes;
  }

  Future<void> _removed(QueuedAction action) async {
    try {
      await onRemoved?.call(action);
    } catch (_) {}
  }

  Future<void> clear() async {
    await load();
    for (final a in List.of(_items)) {
      await _removed(a);
    }
    _items.clear();
    await store.delete(StoreKeys.offlineQueue);
    notifyListeners();
  }
}
