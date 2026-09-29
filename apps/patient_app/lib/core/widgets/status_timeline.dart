import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../utils/format.dart';
import 'common.dart';

/// One row of a [StatusTimeline].
class TimelineStep {
  const TimelineStep({required this.label, this.at, required this.done, this.current = false, this.danger = false});
  final String label;
  final DateTime? at;
  final bool done;
  final bool current;
  final bool danger;
}

/// Builds the steps for a linear [flow] given the reached statuses: every
/// status up to the current one counts as done; statuses outside the flow
/// (cancelled, no_vehicle, …) are appended in red.
List<TimelineStep> buildTimelineSteps({
  required List<String> flow,
  required String current,
  required Map<String, DateTime> reached,
  required String Function(String status) label,
}) {
  final idx = flow.indexOf(current);
  return [
    for (var i = 0; i < flow.length; i++)
      TimelineStep(
        label: label(flow[i]),
        at: reached[flow[i]],
        done: reached.containsKey(flow[i]) || (idx >= 0 && i <= idx),
        current: flow[i] == current,
      ),
    for (final e in reached.entries)
      if (!flow.contains(e.key))
        TimelineStep(label: label(e.key), at: e.value, done: true, current: e.key == current, danger: true),
    if (!flow.contains(current) && !reached.containsKey(current))
      TimelineStep(label: label(current), done: true, current: true, danger: true),
  ];
}

/// Vertical status timeline (same look as the home-visit tracker).
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.steps});
  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return CcCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) _row(context, steps[i], last: i == steps.length - 1),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, TimelineStep s, {required bool last}) {
    final color = s.danger ? AppColors.danger : AppColors.primary;
    return Semantics(
      label: [s.label, if (s.at != null) fmtDateTime(context, s.at!)].join(', '),
      selected: s.current,
      excludeSemantics: true,
      child: IntrinsicHeight(
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
                    color: s.done ? color : context.surface,
                    border: Border.all(color: s.done ? color : context.borderColor, width: 2),
                  ),
                  child: s.done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                ),
                if (!last) Expanded(child: Container(width: 2, color: s.done ? color : context.borderColor)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.label,
                        style: TextStyle(
                            fontWeight: s.current ? FontWeight.w700 : FontWeight.w500,
                            color: s.done ? context.textStrong : context.textMuted)),
                    if (s.at != null)
                      Text(fmtDateTime(context, s.at!), style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small tinted notice box (info / warning / danger).
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.icon, required this.text, this.color = AppColors.peachFg, this.title, this.action});
  final IconData icon;
  final String text;
  final String? title;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(text),
                if (action != null) Padding(padding: const EdgeInsets.only(top: 4), child: action!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
