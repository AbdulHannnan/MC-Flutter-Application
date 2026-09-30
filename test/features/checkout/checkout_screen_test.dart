// The Checkout + Success/Failure screens (Module 14), driven through the real app
// + router (signed in) with a seeded cart. Covers: order summary + total render;
// the empty-cart guard; phone-required validation; and a successful pay landing on
// the confirmation screen with a reference. Payment + bookings run at zero latency.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/app/app_router.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/cart/cart_controller.dart';
import 'package:microcare/src/features/checkout/bookings_api.dart';
import 'package:microcare/src/features/checkout/payment_api.dart';
import 'package:microcare/src/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

int _seq = 0;
CartItem _line() => CartItem(
      id: 'line_${_seq++}',
      serviceId: 'svc_split_clean',
      quantity: 1,
      serviceName: 'Split AC Deep Cleaning',
      unitPrice: _aed(9900),
      location: const BookingLocation(addressText: 'Marina Gate 1'),
      slot: const TimeSlot(
        id: 'slot_1',
        start: '2026-09-01T10:00:00.000',
        end: '2026-09-01T11:00:00.000',
      ),
    );

Widget _app() => ProviderScope(
      overrides: [
        mockAuthApiProvider
            .overrideWithValue(MockAuthApi(latency: Duration.zero)),
        paymentApiProvider
            .overrideWithValue(MockPaymentApi(latency: Duration.zero)),
        bookingsApiProvider
            .overrideWithValue(MockBookingsApi(latency: Duration.zero)),
      ],
      child: const MicrocareApp(),
    );

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MicrocareApp)));

GoRouter _routerOf(WidgetTester tester) =>
    _containerOf(tester).read(routerProvider);

String _loc(WidgetTester tester) =>
    _routerOf(tester).routerDelegate.currentConfiguration.uri.toString();

Future<void> _seedSignedIn() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

/// Sign in, seed the cart with [lines], and go to a [start] route.
Future<ProviderContainer> _boot(
  WidgetTester tester, {
  int lines = 1,
  String start = '/checkout',
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  await _seedSignedIn();
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  final container = _containerOf(tester);
  for (var i = 0; i < lines; i++) {
    container.read(cartProvider.notifier).add(_line());
  }
  _routerOf(tester).go(start);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders the order summary, total and Pay CTA', (tester) async {
    await _boot(tester);
    expect(find.text('Order summary'), findsOneWidget);
    expect(find.text('Split AC Deep Cleaning'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Pay 99.00 AED'), findsOneWidget);
    // Email is prefilled from the session.
    expect(find.text('jane@example.com'), findsOneWidget);
  });

  testWidgets('an empty cart is redirected away from checkout', (tester) async {
    await _boot(tester, lines: 0, start: '/checkout');
    expect(_loc(tester), '/cart');
  });

  testWidgets('Pay with no phone shows a validation error and stays',
      (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Pay 99.00 AED'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a phone number.'), findsOneWidget);
    expect(_loc(tester), '/checkout');
  });

  testWidgets('a valid pay lands on the confirmation screen with a reference',
      (tester) async {
    final container = await _boot(tester);

    await tester.enterText(find.byType(TextField).first, '0501234567');
    await tester.tap(find.text('Pay 99.00 AED'));
    await tester.pumpAndSettle();

    expect(_loc(tester), '/checkout/success');
    expect(find.text('Booking confirmed'), findsOneWidget);
    expect(find.textContaining('MC-'), findsOneWidget); // reference
    expect(container.read(cartProvider), isEmpty); // cart cleared
  });
}
