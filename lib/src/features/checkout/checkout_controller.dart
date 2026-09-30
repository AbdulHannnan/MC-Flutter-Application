// lib/src/features/checkout/checkout_controller.dart — the checkout ORCHESTRATION.
// Dart port of the RN app's checkout/pay flow.
//
// One action, [pay], runs the whole Module-14 sequence and records its result so
// the Success / Failure screens can read it back:
//   1. Charge the total through the (mock) payment gateway.
//   2. On approval, submit EACH cart line to the bookings API — sequentially and
//      awaited (README) — collecting the references, and build a local Booking
//      record per line for order history.
//   3. Persist those bookings locally (features/orders).
//   4. Fire a local notification per placed booking (fire-and-forget).
//   5. Clear the cart AND the booking draft.
// The outcome (success with references/amount/txn ref, or a failure reason) is
// held as this notifier's state; the screens navigate on it and read it there.
//
// FAILURE: the mock gateway always approves, so the visible failure path is a
// booking-submit error AFTER payment — surfaced as a distinct message so the user
// knows the charge went through. A declined charge (real gateway later) is handled
// the same way.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../auth/auth.dart';
import '../booking/booking.dart';
import '../cart/cart.dart';
import '../orders/orders_repository.dart';
import 'bookings_api.dart';
import 'notifications.dart';
import 'payment_api.dart';

/// The result of a checkout attempt — the Success/Failure screens' backing data.
class CheckoutOutcome {
  final bool success;

  /// One booking reference per placed cart line (success only).
  final List<String> references;

  /// The amount charged (success only).
  final Money? amount;

  /// The payment gateway's transaction reference (success only).
  final String? transactionRef;

  /// Why checkout failed (failure only).
  final String? failureReason;

  const CheckoutOutcome.success({
    required this.references,
    required this.amount,
    required this.transactionRef,
  })  : success = true,
        failureReason = null;

  const CheckoutOutcome.failure(this.failureReason)
      : success = false,
        references = const [],
        amount = null,
        transactionRef = null;
}

class CheckoutController extends Notifier<CheckoutOutcome?> {
  @override
  CheckoutOutcome? build() => null;

  /// Run the pay → submit → persist → notify → clear sequence. Returns (and
  /// stores) the outcome; the screen navigates to Success/Failure on it.
  Future<CheckoutOutcome> pay({
    required String phone,
    required String email,
  }) async {
    final lines = ref.read(cartProvider);
    final total = ref.read(cartSubtotalProvider);
    if (lines.isEmpty || total == null) {
      return _record(const CheckoutOutcome.failure('Your cart is empty.'));
    }

    final user = ref.read(sessionProvider).user;
    final customer = Customer(
      name: user?.fullName ?? user?.displayName ?? 'Customer',
      phone: phone.trim(),
      email: email.trim(),
    );

    // 1. Charge (mock always approves; a real decline lands here too).
    final payment = await ref.read(paymentApiProvider).charge(
          amount: total,
          phone: customer.phone,
          email: customer.email,
        );
    if (!payment.approved) {
      return _record(
          CheckoutOutcome.failure(payment.declineReason ?? 'Payment was declined.'));
    }

    // 2. Submit each line, sequentially + awaited; build local booking records.
    final api = ref.read(bookingsApiProvider);
    final createdAt = DateTime.now().toIso8601String();
    final placed = <Booking>[];
    final references = <String>[];
    try {
      for (final line in lines) {
        final submitted = await api.submitDraft(line, customer);
        references.add(submitted.reference);
        placed.add(_bookingFrom(
          line: line,
          submitted: submitted,
          userId: user?.id ?? '',
          transactionRef: payment.transactionRef,
          createdAt: createdAt,
        ));
      }
    } catch (_) {
      return _record(const CheckoutOutcome.failure(
          "Your payment went through, but we couldn't place all of your "
          'bookings. Your cart is saved — please try again or contact support.'));
    }

    // 3. Persist to local order history (Module 15 reads this).
    await ref.read(ordersRepositoryProvider).addAll(placed);

    // 4. Local notifications — fire-and-forget; never block or fail checkout.
    final notifications = ref.read(notificationsServiceProvider);
    for (final b in placed) {
      notifications.bookingConfirmed(
          reference: b.reference, serviceName: b.items.first.serviceName);
    }

    // 5. Clear the cart and the draft — the booking is placed.
    ref.read(cartProvider.notifier).clear();
    ref.read(bookingDraftProvider.notifier).reset();

    return _record(CheckoutOutcome.success(
      references: references,
      amount: total,
      transactionRef: payment.transactionRef,
    ));
  }

  /// Forget the last outcome (e.g. when leaving the Success/Failure screens).
  void reset() => state = null;

  CheckoutOutcome _record(CheckoutOutcome outcome) {
    state = outcome;
    return outcome;
  }

  /// One placed line → a locally-persisted confirmed [Booking] (its own receipt
  /// record, mirroring "submit each cart line" one-to-one).
  static Booking _bookingFrom({
    required CartItem line,
    required SubmittedBooking submitted,
    required String userId,
    required String? transactionRef,
    required String createdAt,
  }) {
    return Booking(
      id: submitted.id.isEmpty ? line.id : submitted.id,
      reference: submitted.reference,
      userId: userId,
      status: BookingStatus.confirmed,
      items: [line],
      slot: line.slot!,
      location: line.location,
      subtotal: line.lineTotal,
      total: line.lineTotal,
      notes: line.notes,
      createdAt: createdAt,
      paymentId: transactionRef,
    );
  }
}

/// The last checkout outcome. The checkout screen writes it (via [pay]); the
/// Success/Failure screens read it.
final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutOutcome?>(CheckoutController.new);
