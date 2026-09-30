// lib/src/features/checkout/bookings_api.dart — the BOOKING SUBMIT seam. Dart
// port of the RN app's bookings API (`createBooking` → POST /api/bookings/draft).
//
// This is the ONE place the app talks to the real backend for writes. Per cart
// line, it sends the draft body the user confirmed for Module 14:
//   { source:"app", serviceId, optionId?, addonIds[], quantity,
//     scheduledDate, scheduledTime, location{addressText,area?,coords?},
//     customer{name,phone,email}, notes? }
// HARD RULES honoured: `source:"app"` is top-level + lowercase (rule #3); NO
// prices are ever sent (the server computes them — rule #3); NO `userId` is sent.
//
// ⚠️ FIELD-NAME SEAM: the exact wire field names were assembled from the README
// constraints + the documented `scheduledDate`/`scheduledTime` shape, not copied
// from a live contract. If the backend names differ, [_buildBody] is the single
// spot to adjust — nothing else in the app changes.
//
// TWO IMPLEMENTATIONS, chosen by BOOKINGS_MODE (rule §config):
//   • live → POST to the backend, return the server's booking id + reference.
//   • mock → no server; mint a local id + reference so the flow works offline.
// (Order HISTORY is always local — see features/orders — regardless of this.)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/format/date_time.dart';
import '../../core/network/api_client.dart';
import '../../models/models.dart';

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

/// Build the `POST /api/bookings/draft` body for one line. Shared by both
/// implementations (the mock echoes it back) so the wire shape lives in one place.
Map<String, dynamic> buildDraftBody(CartItem line, Customer customer) {
  final slot = line.slot;
  final location = line.location;
  return {
    'source': 'app', // top-level, lowercase (rule #3)
    'serviceId': line.serviceId,
    if (line.optionId != null) 'optionId': line.optionId,
    'addonIds': line.addons.map((a) => a.id).toList(),
    'quantity': line.quantity,
    if (slot != null) 'scheduledDate': slot.start, // ISO datetime
    if (slot != null) 'scheduledTime': formatTime(slot.start), // "10:00 AM"
    if (location != null)
      'location': {
        'addressText': location.addressText,
        if (location.area != null) 'area': location.area,
        if (location.coords != null)
          'coords': {'lat': location.coords!.lat, 'lng': location.coords!.lng},
      },
    'customer': {
      'name': customer.name,
      'phone': customer.phone,
      'email': customer.email,
    },
    if (line.notes != null) 'notes': line.notes,
    // NB: NO unitPrice / total / userId — the server owns pricing and identity.
  };
}

/// Live path: POST the draft and read back the server's booking id + reference.
class LiveBookingsApi implements BookingsApi {
  LiveBookingsApi(this._api);

  final ApiClient _api;

  @override
  Future<SubmittedBooking> submitDraft(CartItem line, Customer customer) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/api/bookings/draft',
      body: buildDraftBody(line, customer),
    );
    return SubmittedBooking(
      id: (data['id'] ?? data['bookingId'] ?? '').toString(),
      reference: (data['reference'] ?? data['ref'] ?? data['id'] ?? '').toString(),
    );
  }
}

/// Mock path: no server. Mint a local id + reference so checkout works offline.
class MockBookingsApi implements BookingsApi {
  MockBookingsApi({this.latency = const Duration(milliseconds: 300)});

  final Duration latency;
  int _seq = 0;

  @override
  Future<SubmittedBooking> submitDraft(CartItem line, Customer customer) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final n = DateTime.now().millisecondsSinceEpoch + _seq++;
    return SubmittedBooking(
      id: 'bk_$n',
      reference: 'MC-${n.toRadixString(36).toUpperCase().substring(0, 5)}',
    );
  }
}

/// The single [BookingsApi] the checkout reads. Live unless BOOKINGS_MODE=mock.
final bookingsApiProvider = Provider<BookingsApi>((ref) {
  if (config.isMockBookings) return MockBookingsApi();
  return LiveBookingsApi(ref.read(apiClientProvider));
});
