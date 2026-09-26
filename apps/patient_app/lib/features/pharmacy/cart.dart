import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/misc.dart';
import '../../models/prescription.dart';

class CartLine {
  const CartLine(this.product, this.qty);
  final Product product;
  final int qty;
}

class CartNotifier extends Notifier<Map<String, CartLine>> {
  @override
  Map<String, CartLine> build() => const {};

  void add(Product p) {
    final cur = state[p.id];
    state = {...state, p.id: CartLine(p, (cur?.qty ?? 0) + 1)};
  }

  void decrement(Product p) {
    final cur = state[p.id];
    if (cur == null) return;
    final next = {...state};
    if (cur.qty <= 1) {
      next.remove(p.id);
    } else {
      next[p.id] = CartLine(p, cur.qty - 1);
    }
    state = next;
  }

  /// Replaces the whole cart (used by "Order these medicines").
  void replaceWith(Map<String, CartLine> lines) => state = Map.unmodifiable(lines);

  void clear() => state = const {};
}

final cartProvider = NotifierProvider<CartNotifier, Map<String, CartLine>>(CartNotifier.new);

extension CartX on Map<String, CartLine> {
  int get itemCount => values.fold(0, (a, l) => a + l.qty);
  int get total => values.fold(0, (a, l) => a + l.qty * l.product.price);
  bool get needsPrescription => values.any((l) => l.product.requiresPrescription);
}

/// The e-prescription a cart was filled from. Sent as `prescriptionId` with
/// `POST /pharmacy/orders`, which satisfies the Rx requirement (§31).
class CartRx {
  const CartRx({required this.prescriptionId, required this.doctorName, required this.issuedAt});
  final String prescriptionId;
  final String doctorName;
  final DateTime issuedAt;
}

class CartRxNotifier extends Notifier<CartRx?> {
  @override
  CartRx? build() => null;

  void set(CartRx? rx) => state = rx;
}

final cartRxProvider = NotifierProvider<CartRxNotifier, CartRx?>(CartRxNotifier.new);

/// Builds the prefilled cart for "Order these medicines": one pack of every
/// matched, in-stock product whose Rx line is in [selected] (all orderable
/// lines when null). Lines matching the same product are merged.
Map<String, CartLine> cartFromRxMatch(List<RxMatch> matches, {Set<int>? selected}) {
  final out = <String, CartLine>{};
  for (final m in matches) {
    final p = m.product;
    if (p == null || !p.inStock) continue;
    if (selected != null && !selected.contains(m.itemIndex)) continue;
    final cur = out[p.id];
    out[p.id] = CartLine(p, (cur?.qty ?? 0) + 1);
  }
  return out;
}
