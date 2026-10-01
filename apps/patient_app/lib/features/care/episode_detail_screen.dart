import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../state/data_providers.dart';
import '../prescriptions/prescription_widgets.dart';
import 'care_widgets.dart';

class EpisodeDetailScreen extends ConsumerWidget {
  const EpisodeDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.careEpisode)),
      body: AsyncView<CareEpisodeDetail>(
        value: ref.watch(episodeDetailProvider(id)),
        onRetry: () => ref.invalidate(episodeDetailProvider(id)),
        data: (d) {
          final e = d.episode;
          final exceptional = EpisodeStatus.exceptional.contains(e.status);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(episodeDetailProvider(id).future),
            child: ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                Text(e.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(e.concern, style: TextStyle(color: context.textMuted)),
                const SizedBox(height: Space.sm),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  StatusPill(
                      label: Labels.episodeStatus(l, e.status), color: Labels.episodeColor(e.status)),
                  if (e.priority != 'routine')
                    StatusPill(
                        label: e.priority == 'emergency' ? l.priorityEmergency : l.priorityUrgent,
                        color: AppColors.danger),
                  if (e.ownerName != null) StatusPill(label: l.careOwner(e.ownerName!), color: AppColors.skyFg),
                ]),
                if (e.nextAction != null && e.nextAction!.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  CcCard(
                    color: context.mintSurface,
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined, color: context.brand),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l.nextStep(e.nextAction!))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Space.md),
                OutlinedButton.icon(
                  key: const Key('episode-messages'),
                  onPressed: () => context.push('/care-episodes/${e.id}/messages'),
                  icon: const Icon(Icons.forum_outlined),
                  label: Text(l.messageCareTeam),
                ),
                const SizedBox(height: Space.lg),
                if (exceptional)
                  CcCard(
                    color: context.roseSurface,
                    borderColor: AppColors.danger,
                    child: Text(l.episodeExceptional(Labels.episodeStatus(l, e.status))),
                  )
                else
                  EpisodeStepper(status: e.status),
                if (d.appointments.isNotEmpty) ...[
                  SectionHeader(title: l.appointments),
                  for (final a in d.appointments) AppointmentCard(appointment: a),
                ],
                if (d.homeVisits.isNotEmpty) ...[
                  SectionHeader(title: l.homeVisits),
                  for (final h in d.homeVisits) HomeVisitCard(visit: h),
                ],
                PrescriptionsSection(careEpisodeId: e.id, hideWhenEmpty: true, title: l.prescriptions),
                if (d.carePlans.isNotEmpty) ...[
                  SectionHeader(title: l.carePlans),
                  for (final p in d.carePlans)
                    ListRowTile(
                      icon: Icons.assignment_outlined,
                      title: p.summary.isEmpty ? l.carePlan : p.summary,
                      subtitle: p.doctorName,
                      onTap: () => context.push('/care-plans/${p.id}'),
                    ),
                ],
                SectionHeader(title: l.timeline),
                if (d.events.isEmpty)
                  Text(l.noEvents, style: TextStyle(color: context.textMuted))
                else
                  EventTimeline(events: d.events),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EpisodeStepper extends StatelessWidget {
  const EpisodeStepper({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = EpisodeStatus.happyPath;
    final current = steps.indexOf(status);
    return CcCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Semantics(
              label: '${Labels.episodeStatus(l, steps[i])}${i == current ? ', ${l.current}' : ''}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= current ? context.brand : context.surface,
                          border: Border.all(color: i <= current ? context.brand : AppColors.border, width: 2),
                        ),
                        child: i < current
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : i == current
                                ? const Icon(Icons.circle, size: 8, color: Colors.white)
                                : null,
                      ),
                      if (i < steps.length - 1)
                        Container(width: 2, height: 18, color: i < current ? context.brand : AppColors.border),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 18 : 0),
                      child: Text(
                        Labels.episodeStatus(l, steps[i]),
                        style: TextStyle(
                          fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                          color: i <= current ? context.textStrong : context.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class EventTimeline extends StatelessWidget {
  const EventTimeline({super.key, required this.events});
  final List<EpisodeEvent> events;

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    ),
                    if (i < sorted.length - 1)
                      Expanded(child: Container(width: 2, color: AppColors.border)),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sorted[i].description, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          [
                            fmtDateTime(context, sorted[i].createdAt),
                            ?sorted[i].actorName,
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
