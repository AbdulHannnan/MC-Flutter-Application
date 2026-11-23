// lib/src/features/checkout/payment_api.dart — the PAYMENT seam.
//
// No payment gateway is wired yet. [PaymentApi] is the contract the checkout flow
// speaks; the current [NoOpPaymentApi] simply approves (a clean pass-through), so
// the booking flow completes end-to-end. A real gateway (e.g. N-Genius) drops in
// as a second implementation and only [paymentApiProvider] changes — the checkout
// controller never learns which one ran. The failure path stays reachable (a
// booking submit that errors after "payment").

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/ids.dart';
import '../../models/models.dart';

/// The outcome of a payment attempt. A success carries the gateway's transaction
/// reference (shown on the receipt); a failure carries a user-facing reason.
class PaymentResult {
  final bool approved;

  /// Gateway transaction reference, e.g. "NGP-4F9K2" — present when [approved].
  final String? transactionRef;

  /// Why the charge failed — present when not [approved].
  final String? declineReason;

  const PaymentResult.approved(this.transactionRef)
      : approved = true,
        declineReason = null;
  const PaymentResult.declined(this.declineReason)
      : approved = false,
        transactionRef = null;
}

/// The payment gateway contract. One method: charge [amount]; the caller passes
/// the payer's contact for the gateway's records. Implementations never touch app
/// state — they just settle a charge and report the result.
abstract class PaymentApi {
  Future<PaymentResult> charge({
    required Money amount,
    required String phone,
    required String email,
  });
}

/// A short cosmetic delay so the "Paying…" state is visible.
const Duration kNoOpPaymentLatency = Duration(milliseconds: 600);

/// The no-op gateway: approves after a short delay with a generated reference.
/// The seam a real gateway replaces. Overridable to [Duration.zero] in tests.
class NoOpPaymentApi implements PaymentApi {
  NoOpPaymentApi({this.latency = kNoOpPaymentLatency});

  final Duration latency;

  @override
  Future<PaymentResult> charge({
    required Money amount,
    required String phone,
    required String email,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return PaymentResult.approved(_txnRef());
  }

  static String _txnRef() => 'NGP-${randomSuffix().toUpperCase()}';
}

/// The single [PaymentApi] the checkout reads — the no-op step for now. Swap this
/// for a real gateway implementation when one is added.
final paymentApiProvider =
    Provider<PaymentApi>((ref) => NoOpPaymentApi());
