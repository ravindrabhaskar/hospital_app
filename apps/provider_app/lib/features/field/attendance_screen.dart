import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/field_ops.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import 'attendance_controller.dart';

/// Attendance for one month, keyed by the first day of that month.
final attendanceMonthProvider = FutureProvider.autoDispose.family<AttendanceMonth, DateTime>((ref, month) {
  return ref.watch(fieldRepositoryProvider).attendanceMonth(monthKey(month));
});

/// Home card: today's check-in / check-out (§48) plus links to the attendance
/// history and supplies.
class AttendanceCard extends ConsumerStatefulWidget {
  const AttendanceCard({super.key});

  @override
  ConsumerState<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends ConsumerState<AttendanceCard> {
  @override
  void initState() {
    super.initState();
    ref.read(attendanceControllerProvider).load();
  }

  Future<void> _act(AttendanceController c, bool checkIn) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (checkIn) {
        await c.checkIn();
      } else {
        await c.checkOut();
      }
      final text = checkIn ? l.attCheckedInToast : l.attCheckedOutToast;
      messenger.showSnackBar(SnackBar(
        content: Text(c.lastHadLocation == false ? '$text ${l.attNoLocation}' : text),
      ));
      ref.invalidate(attendanceMonthProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l, e)), backgroundColor: AppColors.dangerDeep));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = ref.watch(attendanceControllerProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final (String title, String? subtitle) = switch (c.status) {
          AttendanceStatus.unknown => (l.attUnknown, null),
          AttendanceStatus.notCheckedIn => (l.attNotCheckedIn, l.attNotCheckedInHint),
          AttendanceStatus.checkedIn => (l.attCheckedInAt(formatTime(context, c.checkInAt)), null),
          AttendanceStatus.checkedOut => (
              l.attCheckedOutAt(formatTime(context, c.checkOutAt)),
              l.attCheckedInAt(formatTime(context, c.checkInAt))
            ),
        };
        final checkIn = c.status != AttendanceStatus.checkedIn;
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(c.status == AttendanceStatus.checkedIn ? Icons.badge : Icons.badge_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, key: const Key('attStatus'), style: Theme.of(context).textTheme.titleSmall),
                          if (subtitle != null)
                            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (c.busy)
                      const SizedBox(
                          width: 40,
                          height: 40,
                          child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                    else if (checkIn)
                      FilledButton(
                        key: const Key('attCheckIn'),
                        style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                        onPressed: () => _act(c, true),
                        child: Text(l.attCheckIn),
                      )
                    else
                      OutlinedButton(
                        key: const Key('attCheckOut'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44)),
                        onPressed: () => _act(c, false),
                        child: Text(l.attCheckOut),
                      ),
                  ],
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      key: const Key('attHistoryLink'),
                      onPressed: () => context.push('/attendance'),
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text(l.attTitle),
                    ),
                    TextButton.icon(
                      key: const Key('suppliesLink'),
                      onPressed: () => context.push('/supplies'),
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: Text(l.supTitle),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Monthly attendance: hours and visits per day (§48).
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, this.now});
  final DateTime? now;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late final DateTime _current = () {
    final n = widget.now ?? DateTime.now();
    return DateTime(n.year, n.month);
  }();
  late DateTime _month = _current;

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final async = ref.watch(attendanceMonthProvider(_month));
    return Scaffold(
      appBar: AppBar(title: Text(l.attTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  key: const Key('attPrev'),
                  tooltip: l.earnPrevMonth,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: Text(DateFormat.yMMMM(locale).format(_month),
                      key: const Key('attMonth'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  key: const Key('attNext'),
                  tooltip: l.earnNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _month == _current ? null : () => _shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(attendanceMonthProvider(_month).future),
              child: async.when(
                loading: () => ListView(children: const [SizedBox(height: 200, child: LoadingView())]),
                error: (e, _) => ListView(children: [
                  SizedBox(
                    height: 320,
                    child: ErrorView(
                        message: errorMessage(l, e), onRetry: () => ref.invalidate(attendanceMonthProvider(_month))),
                  ),
                ]),
                data: (m) => AttendanceMonthView(month: m),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AttendanceMonthView extends StatelessWidget {
  const AttendanceMonthView({super.key, required this.month});
  final AttendanceMonth month;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final hours = NumberFormat('#,##0.#', locale);
    String day(String iso) {
      final d = DateTime.tryParse(iso);
      return d == null ? iso : DateFormat.MMMEd(locale).format(d);
    }

    Widget tile(Key key, String label, String value) => Expanded(
          child: Semantics(
            label: '$label: $value',
            excludeSemantics: true,
            child: Container(
              key: key,
              padding: const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(color: AppColors.mint50, borderRadius: BorderRadius.circular(AppSpacing.tileRadius)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Row(children: [
          tile(const Key('att.days'), l.attDaysPresent, '${month.daysPresent}'),
          const SizedBox(width: 8),
          tile(const Key('att.hours'), l.attHours, hours.format(month.totalHours)),
          const SizedBox(width: 8),
          tile(const Key('att.visits'), l.attVisits, '${month.totalVisits}'),
        ]),
        const SizedBox(height: 12),
        SectionCard(
          title: l.attDaily,
          child: month.days.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.attEmpty, key: const Key('attEmpty'), textAlign: TextAlign.center),
                )
              : Column(
                  children: [
                    for (final d in month.days)
                      ListTile(
                        key: Key('attDay.${d.date}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(day(d.date)),
                        subtitle: Text(d.checkInAt == null
                            ? l.attAbsent
                            : '${formatTime(context, d.checkInAt)} – '
                                '${d.checkOutAt == null ? l.attOpen : formatTime(context, d.checkOutAt)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(l.attHoursShort(hours.format(d.hours)),
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(l.attVisitsCount(d.visits),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
