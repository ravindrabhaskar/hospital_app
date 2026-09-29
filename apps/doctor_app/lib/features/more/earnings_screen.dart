import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/doctor.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

final earningsProvider = FutureProvider.autoDispose.family<Earnings, DateTime>(
  (ref, month) => ref.watch(clinicianRepositoryProvider).earnings(month),
);

/// Monthly earnings (contract §32): completed and paid services only.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final now = ref.read(clockProvider)();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    return Scaffold(
      appBar: AppBar(title: Text(l.earningsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: l.previousMonth,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
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
                  tooltip: l.nextMonth,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isCurrent ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody<Earnings>(
              value: ref.watch(earningsProvider(_month)),
              onRetry: () => ref.invalidate(earningsProvider(_month)),
              data: (e) => ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.mint50, AppColors.mint100]),
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.earnPayable, style: const TextStyle(color: AppColors.textSecondary)),
                        Text(
                          formatRupees(e.payable),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primaryDark),
                        ),
                        Text(l.earnServices(e.completedServices)),
                      ],
                    ),
                  ),
                  gap12,
                  SectionCard(
                    child: Column(
                      children: [
                        LabeledValue(label: l.earnGross, value: formatRupees(e.grossAmount)),
                        LabeledValue(label: l.earnPlatformFee, value: formatRupees(e.platformFee)),
                        LabeledValue(label: l.earnRefunds, value: formatRupees(e.refunds)),
                      ],
                    ),
                  ),
                  gap12,
                  if (e.lines.isEmpty)
                    EmptyView(message: l.earnEmpty, icon: Icons.account_balance_wallet_outlined)
                  else
                    SectionCard(
                      title: l.earnLines,
                      child: Column(
                        children: [
                          for (final line in e.lines)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(line.description),
                              subtitle: Text(formatIsoDate(context, line.date)),
                              trailing: Text(
                                formatRupees(line.payable),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
