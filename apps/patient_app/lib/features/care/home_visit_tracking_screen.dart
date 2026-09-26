import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import 'care_widgets.dart';

class HomeVisitTrackingScreen extends ConsumerStatefulWidget {
  const HomeVisitTrackingScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<HomeVisitTrackingScreen> createState() => _State();
}

class _State extends ConsumerState<HomeVisitTrackingScreen> {
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Live tracking: refresh every 20s while the visit is in progress.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      final v = ref.read(homeVisitProvider(widget.id)).value;
      if (v == null || !v.isTerminal) ref.invalidate(homeVisitProvider(widget.id));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _refreshLists() {
    ref.invalidate(homeVisitProvider(widget.id));
    ref.invalidate(homeVisitsProvider('active'));
    ref.invalidate(homeVisitsProvider('past'));
    ref.invalidate(remindersTodayProvider);
  }

  Future<void> _cancel() async {
    final l = context.l10n;
    final reason = await askReason(context, title: l.cancelVisit);
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(homeVisitRepositoryProvider).cancel(widget.id, reason);
      _refreshLists();
      if (mounted) showSnack(context, l.visitCancelled);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.homeVisitTracking)),
      body: AsyncView<HomeVisit>(
        value: ref.watch(homeVisitProvider(widget.id)),
        onRetry: () => ref.invalidate(homeVisitProvider(widget.id)),
        data: (v) {
          final cancellable = const ['requested', 'unassigned', 'assigned', 'accepted'].contains(v.status);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(homeVisitProvider(widget.id).future),
            child: ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                if (v.visitCode != null && !v.isTerminal) VisitCodeCard(code: v.visitCode!),
                const SizedBox(height: Space.md),
                CcCard(
                  child: Row(
                    children: [
                      IconTile(icon: Labels.homeServiceIcon(v.serviceCode), accent: Accent.rose, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.serviceName, style: Theme.of(context).textTheme.titleSmall),
                            Text(
                                '${fmtDateTime(context, v.preferredStart)} – ${fmtTime(context, v.preferredEnd)}',
                                style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                          ],
                        ),
                      ),
                      StatusPill(label: Labels.visitStatus(l, v.status)),
                    ],
                  ),
                ),
                if (v.etaMinutes != null && v.status == 'en_route') ...[
                  const SizedBox(height: Space.md),
                  CcCard(
                    color: context.skySurface,
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_outlined, color: AppColors.skyFg),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l.etaMinutes(v.etaMinutes!),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (v.status == 'unassigned') ...[
                  const SizedBox(height: Space.md),
                  CcCard(color: context.peachSurface, child: Text(l.visitUnassigned)),
                ],
                if (v.provider != null) ...[
                  SectionHeader(title: l.yourCareProvider),
                  CcCard(
                    child: Row(
                      children: [
                        Avatar(name: v.provider!.name, url: v.provider!.photoUrl, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.provider!.name, style: Theme.of(context).textTheme.titleSmall),
                              Text(v.provider!.qualification,
                                  style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                              Text(v.provider!.phoneMasked, style: const TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const Icon(Icons.verified_user_outlined, color: AppColors.primaryLight),
                      ],
                    ),
                  ),
                ],
                SectionHeader(title: l.visitStatusTitle),
                VisitTimeline(visit: v),
                SectionHeader(title: l.address),
                CcCard(child: Text(v.address.oneLine)),
                if (v.summary != null && v.summary!.isNotEmpty) ...[
                  SectionHeader(title: l.visitSummary),
                  CcCard(child: Text(v.summary!)),
                ],
                if (v.vitals.isNotEmpty) ...[
                  SectionHeader(title: l.vitalsRecorded),
                  CcCard(
                    child: Column(
                      children: [
                        for (final m in v.vitals)
                          LabeledValue(
                              label: Labels.vitalType(l, m.type),
                              value: '${_num(m.value)} ${m.unit}'),
                      ],
                    ),
                  ),
                ],
                if (v.careEpisodeId != null) ...[
                  const SizedBox(height: Space.md),
                  ListRowTile(
                    icon: Icons.favorite_border,
                    title: l.viewCareEpisode,
                    onTap: () => context.push('/episodes/${v.careEpisodeId}'),
                  ),
                ],
                const SizedBox(height: Space.md),
                if (cancellable)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                    onPressed: _busy ? null : _cancel,
                    child: Text(l.cancelVisit),
                  ),
                if (v.status == 'requested' || v.status == 'unassigned') ...[
                  const SizedBox(height: Space.sm),
                  TextButton(
                    onPressed: () async {
                      final ok = await payOutstanding(context, ref, refId: v.id, title: v.serviceName);
                      if (ok) _refreshLists();
                    },
                    child: Text(l.payIfPending),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class VisitCodeCard extends StatelessWidget {
  const VisitCodeCard({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      label: l.visitCodeSemantic(code.split('').join(' ')),
      excludeSemantics: true,
      child: Container(
        key: const Key('visit-code'),
        padding: const EdgeInsets.all(Space.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
          borderRadius: BorderRadius.circular(Radii.card),
          boxShadow: Shadows.raised,
        ),
        child: Column(
          children: [
            Text(l.visitCode, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(code,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 14)),
            ),
            const SizedBox(height: 6),
            Text(l.visitCodeHint,
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class VisitTimeline extends StatelessWidget {
  const VisitTimeline({super.key, required this.visit});
  final HomeVisit visit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reached = {for (final t in visit.timeline) t.status: t};
    final flow = HomeVisit.flow;
    final currentIdx = flow.indexOf(visit.status);
    final extra = visit.timeline.where((t) => !flow.contains(t.status)).toList();
    return CcCard(
      child: Column(
        children: [
          for (var i = 0; i < flow.length; i++)
            _row(
              context,
              label: Labels.visitStatus(l, flow[i]),
              at: reached[flow[i]]?.at,
              note: reached[flow[i]]?.note,
              done: reached.containsKey(flow[i]) || (currentIdx >= 0 && i <= currentIdx),
              current: flow[i] == visit.status,
              last: i == flow.length - 1 && extra.isEmpty,
            ),
          for (var i = 0; i < extra.length; i++)
            _row(context,
                label: Labels.visitStatus(l, extra[i].status),
                at: extra[i].at,
                note: extra[i].note,
                done: true,
                current: extra[i].status == visit.status,
                last: i == extra.length - 1,
                danger: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context,
      {required String label,
      DateTime? at,
      String? note,
      required bool done,
      required bool current,
      required bool last,
      bool danger = false}) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : context.surface,
                  border: Border.all(color: done ? color : AppColors.border, width: 2),
                ),
                child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
              if (!last) Expanded(child: Container(width: 2, color: done ? color : AppColors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                          color: done ? context.textStrong : context.textMuted)),
                  if (at != null)
                    Text(fmtDateTime(context, at),
                        style: TextStyle(fontSize: 12, color: context.textMuted)),
                  if (note != null) Text(note, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
