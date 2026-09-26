import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/prescription.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../pharmacy/cart.dart';

/// `/prescriptions/:id/pharmacy-match`: the Rx lines matched against the
/// pharmacy catalogue. The user confirms which ones to buy; the cart is then
/// prefilled and checkout sends `prescriptionId`.
class PharmacyMatchScreen extends ConsumerStatefulWidget {
  const PharmacyMatchScreen({super.key, required this.prescriptionId});
  final String prescriptionId;

  @override
  ConsumerState<PharmacyMatchScreen> createState() => _PharmacyMatchScreenState();
}

class _PharmacyMatchScreenState extends ConsumerState<PharmacyMatchScreen> {
  Set<int>? _selected;

  Set<int> _defaults(List<RxMatch> list) => {for (final m in list) if (m.orderable) m.itemIndex};

  void _checkout(List<RxMatch> list, Prescription? rx) {
    final lines = cartFromRxMatch(list, selected: _selected ?? _defaults(list));
    if (lines.isEmpty) return;
    ref.read(cartProvider.notifier).replaceWith(lines);
    ref.read(cartRxProvider.notifier).set(CartRx(
          prescriptionId: widget.prescriptionId,
          doctorName: rx?.doctorName ?? '',
          issuedAt: rx?.createdAt ?? DateTime.now(),
        ));
    context.push('/pharmacy/cart');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final id = widget.prescriptionId;
    final rx = ref.watch(prescriptionProvider(id)).value;
    if (!ref.watch(featureFlagsProvider).pharmacyOrders) {
      return Scaffold(
        appBar: AppBar(title: Text(l.orderTheseMedicines)),
        body: EmptyStateView(icon: Icons.medication_outlined, title: l.comingSoon, message: l.pharmacyUnavailable),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.orderTheseMedicines)),
      body: AsyncView<List<RxMatch>>(
        value: ref.watch(pharmacyMatchProvider(id)),
        onRetry: () => ref.invalidate(pharmacyMatchProvider(id)),
        isEmpty: (list) => list.isEmpty,
        empty: EmptyStateView(icon: Icons.search_off, title: l.noPharmacyMatches),
        data: (list) {
          final selected = _selected ?? _defaults(list);
          final cart = cartFromRxMatch(list, selected: selected);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(Space.screen),
                  children: [
                    Text(l.pharmacyMatchIntro, style: TextStyle(color: context.textMuted)),
                    const SizedBox(height: Space.md),
                    for (final m in list)
                      _MatchTile(
                        match: m,
                        selected: selected.contains(m.itemIndex),
                        onChanged: m.orderable
                            ? (v) => setState(() {
                                  final next = {...selected};
                                  v ? next.add(m.itemIndex) : next.remove(m.itemIndex);
                                  _selected = next;
                                })
                            : null,
                      ),
                    const SizedBox(height: Space.sm),
                    Text(l.pharmacyMatchNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
                  child: PrimaryButton(
                    key: const Key('rx-add-to-cart'),
                    label: cart.isEmpty ? l.selectMedicines : l.addItemsToCart(cart.itemCount, money(cart.total)),
                    icon: Icons.shopping_cart_checkout,
                    onPressed: cart.isEmpty ? null : () => _checkout(list, rx),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.selected, required this.onChanged});
  final RxMatch match;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = match.product;
    final String subtitle;
    if (p == null) {
      subtitle = l.notInCatalogue;
    } else if (!p.inStock) {
      subtitle = '${p.name} · ${l.outOfStock}';
    } else {
      subtitle = [p.name, if (p.packSize.isNotEmpty) p.packSize, money(p.price)].join(' · ');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        borderColor: selected ? context.brand : null,
        child: CheckboxListTile(
          value: onChanged == null ? false : selected,
          onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(match.drugName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: TextStyle(color: p == null || !p.inStock ? AppColors.peachFg : context.textMuted)),
          secondary: p != null && p.requiresPrescription
              ? Tooltip(
                  message: l.rxRequired,
                  child: const Icon(Icons.receipt_long_outlined, color: AppColors.primaryLight),
                )
              : null,
        ),
      ),
    );
  }
}
