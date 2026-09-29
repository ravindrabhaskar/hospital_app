import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/care_plans.dart' show ymd;
import '../../models/field_ops.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// `GET /provider/route?date=YYYY-MM-DD` (§48).
final routePlanProvider = FutureProvider.autoDispose.family<RoutePlan, String>((ref, date) {
  return ref.watch(fieldRepositoryProvider).route(DateTime.parse(date));
});

/// Today's route as a map-free list: ordered stops, windows, distances, ETAs
/// and total km, with one "Start navigation" hand-off to Google Maps.
class RouteView extends ConsumerWidget {
  const RouteView({super.key, this.now});

  /// Injectable "today" for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final date = ymd(now ?? ref.watch(clockProvider)());
    final async = ref.watch(routePlanProvider(date));
    Future<void> refresh() => ref.refresh(routePlanProvider(date).future).then((_) {}, onError: (_) {});

    return RefreshIndicator(
      onRefresh: refresh,
      child: async.when(
        loading: () => ListView(children: const [SizedBox(height: 200, child: LoadingView())]),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 320, child: ErrorView(message: errorMessage(l, e), onRetry: refresh)),
          ],
        ),
        data: (plan) => RouteList(plan: plan),
      ),
    );
  }
}

/// Pure rendering of a [RoutePlan] (always scrollable, for pull-to-refresh).
class RouteList extends StatelessWidget {
  const RouteList({super.key, required this.plan});
  final RoutePlan plan;

  Future<void> _navigate(BuildContext context) async {
    final uri = buildMapsRouteUri(plan.stops, originLat: plan.startLat, originLng: plan.startLng);
    await openExternal(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stops = plan.ordered;
    if (stops.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [const SizedBox(height: 40), EmptyView(message: l.routeEmpty, icon: Icons.route_outlined)],
      );
    }
    final km = NumberFormat('#,##0.0', Localizations.localeOf(context).toString());
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 24),
      children: [
        SectionCard(
          color: AppColors.mint50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: l.routeSummary(stops.length, km.format(plan.totalKm)),
                excludeSemantics: true,
                child: Text(
                  l.routeSummary(stops.length, km.format(plan.totalKm)),
                  key: const Key('routeSummary'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(plan.hasStart ? l.routeFromLastLocation : l.routeFromCurrentLocation,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('routeNavigate'),
                onPressed: () => _navigate(context),
                icon: const Icon(Icons.navigation_outlined),
                label: Text(l.routeStartNavigation),
              ),
              if (stops.length > maxMapsStops) ...[
                const SizedBox(height: 8),
                Text(l.routeTooManyStops(maxMapsStops),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < stops.length; i++) ...[
          RouteStopTile(stop: stops[i], index: i + 1, isFirst: i == 0, isLast: i == stops.length - 1),
        ],
      ],
    );
  }
}

class RouteStopTile extends StatelessWidget {
  const RouteStopTile({super.key, required this.stop, required this.index, this.isFirst = false, this.isLast = false});
  final RouteStop stop;
  final int index;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final km = NumberFormat('#,##0.0', Localizations.localeOf(context).toString());
    final window = formatWindow(context, stop.windowStart, stop.windowEnd, withDate: false);
    final distance = stop.distanceFromPrevKm == null
        ? null
        : (isFirst ? l.routeFromStart(km.format(stop.distanceFromPrevKm)) : l.routeFromPrev(km.format(stop.distanceFromPrevKm)));
    final eta = stop.etaAt == null ? null : l.routeEta(formatTime(context, stop.etaAt));
    final details = [?distance, ?eta].join(' · ');
    return IntrinsicHeight(
      key: Key('routeStop.${stop.visitId}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 12),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Semantics(
                  button: true,
                  label: l.routeStopLabel(index, stop.serviceName, window, details),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: stop.visitId.isEmpty ? null : () => context.push('/visits/${stop.visitId}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.serviceName, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(window, style: const TextStyle(color: AppColors.textSecondary)),
                          ]),
                          if (stop.addressText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(stop.addressText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.textSecondary)),
                                ),
                              ],
                            ),
                          ],
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(details,
                                style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
