// lib/src/features/orders/orders_providers.dart — the READ side of order history.
// Dart port of the RN app's useBookings/useBooking hooks (src/features/orders/
// hooks/useBookings.ts).
//
// Module 14 WROTE confirmed bookings into the local OrdersRepository; these
// providers read them back for the My-Bookings list (Module 15) and the digital
// receipt, as AsyncValues so the screens stay declarative (loading / error /
// empty / data) — the same seam the catalog screens already lean on.
//
// Every read is SCOPED TO THE SIGNED-IN USER: a booking's userId must match the
// session's. In this rebuild signOut already clears the store, so it only ever
// holds the current user's bookings; the scope is a belt-and-braces guard that a
// stale blob can never leak another account's history (mirrors the RN query key).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../auth/auth.dart';
import 'orders_repository.dart';

/// Every booking belonging to the signed-in user, newest first (the repository
/// already sorts). Empty when signed out. Re-run with
/// `ref.invalidate(bookingsProvider)`.
final bookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final userId = ref.watch(sessionProvider).user?.id;
  if (userId == null) return const [];
  final all = await ref.watch(ordersRepositoryProvider).readAll();
  return all.where((b) => b.userId == userId).toList();
});

/// A single booking by id, scoped to the signed-in user. Resolves to `null` when
/// it doesn't exist or belongs to someone else — the receipt then shows a
/// "not found" state rather than an error.
final bookingProvider =
    FutureProvider.autoDispose.family<Booking?, Id>((ref, id) async {
  final list = await ref.watch(bookingsProvider.future);
  for (final booking in list) {
    if (booking.id == id) return booking;
  }
  return null;
});
