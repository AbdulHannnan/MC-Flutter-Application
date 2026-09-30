// The CART store (Module 13): the persisted Riverpod port of RN's useCartStore.
// Covers add/remove/setQuantity/increment/decrement/clear, the derived
// count/subtotal providers, background hydration from storage, and the
// hydration-vs-mutation race guard.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/cart/cart_controller.dart';
import 'package:microcare/src/features/cart/cart_storage.dart';
import 'package:microcare/src/models/models.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

int _seq = 0;
CartItem _item({
  String? id,
  int quantity = 1,
  int unit = 5000,
  List<CartAddon> addons = const [],
}) =>
    CartItem(
      id: id ?? 'line_${_seq++}',
      serviceId: 's1',
      quantity: quantity,
      serviceName: 'Split AC Deep Cleaning',
      unitPrice: _aed(unit),
      addons: addons,
    );

/// In-memory storage stub — deterministic, no shared_preferences. Records the
/// last write so persistence can be asserted, and seeds a starting cart.
class _FakeCartStorage implements CartStorage {
  _FakeCartStorage([this.seed = const []]);
  List<CartItem> seed;
  List<CartItem>? lastWrite;
  int clears = 0;

  @override
  Future<List<CartItem>> read() async => seed;

  @override
  Future<void> write(List<CartItem> items) async => lastWrite = items;

  @override
  Future<void> clear() async => clears++;
}

void main() {
  ProviderContainer makeContainer(_FakeCartStorage storage) {
    final c = ProviderContainer(
      overrides: [cartStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    return c;
  }

  CartController ctrl(ProviderContainer c) => c.read(cartProvider.notifier);
  List<CartItem> lines(ProviderContainer c) => c.read(cartProvider);

  test('starts empty', () {
    final c = makeContainer(_FakeCartStorage());
    expect(lines(c), isEmpty);
    expect(c.read(cartCountProvider), 0);
    expect(c.read(cartSubtotalProvider), isNull);
  });

  test('hydrates the saved cart in the background', () async {
    final c = makeContainer(_FakeCartStorage([_item(quantity: 2)]));
    // Reading the provider triggers build() → fire-and-forget _hydrate.
    expect(lines(c), isEmpty);
    await Future<void>.value(); // let the read() microtask resolve
    expect(lines(c), hasLength(1));
    expect(c.read(cartCountProvider), 2);
  });

  test('add appends a new line each time (no merge)', () {
    final c = makeContainer(_FakeCartStorage());
    ctrl(c).add(_item(id: 'a'));
    ctrl(c).add(_item(id: 'b'));
    expect(lines(c).map((i) => i.id), ['a', 'b']);
    expect(c.read(cartCountProvider), 2);
  });

  test('increment / decrement adjust a line; decrement at 1 removes it', () {
    final c = makeContainer(_FakeCartStorage());
    ctrl(c).add(_item(id: 'a'));
    ctrl(c).increment('a');
    expect(lines(c).single.quantity, 2);
    ctrl(c).decrement('a');
    expect(lines(c).single.quantity, 1);
    ctrl(c).decrement('a');
    expect(lines(c), isEmpty);
  });

  test('setQuantity to 0 removes the line', () {
    final c = makeContainer(_FakeCartStorage());
    ctrl(c).add(_item(id: 'a'));
    ctrl(c).setQuantity('a', 0);
    expect(lines(c), isEmpty);
  });

  test('remove drops the matching line only', () {
    final c = makeContainer(_FakeCartStorage());
    ctrl(c)
      ..add(_item(id: 'a'))
      ..add(_item(id: 'b'));
    ctrl(c).remove('a');
    expect(lines(c).map((i) => i.id), ['b']);
  });

  test('clear empties the cart', () {
    final c = makeContainer(_FakeCartStorage());
    ctrl(c).add(_item(id: 'a'));
    ctrl(c).clear();
    expect(lines(c), isEmpty);
  });

  test('subtotal sums line totals (unit + add-ons) × quantity', () {
    final c = makeContainer(_FakeCartStorage());
    final addon = CartAddon(id: 'x', name: 'Deep clean', price: _aed(1000));
    ctrl(c).add(_item(id: 'a', unit: 5000, addons: [addon], quantity: 2));
    // (5000 + 1000) × 2 = 12000
    ctrl(c).add(_item(id: 'b', unit: 3000));
    expect(c.read(cartSubtotalProvider), _aed(15000));
  });

  test('mutations persist through storage', () {
    final storage = _FakeCartStorage();
    final c = makeContainer(storage);
    ctrl(c).add(_item(id: 'a'));
    expect(storage.lastWrite?.map((i) => i.id), ['a']);
  });

  test('a mutation before hydration wins over the stored cart', () async {
    final c = makeContainer(_FakeCartStorage([_item(id: 'stored')]));
    // Mutate immediately, before the async hydrate resolves.
    ctrl(c).add(_item(id: 'fresh'));
    await Future<void>.value();
    // The stored line must NOT clobber the local change.
    expect(lines(c).map((i) => i.id), ['fresh']);
  });
}
