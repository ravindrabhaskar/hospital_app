import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/misc.dart';
import '../../state/data_providers.dart';
import 'cart.dart';

class PharmacyScreen extends ConsumerStatefulWidget {
  const PharmacyScreen({super.key});

  @override
  ConsumerState<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends ConsumerState<PharmacyScreen> {
  String _q = '';
  String? _category;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  ProductQuery get _query => (q: _q.isEmpty ? null : _q, category: _category);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cart = ref.watch(cartProvider);
    final cats = ref.watch(pharmacyCategoriesProvider);
    final products = ref.watch(productsProvider(_query));
    const accents = [Accent.rose, Accent.sky, Accent.peach, Accent.lavender, Accent.teal];

    return Scaffold(
      appBar: AppBar(title: Text(l.qaOrderMedicines)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                TextField(
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400),
                        () => mounted ? setState(() => _q = v.trim()) : null);
                  },
                  decoration: InputDecoration(
                    hintText: l.searchMedicines,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: Space.lg),
                CcCard(
                  color: context.skySurface,
                  borderColor: context.skySurface,
                  onTap: () => context.push('/records/upload?type=prescription'),
                  child: Row(
                    children: [
                      const IconTile(icon: Icons.upload_file, accent: Accent.sky, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.uploadPrescription, style: Theme.of(context).textTheme.titleSmall),
                            Text(l.uploadPrescriptionSub,
                                style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                SectionHeader(title: l.popularCategories),
                SizedBox(
                  height: 96,
                  child: cats.when(
                    loading: () => const LoadingView(compact: true),
                    error: (e, _) => ErrorStateView(
                        compact: true, error: e, onRetry: () => ref.invalidate(pharmacyCategoriesProvider)),
                    data: (list) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Space.md),
                      itemBuilder: (_, i) {
                        final c = list[i];
                        final sel = _category == c.code;
                        return Semantics(
                          selected: sel,
                          button: true,
                          label: c.name,
                          excludeSemantics: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(Radii.tile),
                            onTap: () => setState(() => _category = sel ? null : c.code),
                            child: SizedBox(
                              width: 76,
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(Radii.tile),
                                      border: Border.all(
                                          color: sel ? AppColors.primary : Colors.transparent, width: 2),
                                    ),
                                    child: IconTile(
                                        icon: _categoryIcon(c.code), accent: accents[i % accents.length], size: 52),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      style: const TextStyle(fontSize: 11.5)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SectionHeader(title: _q.isEmpty && _category == null ? l.frequentlyOrdered : l.results),
                AsyncView<List<Product>>(
                  value: products,
                  compact: true,
                  onRetry: () => ref.invalidate(productsProvider(_query)),
                  isEmpty: (l) => l.isEmpty,
                  empty: EmptyStateView(compact: true, icon: Icons.search_off, title: l.noResults),
                  data: (list) => Column(
                    children: [for (final p in list) ProductTile(product: p, qty: cart[p.id]?.qty ?? 0)],
                  ),
                ),
              ],
            ),
          ),
          if (cart.isNotEmpty) const CartBar(),
        ],
      ),
    );
  }

  IconData _categoryIcon(String code) {
    final c = code.toLowerCase();
    if (c.contains('pain')) return Icons.healing;
    if (c.contains('diab')) return Icons.water_drop_outlined;
    if (c.contains('skin')) return Icons.spa_outlined;
    if (c.contains('vitamin')) return Icons.bolt;
    if (c.contains('heart') || c.contains('cardio')) return Icons.favorite_border;
    if (c.contains('baby') || c.contains('child')) return Icons.child_care;
    return Icons.medication_outlined;
  }
}

class ProductTile extends ConsumerWidget {
  const ProductTile({super.key, required this.product, required this.qty});
  final Product product;
  final int qty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = product;
    final cart = ref.read(cartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 56,
                color: context.peachSurface,
                child: p.imageUrl != null
                    ? Image.network(p.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.medication, color: AppColors.peachFg))
                    : const Icon(Icons.medication, color: AppColors.peachFg),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: Theme.of(context).textTheme.titleSmall),
                  Text(p.packSize, style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (p.mrp > p.price) ...[
                        const SizedBox(width: 6),
                        Text(money(p.mrp),
                            style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: context.textMuted,
                                fontSize: 12)),
                      ],
                      if (p.requiresPrescription) ...[
                        const SizedBox(width: 6),
                        StatusPill(label: l.rxRequired, color: AppColors.danger),
                      ],
                    ],
                  ),
                  if (!p.inStock)
                    Text(l.outOfStock, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ],
              ),
            ),
            if (qty == 0)
              IconButton.filled(
                tooltip: l.addToCart(p.name),
                onPressed: p.inStock ? () => cart.add(p) : null,
                style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.add),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      tooltip: l.decreaseQty, onPressed: () => cart.decrement(p), icon: const Icon(Icons.remove)),
                  Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(tooltip: l.increaseQty, onPressed: () => cart.add(p), icon: const Icon(Icons.add)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cart = ref.watch(cartProvider);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
        padding: const EdgeInsets.fromLTRB(Space.lg, 8, 8, 8),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: context.borderColor),
          boxShadow: Shadows.card,
        ),
        child: Row(
          children: [
            Badge(
              label: Text('${cart.itemCount}'),
              child: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.itemsCount(cart.itemCount), style: const TextStyle(fontSize: 12.5)),
                  Text(money(cart.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            ),
            FilledButton(onPressed: () => context.push('/pharmacy/cart'), child: Text(l.viewCart)),
          ],
        ),
      ),
    );
  }
}
