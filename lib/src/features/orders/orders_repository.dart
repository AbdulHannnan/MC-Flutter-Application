// lib/src/features/orders/orders_repository.dart — LOCAL order history storage.
// Dart port of the RN app's local order store.
//
// README §MOCK: "Order history + booking detail — local storage." So confirmed
// bookings live on the device (shared_preferences — the same backend auth + cart
// use), independent of BOOKINGS_MODE (which only decides where the DRAFT submit
// goes). Module 14 WRITES a placed booking here after a successful checkout;
// Module 15 builds the My-Bookings list + receipt on top of it.
//
// This module is intentionally thin: append one booking, read them all (newest
// first). No UI, no business rules — just persistence behind a provider.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';

// Namespaced like the auth + cart keys.
const String _ordersKey = 'microcare-orders';

class OrdersRepository {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Every saved booking, NEWEST FIRST. A corrupt blob reads as empty (never an
  /// error that would block the receipt / history).
  Future<List<Booking>> readAll() async {
    final raw = (await _prefs).getString(_ordersKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final bookings = list
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList();
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
      return bookings;
    } catch (_) {
      return const [];
    }
  }

  /// Append placed bookings (a checkout can place several — one per cart line).
  Future<void> addAll(List<Booking> bookings) async {
    if (bookings.isEmpty) return;
    final existing = await readAll();
    final next = [...bookings, ...existing];
    await (await _prefs)
        .setString(_ordersKey, jsonEncode(next.map((b) => b.toJson()).toList()));
  }

  /// Drop all saved bookings (e.g. on logout, to match the cart clearing).
  Future<void> clear() async {
    await (await _prefs).remove(_ordersKey);
  }
}

/// The single [OrdersRepository] the app reads. Overridable in tests.
final ordersRepositoryProvider =
    Provider<OrdersRepository>((ref) => OrdersRepository());
