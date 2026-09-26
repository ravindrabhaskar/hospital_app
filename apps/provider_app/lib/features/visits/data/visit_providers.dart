import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/providers.dart';
import '../../../models/home_visit.dart';
import 'provider_repository.dart';

class VisitListResult {
  const VisitListResult(this.visits, {this.fromCache = false});
  final List<HomeVisit> visits;
  final bool fromCache;
}

class VisitDetailResult {
  const VisitDetailResult(this.visit, {this.fromCache = false});
  final HomeVisit visit;
  final bool fromCache;
}

/// Network first; falls back to the encrypted cache when offline.
final visitListProvider = FutureProvider.autoDispose.family<VisitListResult, VisitScope>((ref, scope) async {
  final repo = ref.watch(providerRepositoryProvider);
  final cache = ref.watch(visitCacheProvider);
  final actions = ref.watch(visitActionServiceProvider);
  await actions.queue.load();
  List<HomeVisit> visible(List<HomeVisit> list) => list
      // A visit rejected (possibly still queued) is no longer ours to show.
      .where((v) => v.status != VisitStatus.unassigned)
      .toList()
    ..sort((a, b) => (a.preferredStart ?? DateTime(0)).compareTo(b.preferredStart ?? DateTime(0)));
  try {
    final visits = (await repo.visits(scope)).map(actions.withPending).toList();
    await cache.saveList(scope.name, visits);
    final list = visible(visits);
    if (scope == VisitScope.completed) {
      return VisitListResult(list.reversed.toList());
    }
    return VisitListResult(list);
  } on ApiException catch (e) {
    if (e.isNetwork) {
      final cached = await cache.getList(scope.name);
      if (cached != null) return VisitListResult(visible(cached), fromCache: true);
    }
    rethrow;
  }
});

final visitDetailProvider = FutureProvider.autoDispose.family<VisitDetailResult, String>((ref, id) async {
  final repo = ref.watch(providerRepositoryProvider);
  final cache = ref.watch(visitCacheProvider);
  final actions = ref.watch(visitActionServiceProvider);
  await actions.queue.load();
  try {
    final visit = actions.withPending(await repo.visit(id));
    await cache.saveVisit(visit);
    return VisitDetailResult(visit);
  } on ApiException catch (e) {
    if (e.isNetwork) {
      final cached = await cache.getVisit(id);
      if (cached != null) return VisitDetailResult(cached, fromCache: true);
    }
    if (e.isAccessLost) {
      // Reassigned or access revoked: drop anything we hold for it.
      await cache.purgeVisit(id);
    }
    rethrow;
  }
});
