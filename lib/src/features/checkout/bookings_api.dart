// lib/src/features/checkout/bookings_api.dart — the BOOKING SUBMIT seam.
//
// Per cart line, the booking is placed on Supabase (create-draft → finalize-booking
// Edge Functions; see supabase_bookings_api.dart). This file holds the backend-
// agnostic contract ([BookingsApi]) + its value types, so the checkout controller
// depends only on the seam and tests can override it with a fake.
// (Order HISTORY is always local — see features/orders.)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_client.dart';
import '../../models/models.dart';
import 'supabase_bookings_api.dart';

/// The payer's contact, sent to the backend with each booking (never the userId).
class Customer {
  final String name;
  final String phone;
  final String email;

  const Customer({required this.name, required this.phone, required this.email});
}

/// The backend's acknowledgement of a placed booking: its id and the
/// human-friendly reference shown on the receipt.
class SubmittedBooking {
  final String id;
  final String reference;

  const SubmittedBooking({required this.id, required this.reference});
}

/// The submit contract: turn one configured [CartItem] into a placed booking.
abstract class BookingsApi {
  Future<SubmittedBooking> submitDraft(CartItem line, Customer customer);
}

/// The single [BookingsApi] the checkout reads (Supabase), as the seam so it can
/// be overridden with a fake in tests.
final bookingsApiProvider = Provider<BookingsApi>(
  (ref) => SupabaseBookingsApi(ref.watch(supabaseClientProvider)),
);
