// lib/src/features/cart/cart_storage.dart — the cart's LOCAL persistence seam.
// The analog of the RN app's zustand `persist` middleware over AsyncStorage.
//
// The cart is CLIENT STATE THE APP OWNS and must survive app restarts (README
// Module 13: "Cart persists locally"), so the line list is written to the
// device's key-value store (shared_preferences — the same backend the mock auth
// uses). This class is the ONLY thing that knows the storage key and JSON shape;
// [CartController] talks to it and the rest of the app never learns how the cart
// is persisted — swap this one file for a server-backed cart later.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';

// Namespaced like the auth keys (see mock_auth_api.dart).
const String _cartKey = 'microcare-cart';

/// Reads and writes the persisted cart line list. Pure storage — no business
/// rules, no derived totals (those live on [CartItem] / the controller).
class CartStorage {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// The saved cart, or an empty list when nothing is stored (or the stored
  /// value is corrupt — a bad blob is treated as an empty cart, never an error
  /// that would block the app).
  Future<List<CartItem>> read() async {
    final raw = (await _prefs).getString(_cartKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Persist the whole line list (the controller writes after every mutation).
  Future<void> write(List<CartItem> items) async {
    final raw = jsonEncode(items.map((i) => i.toJson()).toList());
    await (await _prefs).setString(_cartKey, raw);
  }

  /// Drop the saved cart entirely (clear-all / checkout / logout).
  Future<void> clear() async {
    await (await _prefs).remove(_cartKey);
  }
}

/// The single [CartStorage] the cart layer reads. Overridable in tests.
final cartStorageProvider = Provider<CartStorage>((ref) => CartStorage());
