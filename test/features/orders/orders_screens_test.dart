// The Orders screens (Module 15), driven through the real app + router (signed
// in). Covers: the empty state; the My-Bookings list renders a booking card;
// tapping a card opens its receipt; the receipt lays out schedule / service /
// payment; and an unknown id shows the not-found state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/app/app_router.dart';
import 'package:microcare/src/features/auth/auth.dart';
import 'package:microcare/src/features/orders/orders_repository.dart';
import 'package:microcare/src/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

TimeSlot _slot() => const TimeSlot(
      id: 'slot_1',
      start: '2026-10-05T09:00:00.000Z',
      end: '2026-10-05T10:00:00.000Z',
      isAvailable: false,
    );

Booking _booking(String userId) => Booking(
      id: 'bk_1',
      reference: 'MC-2K4F9',
      userId: userId,
      status: BookingStatus.confirmed,
      items: [
        CartItem(
          id: 'line_1',
          serviceId: 's1',
          quantity: 1,
          serviceName: 'Split AC Deep Cleaning',
          optionName: 'Up to 2 units',
          unitPrice: _aed(15000),
          addons: [CartAddon(id: 'a1', name: 'Gas top-up', price: _aed(5000))],
        ),
      ],
      slot: _slot(),
      location: const BookingLocation(
          addressText: 'Marina Walk, Tower 1', area: 'Dubai Marina'),
      subtotal: _aed(20000),
      total: _aed(20000),
      notes: 'Call on arrival',
      createdAt: '2026-10-01T12:00:00.000Z',
      paymentId: 'txn_abc123',
    );

Widget _app() => ProviderScope(
      overrides: [
        mockAuthApiProvider
            .overrideWithValue(MockAuthApi(latency: Duration.zero)),
      ],
      child: const MicrocareApp(),
    );

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MicrocareApp)));

Future<AuthUser> _seedSignedIn() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

/// Sign in, seed the bookings built from the signed-in user's id, then open
/// [path] on a tall surface. Returns the container (session already restored).
Future<ProviderContainer> _open(
  WidgetTester tester, {
  List<Booking> Function(String userId)? bookingsFor,
  String path = '/orders',
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  // The id persisted here is the one the session restores on boot, so bookings
  // seeded against it pass the provider's user scope.
  final user = await _seedSignedIn();
  final bookings = bookingsFor?.call(user.id) ?? const [];
  if (bookings.isNotEmpty) await OrdersRepository().addAll(bookings);

  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  final container = _containerOf(tester);
  container.read(routerProvider).go(path);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the empty state when there are no bookings',
      (tester) async {
    await _open(tester);
    expect(find.text('No bookings yet'), findsOneWidget);
    expect(find.text('Browse services'), findsOneWidget);
  });

  testWidgets('lists a booking card with its reference, service and total',
      (tester) async {
    await _open(tester, bookingsFor: (id) => [_booking(id)]);

    expect(find.text('MC-2K4F9'), findsOneWidget);
    expect(find.text('Split AC Deep Cleaning'), findsOneWidget);
    expect(find.text('200.00 AED'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('tapping a booking opens its receipt', (tester) async {
    await _open(tester, bookingsFor: (id) => [_booking(id)]);
    await tester.tap(find.text('Split AC Deep Cleaning'));
    await tester.pumpAndSettle();

    // Receipt header + sections.
    expect(find.text('Booking receipt'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('Total paid'), findsOneWidget);
    expect(find.text('txn_abc123'), findsOneWidget);
    expect(find.text('Call on arrival'), findsOneWidget);
  });

  testWidgets('an unknown booking id shows the not-found state',
      (tester) async {
    await _open(tester, path: '/orders/does-not-exist');
    expect(find.text('Booking not found'), findsOneWidget);
    expect(find.text('Back to bookings'), findsOneWidget);
  });
}
