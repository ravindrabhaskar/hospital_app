import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/billing.dart';
import '../../models/care.dart';
import '../../state/data_providers.dart';

class PaymentsHistoryScreen extends ConsumerWidget {
  const PaymentsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.payments)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(paymentsProvider.future),
        child: AsyncView<List<Payment>>(
          value: ref.watch(paymentsProvider),
          onRetry: () => ref.invalidate(paymentsProvider),
          isEmpty: (l) => l.isEmpty,
          empty: EmptyStateView(icon: Icons.receipt_long_outlined, title: l.noPayments),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.all(Space.screen),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
            itemBuilder: (_, i) {
              final p = list[i];
              final color = switch (p.status) {
                'succeeded' => AppColors.primaryLight,
                'failed' => AppColors.danger,
                'pending' => AppColors.peachFg,
                _ => AppColors.skyFg,
              };
              return CcCard(
                child: Row(
                  children: [
                    IconTile(
                      icon: switch (p.purpose) {
                        'appointment' => Icons.medical_services_outlined,
                        'home_visit' => Icons.home_outlined,
                        'subscription' => Icons.workspace_premium_outlined,
                        _ => Icons.medication_outlined,
                      },
                      accent: Accent.teal,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Labels.paymentPurpose(l, p.purpose), style: Theme.of(context).textTheme.titleSmall),
                          Text(fmtDateTime(context, p.createdAt),
                              style: TextStyle(fontSize: 12, color: context.textMuted)),
                          if (p.refundedAmount > 0)
                            Text(l.refunded(money(p.refundedAmount)),
                                style: const TextStyle(fontSize: 12, color: AppColors.skyFg)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        StatusPill(label: Labels.paymentStatus(l, p.status), color: color),
                        if (invoiceableStatuses.contains(p.status))
                          TextButton.icon(
                            key: Key('invoice-${p.id}'),
                            onPressed: () => context.push('/payments/${p.id}/invoice'),
                            icon: const Icon(Icons.receipt_outlined, size: 18),
                            label: Text(l.invoice),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
