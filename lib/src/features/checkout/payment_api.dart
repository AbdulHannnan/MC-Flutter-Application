// lib/src/features/checkout/payment_api.dart — the PAYMENT seam. Dart port of the
// RN app's payment layer (N-Genius), MOCKED here behind an interface.
//
// README §MOCK: "Payments — N-Genius is mocked (behind a seam for a real drop-in
// later)." So [PaymentApi] is the contract the checkout flow speaks; the real
// N-Genius Flutter package drops in as a second implementation and only
// [paymentApiProvider] changes — the checkout controller never learns which one
// ran. The mock ALWAYS approves (per the module's chosen behaviour); the failure
// path is still reachable when a booking submit errors after payment.

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
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

/// A short cosmetic delay so the "Paying…" state is visible in development.
const Duration kMockPaymentLatency = Duration(milliseconds: 600);

/// The mock gateway: always approves, after a short delay, with a generated
/// transaction reference. Overridable to [Duration.zero] in tests.
class MockPaymentApi implements PaymentApi {
  MockPaymentApi({this.latency = kMockPaymentLatency});

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

  static String _txnRef() {
    final rand = Random().nextInt(1 << 32).toRadixString(36).toUpperCase();
    return 'NGP-$rand';
  }
}

/// The single [PaymentApi] the checkout reads. Mock unless PAYMENTS_MODE=live —
/// the real N-Genius SDK is not wired yet, so `live` fails loudly rather than
/// silently no-op'ing a charge.
final paymentApiProvider = Provider<PaymentApi>((ref) {
  if (config.isMockPayments) return MockPaymentApi();
  throw UnimplementedError(
      'Live N-Genius payments are not wired yet (PAYMENTS_MODE=live). '
      'Keep PAYMENTS_MODE=mock, or drop in the N-Genius PaymentApi here.');
});
