import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/load_more.dart';
import '../../core/widgets/state_views.dart';
import '../../models/json.dart';
import '../../models/records.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  (IconData, Accent) _style(String kind) => switch (kind) {
        'record' => (Icons.description_outlined, Accent.sky),
        'appointment' => (Icons.event_outlined, Accent.teal),
        'home_visit' => (Icons.home_outlined, Accent.rose),
        'vital' => (Icons.monitor_heart_outlined, Accent.peach),
        'care_plan' => (Icons.assignment_outlined, Accent.lavender),
        'medication' => (Icons.medication_outlined, Accent.peach),
        _ => (Icons.favorite_border, Accent.teal),
      };

  String? _route(TimelineItem t) => switch (t.kind) {
        'record' => '/records/${t.refId}',
        'appointment' => '/appointments/${t.refId}',
        'home_visit' => '/home-visits/${t.refId}',
        'care_plan' => '/care-plans/${t.refId}',
        'episode' => '/episodes/${t.refId}',
        'vital' => '/vitals',
        'medication' => '/medications',
        _ => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.healthTimeline)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(timelineProvider.future),
        child: AsyncView<Page<TimelineItem>>(
          value: ref.watch(timelineProvider),
          onRetry: () => ref.invalidate(timelineProvider),
          isEmpty: (p) => p.items.isEmpty,
          empty: EmptyStateView(icon: Icons.timeline, title: l.timelineEmpty),
          data: (page) => PagedItems<TimelineItem>(
            first: page.items,
            nextCursor: page.nextCursor,
            fetch: (cursor) async => ref
                .read(recordsRepositoryProvider)
                .timelinePage((await ref.read(activePatientProvider.future)).id, cursor: cursor),
            builder: (context, items, footer) {
            String? lastDay;
            final children = <Widget>[];
            for (final t in items) {
              final day = fmtDate(context, t.occurredAt);
              if (day != lastDay) {
                children.add(Padding(
                  padding: const EdgeInsets.only(top: Space.md, bottom: Space.sm),
                  child: Text(day, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                ));
                lastDay = day;
              }
              final (icon, accent) = _style(t.kind);
              final route = _route(t);
              children.add(ListRowTile(
                icon: icon,
                accent: accent,
                title: t.title,
                subtitle: [
                  fmtTime(context, t.occurredAt),
                  ?t.subtitle,
                  if (t.source != null) Labels.provenance(l, t.source),
                ].join(' · '),
                onTap: route == null ? null : () => context.push(route),
              ));
            }
            if (footer != null) children.add(footer);
            return ListView(padding: const EdgeInsets.all(Space.screen), children: children);
            },
          ),
        ),
      ),
    );
  }
}
