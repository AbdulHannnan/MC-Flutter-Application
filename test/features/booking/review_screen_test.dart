// The Review screen (Module 13), driven through the real app + router (signed in,
// mock catalog) with a fully-assembled draft. Covers: the read-back renders
// Service/Where/When + total; "Add to cart" snapshots the draft and lands on the
// cart; "Pay now" revalidates — a stale slot shows a blocking banner and stays put,
// a clean draft proceeds to checkout.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/app/app_router.dart';
import 'package:microcare/src/core/format/date_time.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/booking/availability_providers.dart';
import 'package:microcare/src/features/booking/availability_repository.dart';
import 'package:microcare/src/features/booking/booking_controller.dart';
import 'package:microcare/src/features/cart/cart_controller.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:microcare/src/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

final _avail = AvailabilityRepository(latency: Duration.zero, demoTaken: false);

Service _service() => Service(
      id: 'svc_split_clean',
      categoryId: 'cat_ac_cleaning',
      name: 'Split AC Deep Cleaning',
      slug: 'split',
      basePrice: _aed(9900),
      duration: 60,
      options: [
        ServiceOption(
            id: 'opt_split_1', name: '1 unit', price: _aed(9900), duration: 60),
      ],
    );

ServiceOption _option([int price = 9900]) =>
    ServiceOption(id: 'opt_split_1', name: '1 unit', price: _aed(price), duration: 60);

TimeSlot _futureSlot() {
  final date = isoDateToString(DateTime.now().add(const Duration(days: 2)));
  return _avail.buildSlots(date).firstWhere((s) => s.isAvailable);
}

TimeSlot _pastSlot() => _avail.buildSlots('2000-01-01').first;

Widget _app() => ProviderScope(
      overrides: [
        mockAuthApiProvider
            .overrideWithValue(MockAuthApi(latency: Duration.zero)),
        catalogRepositoryProvider.overrideWithValue(
          CatalogRepository(
            ApiClient(baseUrl: 'http://localhost:5050'),
            useMock: true,
            mockLatency: Duration.zero,
          ),
        ),
        availabilityRepositoryProvider.overrideWithValue(_avail),
      ],
      child: const MicrocareApp(),
    );

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MicrocareApp)));

GoRouter _routerOf(WidgetTester tester) =>
    _containerOf(tester).read(routerProvider);

String _location(WidgetTester tester) =>
    _routerOf(tester).routerDelegate.currentConfiguration.uri.toString();

Future<void> _seedSignedIn() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

/// Sign in, assemble a full draft (service + option + location + [slot]), and land
/// on the Review screen. Returns the container for assertions.
Future<ProviderContainer> _openReview(
  WidgetTester tester, {
  required TimeSlot slot,
  int optionPrice = 9900,
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
  final ctrl = container.read(bookingDraftProvider.notifier);
  ctrl.start(_service(), _option(optionPrice));
  ctrl.setLocation(
      const BookingLocation(addressText: 'Marina Gate 1', area: 'Dubai Marina'));
  ctrl.setSlot(slot);

  _routerOf(tester).go('/booking/review');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders the read-back and total', (tester) async {
    await _openReview(tester, slot: _futureSlot());

    expect(find.text('Service'), findsOneWidget);
    expect(find.text('Where'), findsOneWidget);
    expect(find.text('When'), findsOneWidget);
    expect(find.text('Split AC Deep Cleaning'), findsOneWidget);
    expect(find.text('Dubai Marina'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Add to cart'), findsOneWidget);
    expect(find.text('Pay now'), findsOneWidget);
    // Total = unit 9900, shown as the footer total.
    expect(find.text('99.00 AED'), findsWidgets);
  });

  testWidgets('Add to cart snapshots the draft and lands on the cart',
      (tester) async {
    final container = await _openReview(tester, slot: _futureSlot());

    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();

    expect(container.read(cartProvider), hasLength(1));
    expect(container.read(bookingDraftProvider).hasService, isFalse); // reset
    expect(_location(tester), '/cart');
  });

  testWidgets('Pay now on a stale slot shows a blocking banner and stays',
      (tester) async {
    final container = await _openReview(tester, slot: _pastSlot());

    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(container.read(cartProvider), isEmpty);
    expect(_location(tester), '/booking/review');
  });

  testWidgets('Pay now on a clean draft proceeds to checkout', (tester) async {
    final container = await _openReview(tester, slot: _futureSlot());

    await tester.tap(find.text('Pay now'));
    await tester.pumpAndSettle();

    expect(container.read(cartProvider), hasLength(1));
    expect(_location(tester), '/checkout');
  });
}
