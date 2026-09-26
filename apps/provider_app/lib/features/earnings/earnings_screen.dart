import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/earnings.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// First and last day of [month] as `YYYY-MM-DD` (the `from`/`to` query).
({String from, String to}) monthRange(DateTime month) {
  String d(DateTime x) => DateFormat('yyyy-MM-dd').format(x);
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  return (from: d(first), to: d(last));
}

/// Earnings for one month, keyed by the first day of that month.
final earningsProvider = FutureProvider.autoDispose.family<Earnings, DateTime>((ref, month) {
  final r = monthRange(month);
  return ref.watch(providerRepositoryProvider).earnings(from: r.from, to: r.to);
});

/// Contract §32: month selector, summary tiles and per-service lines.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key, this.now});

  /// Injectable "today" for tests.
  final DateTime? now;

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
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
    final async = ref.watch(earningsProvider(_month));
    final isCurrent = _month == _current;
    return Scaffold(
      appBar: AppBar(title: Text(l.earnTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  key: const Key('earnPrev'),
                  tooltip: l.earnPrevMonth,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM(locale).format(_month),
                    key: const Key('earnMonth'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('earnNext'),
                  tooltip: l.earnNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isCurrent ? null : () => _shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(earningsProvider(_month).future),
              child: async.when(
                loading: () => ListView(children: const [SizedBox(height: 200, child: LoadingView())]),
                error: (e, _) => ListView(children: [
                  SizedBox(
                    height: 320,
                    child: ErrorView(
                      message: errorMessage(l, e),
                      onRetry: () => ref.invalidate(earningsProvider(_month)),
                    ),
                  ),
                ]),
                data: (e) => EarningsView(earnings: e),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pure rendering of an [Earnings] payload (always scrollable, for
/// pull-to-refresh).
class EarningsView extends StatelessWidget {
  const EarningsView({super.key, required this.earnings});
  final Earnings earnings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = earnings;
    final locale = Localizations.localeOf(context).toString();
    String date(String iso) {
      final d = DateTime.tryParse(iso);
      return d == null ? iso : DateFormat.MMMd(locale).format(d);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        _Tile(
          key: const Key('earn.payable'),
          label: l.earnPayable,
          value: formatRupees(e.payable),
          highlight: true,
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.1,
          children: [
            _Tile(key: const Key('earn.completed'), label: l.earnCompleted, value: '${e.completedServices}'),
            _Tile(key: const Key('earn.gross'), label: l.earnGross, value: formatRupees(e.grossAmount)),
            _Tile(key: const Key('earn.fee'), label: l.earnPlatformFee, value: '− ${formatRupees(e.platformFee)}'),
            _Tile(key: const Key('earn.refunds'), label: l.earnRefunds, value: '− ${formatRupees(e.refunds)}'),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l.earnLines,
          child: e.lines.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.earnEmpty, key: const Key('earnEmpty'), textAlign: TextAlign.center),
                )
              : Column(
                  children: [
                    for (final line in e.lines)
                      ListTile(
                        key: Key('earnLine.${line.refId}'),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(line.refType == 'home_visit' ? Icons.home_outlined : Icons.event_outlined),
                        title: Text(line.description.isEmpty
                            ? (line.refType == 'home_visit' ? l.earnRefHomeVisit : l.earnRefAppointment)
                            : line.description),
                        subtitle: Text(
                            '${date(line.date)} · ${l.earnLineDetail(formatRupees(line.platformFee), formatRupees(line.payable))}'),
                        trailing: Text(formatRupees(line.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Text(l.earnNote, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primary : AppColors.mint50,
          borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: highlight ? Colors.white70 : AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                    color: highlight ? Colors.white : AppColors.textPrimary,
                    fontSize: highlight ? 26 : 18,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
