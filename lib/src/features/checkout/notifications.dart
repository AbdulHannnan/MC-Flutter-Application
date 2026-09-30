// lib/src/features/checkout/notifications.dart — the local-NOTIFICATIONS seam.
// Dart port of the RN app's notifications layer, MOCKED (README: PUSH_MODE=mock →
// "local notifications only").
//
// After a booking is placed the app tells the user, without any remote push
// infrastructure. [NotificationsService] is the contract; the mock just logs (a
// real `flutter_local_notifications` implementation drops in behind the same
// interface and only [notificationsServiceProvider] changes). Firing a
// notification must never break checkout, so callers fire-and-forget and the mock
// never throws.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class NotificationsService {
  /// Notify the user that a booking is confirmed (one per placed line).
  Future<void> bookingConfirmed({
    required String reference,
    required String serviceName,
  });
}

/// The mock: logs in debug, no-ops in release. Never throws.
class MockNotificationsService implements NotificationsService {
  @override
  Future<void> bookingConfirmed({
    required String reference,
    required String serviceName,
  }) async {
    if (kDebugMode) {
      debugPrint('[notification] Booking confirmed · $serviceName · $reference');
    }
  }
}

/// The single [NotificationsService] the checkout reads. Mock for now (local
/// notifications); a real implementation swaps in here.
final notificationsServiceProvider =
    Provider<NotificationsService>((ref) => MockNotificationsService());
