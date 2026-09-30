// lib/src/features/cart/cart_controller.dart — the CART store. The Riverpod
// analog of the RN app's persisted `useCartStore` (zustand + persist).
//
// Holds the list of configured [CartItem] lines and the mutations over them
// (add / remove / change quantity / clear). State is a plain, synchronous
// `List<CartItem>` so every read is instant (the Home badge, the subtotal) —
// the saved cart HYDRATES asynchronously on build and is written back through
// [CartStorage] after each change.
//
// HYDRATION vs MUTATION: build() starts from an empty list and kicks off an
// async load. If the user changes the cart before that load returns (a fast
// add-to-cart on a cold start), the freshly-loaded snapshot is NOT applied over
// their change — the local mutation wins. This mirrors how the RN persist
// middleware rehydrates without clobbering an already-touched store; a lost
// older line here is an acceptable cold-start race for a local mock cart.
//
// Each add appends a NEW line (a configured booking is its own line — the draft
// generates a unique line id per add, see BookingDraft.buildCartItem); the
// quantity stepper adjusts an existing line instead of merging duplicates.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import 'cart_storage.dart';

class CartController extends Notifier<List<CartItem>> {
  CartStorage get _storage => ref.read(cartStorageProvider);

  /// Set once the user changes the cart, so a late hydration can't overwrite it.
  bool _touched = false;

  @override
  List<CartItem> build() {
    _hydrate();
    return const [];
  }

  /// Load the saved cart in the background. Adopt it only if the user hasn't
  /// already changed the cart during the load (see the file header). A read
  /// failure leaves the cart empty rather than surfacing an error.
  Future<void> _hydrate() async {
    final List<CartItem> stored;
    try {
      stored = await _storage.read();
    } catch (_) {
      return;
    }
    if (_touched || stored.isEmpty) return;
    state = stored;
  }

  /// Commit a new state and persist it (fire-and-forget — the in-memory list is
  /// the source of truth for the UI; the write just keeps the disk copy fresh).
  void _commit(List<CartItem> next) {
    _touched = true;
    state = next;
    _storage.write(next);
  }

  /// Append a fully-configured line (from `BookingDraft.buildCartItem`).
  void add(CartItem item) => _commit([...state, item]);

  /// Remove a line by its id.
  void remove(String lineId) =>
      _commit(state.where((i) => i.id != lineId).toList());

  /// Set an exact quantity for a line. A quantity of 0 or less removes the line
  /// (the stepper's "−" at 1 drops it), matching the RN cart.
  void setQuantity(String lineId, int quantity) {
    if (quantity <= 0) return remove(lineId);
    _commit([
      for (final i in state)
        if (i.id == lineId) i.copyWith(quantity: quantity) else i,
    ]);
  }

  /// Bump a line's quantity by one.
  void increment(String lineId) {
    final line = _find(lineId);
    if (line != null) setQuantity(lineId, line.quantity + 1);
  }

  /// Drop a line's quantity by one (removing it at zero).
  void decrement(String lineId) {
    final line = _find(lineId);
    if (line != null) setQuantity(lineId, line.quantity - 1);
  }

  /// Empty the cart (clear-all, and after a booking is placed / on logout).
  void clear() => _commit(const []);

  CartItem? _find(String lineId) {
    for (final i in state) {
      if (i.id == lineId) return i;
    }
    return null;
  }
}

/// The app-wide cart. Read the whole list (or a `.select`ed derived value) and
/// call the controller's methods to mutate it. Kept alive for the app's lifetime
/// so the cart survives navigation.
final cartProvider =
    NotifierProvider<CartController, List<CartItem>>(CartController.new);

/// Total item count across all lines (Σ quantities) — drives the Home cart badge.
/// Replaces Module 9's stub. `.select` so watchers rebuild only when it changes.
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(
    cartProvider.select((lines) => lines.fold<int>(0, (n, i) => n + i.quantity)),
  );
});

/// The cart subtotal: the sum of every line total. Null when the cart is empty
/// (no currency to sum in) so callers can hide the row. All lines share the app's
/// single currency (AED), so a plain running sum is safe.
final cartSubtotalProvider = Provider<Money?>((ref) {
  final lines = ref.watch(cartProvider);
  if (lines.isEmpty) return null;
  return lines.fold<Money>(
    Money.zero(lines.first.lineTotal.currency),
    (sum, i) => sum + i.lineTotal,
  );
});
