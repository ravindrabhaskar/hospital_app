import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/field_ops.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// `GET /provider/supplies` (§48), falling back to the last list when offline.
final suppliesProvider = FutureProvider.autoDispose<({List<SupplyItem> items, bool fromCache})>((ref) {
  return ref.watch(fieldRepositoryProvider).supplies();
});

String formatQty(BuildContext context, num n) =>
    NumberFormat('#,##0.##', Localizations.localeOf(context).toString()).format(n);

/// On-hand supplies with low-stock highlighting.
class SuppliesScreen extends ConsumerWidget {
  const SuppliesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(suppliesProvider);
    Future<void> refresh() => ref.refresh(suppliesProvider.future).then((_) {}, onError: (_) {});
    return Scaffold(
      appBar: AppBar(title: Text(l.supTitle)),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: async.when(
          loading: () => ListView(children: const [SizedBox(height: 200, child: LoadingView())]),
          error: (e, _) => ListView(children: [
            SizedBox(height: 320, child: ErrorView(message: errorMessage(l, e), onRetry: refresh)),
          ]),
          data: (r) {
            if (r.items.isEmpty) {
              return ListView(children: [const SizedBox(height: 40), EmptyView(message: l.supEmpty, icon: Icons.inventory_2_outlined)]);
            }
            final low = r.items.where((i) => i.isLow).length;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                if (r.fromCache)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(l.visitsShowingCached,
                        style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                  ),
                if (low > 0)
                  Container(
                    key: const Key('supLowBanner'),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFF9A5A10)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.supLowBanner(low))),
                    ]),
                  ),
                for (final item in r.items) SupplyTile(item: item),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SupplyTile extends StatelessWidget {
  const SupplyTile({super.key, required this.item});
  final SupplyItem item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (Color bg, Color fg, String? tag) = item.isOut
        ? (AppColors.dangerBg, AppColors.dangerDeep, l.supOut)
        : item.isLow
            ? (AppColors.warningBg, const Color(0xFF9A5A10), l.supLow)
            : (AppColors.surface, AppColors.textPrimary, null);
    final qty = '${formatQty(context, item.onHand)} ${item.unit}'.trim();
    return Card(
      key: Key('supply.${item.code}'),
      color: bg,
      child: Semantics(
        label: [item.name, qty, ?tag].join(', '),
        excludeSemantics: true,
        child: ListTile(
          leading: Icon(item.isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined, color: fg),
          title: Text(item.name, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
          subtitle: Text(l.supReorderAt(formatQty(context, item.reorderLevel))),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(qty, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16)),
              if (tag != null) Text(tag, key: Key('supTag.${item.code}'), style: TextStyle(color: fg, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: quantities used during a visit. Returns code -> qty (only
/// non-zero entries), or null when cancelled.
Future<Map<String, int>?> showSuppliesUsageSheet(BuildContext context) => showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SuppliesUsageSheet(),
    );

class SuppliesUsageSheet extends ConsumerStatefulWidget {
  const SuppliesUsageSheet({super.key});

  @override
  ConsumerState<SuppliesUsageSheet> createState() => _SuppliesUsageSheetState();
}

class _SuppliesUsageSheetState extends ConsumerState<SuppliesUsageSheet> {
  final Map<String, int> _qty = {};

  void _set(String code, int value) => setState(() => _qty[code] = value.clamp(0, 999));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(suppliesProvider);
    final total = _qty.values.fold<int>(0, (a, b) => a + b);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.supUsageTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(l.supUsageHint, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Flexible(
                child: async.when(
                  loading: () => const SizedBox(height: 120, child: LoadingView()),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(errorMessage(l, e), textAlign: TextAlign.center),
                  ),
                  data: (r) => r.items.isEmpty
                      ? Padding(padding: const EdgeInsets.all(16), child: Text(l.supEmpty, textAlign: TextAlign.center))
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final item in r.items)
                              _QtyRow(
                                item: item,
                                qty: _qty[item.code] ?? 0,
                                onChanged: (v) => _set(item.code, v),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('supUsageSave'),
                      onPressed: total == 0
                          ? null
                          : () => Navigator.pop(context, {
                                for (final e in _qty.entries)
                                  if (e.value > 0) e.key: e.value,
                              }),
                      child: Text(l.supUsageSave),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyRow extends StatelessWidget {
  const _QtyRow({required this.item, required this.qty, required this.onChanged});
  final SupplyItem item;
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(l.supOnHand('${formatQty(context, item.onHand)} ${item.unit}'.trim()),
                    style: TextStyle(color: item.isLow ? AppColors.dangerDeep : AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            key: Key('supMinus.${item.code}'),
            tooltip: l.supDecrease(item.name),
            onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 32,
            child: Text('$qty', key: Key('supQty.${item.code}'), textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            key: Key('supPlus.${item.code}'),
            tooltip: l.supIncrease(item.name),
            onPressed: () => onChanged(qty + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
