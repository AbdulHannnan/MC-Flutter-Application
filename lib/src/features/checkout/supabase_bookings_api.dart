// lib/src/features/checkout/supabase_bookings_api.dart — the booking SUBMIT path
// on SUPABASE Edge Functions. The real replacement for the Express
// POST /api/bookings/draft ([LiveBookingsApi]).
//
// Per cart line the website's proven two-step flow is reproduced:
//   1. create-draft (PUBLIC)   — snapshot the draft, mint the MC-xxxx reference,
//                                carrying source:"app" (hard rule #3).
//   2. finalize-booking (AUTH) — finalize THAT draft in place (keeps its
//                                reference + source), identity from the Supabase
//                                JWT. We pass `bookingId` so the draft's
//                                source:"app" survives (a fresh finalize-create
//                                would not set it).
//
// HARD RULES honoured: source:"app" (create-draft); NO prices are ever sent (the
// functions re-compute + snapshot server-side); NO userId (finalize derives the
// user from the verified token). Field names match the deployed functions exactly
// (confirmed from the booking website's buildBookingPayload): serviceOptionId,
// contactName/contactPhone, flat `address` + `mapUrl`, addons:[{addonId,quantity}],
// scheduledDate (ISO) + scheduledTime (label).
//
// AUTH: finalize-booking requires a signed-in Supabase session — functions.invoke
// attaches the user's access token automatically. So this path must be used with
// AUTH_BACKEND=supabase (config.isSupabaseBookings documents the pairing).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import 'bookings_api.dart';

/// Thrown when a booking Edge Function rejects the submit, carrying the server's
/// message so it can be logged/surfaced. The checkout treats any submit failure
/// as a (post-payment) failure outcome.
class BookingSubmitException implements Exception {
  final String message;
  final int? status;
  const BookingSubmitException(this.message, {this.status});

  @override
  String toString() => 'BookingSubmitException($status): $message';
}

/// A Google Maps link from the pin, matching how the website + backend store it
/// (`…/maps?q=<lat>,<lng>`). Null when there's no pin.
String? buildMapUrl(BookingLocation? location) {
  final coords = location?.coords;
  if (coords == null) return null;
  return 'https://www.google.com/maps?q=${coords.lat},${coords.lng}';
}

/// The slot's local wall-clock as a "HH:mm" label — the SAME format the booking
/// website sends for `scheduledTime`, so web + app rows read identically in the
/// CRM / technician views.
String scheduledTimeLabel(String isoStart) {
  final dt = DateTime.parse(isoStart).toLocal();
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// The fields shared by create-draft and finalize-booking for one line. NEVER
/// includes prices or a userId. `optionId`/`address`/`scheduledDate`/time are
/// required by finalize; they come straight from the configured cart line.
Map<String, dynamic> _baseBookingBody(CartItem line, Customer customer) {
  final slot = line.slot;
  final location = line.location;
  final mapUrl = buildMapUrl(location);
  return {
    'serviceId': line.serviceId,
    if (line.optionId != null) 'serviceOptionId': line.optionId,
    'quantity': line.quantity,
    'contactName': customer.name,
    'contactPhone': customer.phone,
    if (location != null) 'address': location.addressText,
    'mapUrl': ?mapUrl,
    if (slot != null) 'scheduledDate': slot.start, // ISO datetime
    if (slot != null) 'scheduledTime': scheduledTimeLabel(slot.start), // "HH:mm"
    if (line.notes != null && line.notes!.trim().isNotEmpty)
      'notes': line.notes!.trim(),
    'addons': line.addons
        .map((a) => {'addonId': a.id, 'quantity': 1})
        .toList(),
    // NB: no subtotal/total/unitPrice, no userId — server owns pricing + identity.
  };
}

/// The create-draft body: the base plus source:"app" (top-level, lowercase).
Map<String, dynamic> buildCreateDraftBody(CartItem line, Customer customer) => {
      'source': 'app',
      ..._baseBookingBody(line, customer),
    };

/// The finalize-booking body: the base plus the draft id to finalize in place.
Map<String, dynamic> buildFinalizeBody(
  CartItem line,
  Customer customer,
  String bookingId,
) =>
    {
      'bookingId': bookingId,
      ..._baseBookingBody(line, customer),
    };

class SupabaseBookingsApi implements BookingsApi {
  SupabaseBookingsApi(this._sb);

  final SupabaseClient _sb;

  @override
  Future<SubmittedBooking> submitDraft(CartItem line, Customer customer) async {
    // 1. Create the DRAFT (public) — mints the reference, stamps source:"app".
    final draft = await _invoke(
      'create-draft',
      buildCreateDraftBody(line, customer),
    );
    final draftId = draft['id'] as String?;
    if (draftId == null || draftId.isEmpty) {
      throw const BookingSubmitException('The server did not return a draft id.');
    }

    // 2. Finalize THAT draft (auth) — identity from the Supabase JWT, keeps the
    //    reference + source. We trust the finalized row's id + reference.
    final finalized = await _invoke(
      'finalize-booking',
      buildFinalizeBody(line, customer, draftId),
    );
    return SubmittedBooking(
      id: (finalized['id'] ?? draftId).toString(),
      reference: (finalized['reference'] ?? draft['reference'] ?? '').toString(),
    );
  }

  /// Invoke an Edge Function and unwrap the `{ data: <booking> }` envelope.
  /// functions.invoke attaches the `apikey` + the signed-in user's Bearer token
  /// automatically and throws [FunctionException] on a non-2xx response.
  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _sb.functions.invoke(name, body: body);
      final payload = res.data;
      final data = payload is Map<String, dynamic> ? payload['data'] : null;
      if (data is Map<String, dynamic>) return data;
      throw BookingSubmitException(
        'Unexpected response from $name.',
        status: res.status,
      );
    } on FunctionException catch (e) {
      throw BookingSubmitException(_messageFrom(e), status: e.status);
    }
  }

  /// Pull the server's error message out of a [FunctionException]'s body
  /// (`{ error, details }`), falling back to a generic line.
  static String _messageFrom(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'Booking request failed (status ${e.status}).';
  }
}
