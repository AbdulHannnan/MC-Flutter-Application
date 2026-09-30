// The Location + Schedule steps (Module 12), driven through the real app + router
// (signed in, mock catalog) with a started booking draft. Covers: the location
// step's Continue gate + commit-to-draft, and the schedule step's slot selection +
// advance. Slot fetching runs at zero cosmetic latency.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/app/app_router.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/booking/booking.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:microcare/src/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        availabilityRepositoryProvider.overrideWithValue(
          AvailabilityRepository(latency: Duration.zero, demoTaken: false),
        ),
      ],
      child: const MicrocareApp(),
    );

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MicrocareApp)));

BookingDraft _draft(WidgetTester tester) =>
    _containerOf(tester).read(bookingDraftProvider);

Future<void> _seedSignedIn() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

/// Sign in and land on Home, then START a booking draft for a seed service so the
/// booking-flow guard admits the Location/Schedule routes. Returns the container's
/// draft controller for further seeding.
Future<BookingDraftController> _bootWithDraft(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  await _seedSignedIn();
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  final container = _containerOf(tester);
  final service =
      await container.read(catalogRepositoryProvider).getServiceById('svc_split_clean');
  final ctrl = container.read(bookingDraftProvider.notifier);
  ctrl.start(service);
  return ctrl;
}

void main() {
  testWidgets('location: Continue is gated until an area/address is set',
      (tester) async {
    await _bootWithDraft(tester);
    _containerOf(tester).read(routerProvider).go('/booking/location');
    await tester.pumpAndSettle();

    expect(find.text('Where should we come?'), findsOneWidget);
    // No address/area yet → the hint shows and the draft has no location.
    expect(find.text('Enter an address or pick an area to continue.'),
        findsOneWidget);

    // Tapping Continue while gated does nothing.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(_draft(tester).location, isNull);
    expect(find.text('Where should we come?'), findsOneWidget); // still here
  });

  testWidgets('location: picking an area commits it and advances to schedule',
      (tester) async {
    await _bootWithDraft(tester);
    _containerOf(tester).read(routerProvider).go('/booking/location');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dubai Marina'));
    await tester.pumpAndSettle();
    // The gate hint is gone once an area is chosen.
    expect(find.text('Enter an address or pick an area to continue.'),
        findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Location is committed to the draft and we've advanced to the schedule step.
    expect(_draft(tester).location?.area, 'Dubai Marina');
    expect(find.text('Choose a date'), findsOneWidget);
  });

  testWidgets('schedule: no time picker until a day is chosen', (tester) async {
    final ctrl = await _bootWithDraft(tester);
    ctrl.setLocation(const BookingLocation(
        addressText: 'Marina Gate 1', area: 'Dubai Marina'));
    _containerOf(tester).read(routerProvider).go('/booking/schedule');
    await tester.pumpAndSettle();

    expect(find.text('Choose a date'), findsOneWidget);
    expect(find.text('Choose a time'), findsNothing);
    expect(find.text('Pick a day to continue.'), findsOneWidget);
  });

  testWidgets('schedule: selecting a slot enables Continue and advances to review',
      (tester) async {
    final ctrl = await _bootWithDraft(tester);
    ctrl.setLocation(const BookingLocation(
        addressText: 'Marina Gate 1', area: 'Dubai Marina'));
    // Seed a far-future day (all slots available) so the calendar opens on it and
    // the time grid renders deterministically.
    ctrl.setSlot(TimeSlot(
      id: 'slot_2030-06-15_09',
      start: DateTime(2030, 6, 15, 9).toIso8601String(),
      end: DateTime(2030, 6, 15, 10).toIso8601String(),
    ));

    _containerOf(tester).read(routerProvider).go('/booking/schedule');
    await tester.pumpAndSettle();

    // The time picker is shown for the seeded day, with the summary + a slot chosen.
    expect(find.text('Choose a time'), findsOneWidget);
    expect(find.text('Saturday, June 15'), findsOneWidget); // footer Date summary

    // Pick a different available slot; the draft updates.
    await tester.tap(find.text('11:00 AM'));
    await tester.pumpAndSettle();
    expect(_draft(tester).slot?.id, 'slot_2030-06-15_11');

    // Continue advances to the (still-stubbed) Review step.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // The Review placeholder renders its title in both the AppBar and the body.
    expect(find.text('Review booking'), findsWidgets);
  });
}
