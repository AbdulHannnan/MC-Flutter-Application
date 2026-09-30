// The checkout orchestration (Module 14): CheckoutController.pay runs
// charge → submit-each-line → persist → notify → clear. Covers the success path
// (references, orders saved, cart+draft cleared) and a submit-failure path (outcome
// failure, cart INTACT).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/booking/booking.dart';
import 'package:microcare/src/features/cart/cart_controller.dart';
import 'package:microcare/src/features/checkout/bookings_api.dart';
import 'package:microcare/src/features/checkout/checkout_controller.dart';
import 'package:microcare/src/features/checkout/payment_api.dart';
import 'package:microcare/src/features/orders/orders_repository.dart';
import 'package:microcare/src/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

int _seq = 0;
CartItem _line() => CartItem(
      id: 'line_${_seq++}',
      serviceId: 'svc_split_clean',
      quantity: 1,
      serviceName: 'Split AC Deep Cleaning',
      unitPrice: _aed(9900),
      location: const BookingLocation(addressText: 'Marina Gate 1'),
      slot: const TimeSlot(
        id: 'slot_1',
        start: '2026-09-01T10:00:00.000',
        end: '2026-09-01T11:00:00.000',
      ),
    );

/// Records submits; can be told to throw to exercise the failure path.
class _FakeBookingsApi implements BookingsApi {
  _FakeBookingsApi({this.throwOnSubmit = false});
  final bool throwOnSubmit;
  int calls = 0;

  @override
  Future<SubmittedBooking> submitDraft(CartItem line, Customer customer) async {
    calls++;
    if (throwOnSubmit) throw Exception('submit failed');
    return SubmittedBooking(id: 'bk_$calls', reference: 'MC-REF$calls');
  }
}

/// In-memory order history.
class _FakeOrders implements OrdersRepository {
  final List<Booking> saved = [];
  @override
  Future<List<Booking>> readAll() async => saved;
  @override
  Future<void> addAll(List<Booking> bookings) async => saved.addAll(bookings);
  @override
  Future<void> clear() async => saved.clear();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer makeContainer(BookingsApi bookings, _FakeOrders orders) {
    final c = ProviderContainer(
      overrides: [
        paymentApiProvider
            .overrideWithValue(MockPaymentApi(latency: Duration.zero)),
        bookingsApiProvider.overrideWithValue(bookings),
        ordersRepositoryProvider.overrideWithValue(orders),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a successful pay places bookings, clears cart+draft, records outcome',
      () async {
    final orders = _FakeOrders();
    final c = makeContainer(_FakeBookingsApi(), orders);

    // Seed two cart lines + a draft.
    c.read(cartProvider.notifier)
      ..add(_line())
      ..add(_line());
    c.read(bookingDraftProvider.notifier).setNotes('x'); // make the draft non-empty

    final outcome = await c
        .read(checkoutControllerProvider.notifier)
        .pay(phone: '0501234567', email: 'jane@example.com');

    expect(outcome.success, isTrue);
    expect(outcome.references, hasLength(2));
    expect(outcome.amount, _aed(19800)); // 9900 × 2 lines
    expect(outcome.transactionRef, isNotNull);
    expect(orders.saved, hasLength(2)); // persisted to order history
    expect(c.read(cartProvider), isEmpty); // cart cleared
    expect(c.read(bookingDraftProvider).notes, isEmpty); // draft reset
    // Outcome is also retained for the Success screen to read.
    expect(c.read(checkoutControllerProvider)?.success, isTrue);
  });

  test('a submit failure fails checkout and leaves the cart intact', () async {
    final orders = _FakeOrders();
    final c = makeContainer(_FakeBookingsApi(throwOnSubmit: true), orders);

    c.read(cartProvider.notifier).add(_line());

    final outcome = await c
        .read(checkoutControllerProvider.notifier)
        .pay(phone: '0501234567', email: 'jane@example.com');

    expect(outcome.success, isFalse);
    expect(outcome.failureReason, isNotNull);
    expect(orders.saved, isEmpty);
    expect(c.read(cartProvider), hasLength(1)); // cart preserved on failure
  });
}
