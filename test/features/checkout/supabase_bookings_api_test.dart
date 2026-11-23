// The Supabase booking-submit path. Two halves:
//  1. The request-body builders (pure) — field names must match the deployed Edge
//     Functions EXACTLY (confirmed from the booking website): source:"app" on the
//     draft, serviceOptionId (not optionId), flat address + mapUrl, contactName/
//     Phone, addons:[{addonId,quantity}], scheduledDate (ISO) + scheduledTime
//     ("HH:mm"), and NEVER a price or userId.
//  2. The two-step flow (create-draft → finalize-booking) via an injected mock
//     http client on SupabaseClient: finalize must carry the draft's bookingId,
//     and the returned SubmittedBooking comes from the finalized row.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:microcare/src/features/checkout/bookings_api.dart';
import 'package:microcare/src/features/checkout/supabase_bookings_api.dart';
import 'package:microcare/src/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

CartItem _line() => CartItem(
      id: 'line_1',
      serviceId: 'svc_split_clean',
      optionId: 'opt_split_1',
      quantity: 2,
      serviceName: 'Split AC Deep Cleaning',
      optionName: '1 unit',
      unitPrice: _aed(9900),
      addons: [CartAddon(id: 'addon_gas', name: 'Gas top-up', price: _aed(2000))],
      location: const BookingLocation(
        addressText: 'Marina Gate 1',
        area: 'Dubai Marina',
        coords: LatLng(lat: 25.07, lng: 55.13),
      ),
      // 10:00 local — asserted as "10:00" (HH:mm), the website's format.
      slot: const TimeSlot(
        id: 'slot_1',
        start: '2026-09-01T10:00:00.000',
        end: '2026-09-01T11:00:00.000',
      ),
      notes: 'Ring the bell twice',
    );

const _customer = Customer(
  name: 'Jane Doe',
  phone: '0501234567',
  email: 'jane@example.com',
);

void main() {
  group('buildCreateDraftBody', () {
    test('carries source:"app" and the renamed/flat fields, no money/userId', () {
      final body = buildCreateDraftBody(_line(), _customer);

      expect(body['source'], 'app');
      expect(body['serviceId'], 'svc_split_clean');
      expect(body['serviceOptionId'], 'opt_split_1'); // renamed from optionId
      expect(body.containsKey('optionId'), isFalse);
      expect(body['quantity'], 2);
      expect(body['contactName'], 'Jane Doe');
      expect(body['contactPhone'], '0501234567');
      expect(body['address'], 'Marina Gate 1'); // flat, not a nested object
      expect(body['mapUrl'], 'https://www.google.com/maps?q=25.07,55.13');
      expect(body['scheduledDate'], '2026-09-01T10:00:00.000');
      expect(body['scheduledTime'], '10:00'); // HH:mm (website format)
      expect(body['notes'], 'Ring the bell twice');
      expect(body['addons'], [
        {'addonId': 'addon_gas', 'quantity': 1},
      ]);

      // Hard rules: never any price, total, or userId / email.
      for (final k in const [
        'subtotal', 'total', 'unitPrice', 'price', 'userId',
        'customer', 'location', 'email',
      ]) {
        expect(body.containsKey(k), isFalse, reason: 'must not send $k');
      }
    });

    test('omits optional fields cleanly when absent', () {
      final bare = CartItem(
        id: 'l2',
        serviceId: 'svc',
        quantity: 1,
        serviceName: 'S',
        unitPrice: _aed(1000),
        // no option, no location/coords, no slot, no notes, no addons
      );
      final body = buildCreateDraftBody(bare, _customer);
      expect(body.containsKey('serviceOptionId'), isFalse);
      expect(body.containsKey('address'), isFalse);
      expect(body.containsKey('mapUrl'), isFalse);
      expect(body.containsKey('scheduledDate'), isFalse);
      expect(body.containsKey('notes'), isFalse);
      expect(body['addons'], isEmpty);
    });
  });

  group('buildFinalizeBody', () {
    test('adds bookingId and carries NO source (draft keeps source:"app")', () {
      final body = buildFinalizeBody(_line(), _customer, 'draft_123');
      expect(body['bookingId'], 'draft_123');
      expect(body.containsKey('source'), isFalse);
      // Required finalize fields present.
      for (final k in const [
        'serviceId', 'serviceOptionId', 'contactName', 'contactPhone',
        'address', 'scheduledDate', 'scheduledTime',
      ]) {
        expect(body.containsKey(k), isTrue, reason: 'finalize requires $k');
      }
    });
  });

  group('helpers', () {
    test('buildMapUrl is null without a pin', () {
      expect(buildMapUrl(const BookingLocation(addressText: 'x')), isNull);
    });
    test('scheduledTimeLabel formats local wall-clock as HH:mm', () {
      expect(scheduledTimeLabel('2026-09-01T09:05:00.000'), '09:05');
      expect(scheduledTimeLabel('2026-09-01T16:00:00.000'), '16:00');
    });
  });

  group('SupabaseBookingsApi flow', () {
    // Build an api whose SupabaseClient routes Edge Function calls to [handler],
    // and records the decoded request body of each by function name.
    (SupabaseBookingsApi, Map<String, Map<String, dynamic>>) harness(
      http.Response Function(String fn, Map<String, dynamic> body) handler,
    ) {
      final seen = <String, Map<String, dynamic>>{};
      final mock = MockClient((request) async {
        final fn = request.url.pathSegments.last; // .../functions/v1/<fn>
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        seen[fn] = body;
        return handler(fn, body);
      });
      final client =
          SupabaseClient('http://localhost', 'test-key', httpClient: mock);
      return (SupabaseBookingsApi(client), seen);
    }

    http.Response ok(Object data, http.BaseRequest req) => http.Response(
          jsonEncode({'data': data}),
          200,
          request: req,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    test('create-draft then finalize-booking carrying the draft id', () async {
      late Map<String, dynamic> finalizeBody;
      final (api, seen) = harness((fn, body) {
        // Rebuild a minimal request just to satisfy http.Response.request.
        final req = http.Request('POST', Uri.parse('http://localhost/$fn'));
        if (fn == 'create-draft') {
          return ok({'id': 'draft_abc', 'reference': 'MC-0001AH'}, req);
        }
        finalizeBody = body;
        return ok({'id': 'draft_abc', 'reference': 'MC-0001AH'}, req);
      });

      final result = await api.submitDraft(_line(), _customer);

      // Both functions were called, in order, and finalize carried the draft id.
      expect(seen.keys, containsAll(['create-draft', 'finalize-booking']));
      expect(seen['create-draft']!['source'], 'app');
      expect(finalizeBody['bookingId'], 'draft_abc');
      // The returned booking is the finalized row.
      expect(result.id, 'draft_abc');
      expect(result.reference, 'MC-0001AH');
    });

    test('a function error becomes a BookingSubmitException', () async {
      final (api, _) = harness((fn, body) {
        final req = http.Request('POST', Uri.parse('http://localhost/$fn'));
        return http.Response(
          jsonEncode({'error': 'Validation failed.'}),
          422,
          request: req,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await expectLater(
        api.submitDraft(_line(), _customer),
        throwsA(isA<BookingSubmitException>()),
      );
    });
  });
}
