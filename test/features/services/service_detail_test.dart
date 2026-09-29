// The Service Detail screen (Module 11), driven through the real app + router
// (signed in) with the mock catalog. Covers: it renders a service with options +
// add-ons; the pinned footer total reacts to selections; and Continue starts the
// booking draft and advances to the (guarded) Location step.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/app/app_router.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/booking/booking.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
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
      ],
      child: const MicrocareApp(),
    );

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MicrocareApp)));

GoRouter _routerOf(WidgetTester tester) =>
    _containerOf(tester).read(routerProvider);

Future<void> _seedSignedIn() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

/// Sign in, land on Home, then open a service detail. Uses a tall surface so the
/// option/add-on rows are laid out and tappable.
Future<void> _openService(WidgetTester tester, String id) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  await _seedSignedIn();
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  _routerOf(tester).go('/service/$id');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a service with options and add-ons', (tester) async {
    await _openService(tester, 'svc_split_clean');

    expect(find.text('Choose an option'), findsOneWidget);
    expect(find.text('Add extras'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    // Options + add-ons from the seed.
    expect(find.text('1 unit'), findsOneWidget);
    expect(find.text('2 units'), findsOneWidget);
    expect(find.text('Deep coil clean'), findsOneWidget);
    // No add-ons ticked yet, options exist → footer caption "Selected".
    expect(find.text('Selected'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ticking an add-on updates the footer caption', (tester) async {
    await _openService(tester, 'svc_split_clean');

    await tester.tap(find.text('Deep coil clean'));
    await tester.pumpAndSettle();
    expect(find.text('Total · 1 extra'), findsOneWidget);

    await tester.tap(find.text('Anti-bacterial treatment'));
    await tester.pumpAndSettle();
    expect(find.text('Total · 2 extras'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Continue starts the draft and advances to Location',
      (tester) async {
    await _openService(tester, 'svc_split_clean');

    // Choose the second option, then continue.
    await tester.tap(find.text('2 units'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Draft-guard allowed the Location step (a service is now configured).
    expect(find.text('Arrives in Module 12.'), findsOneWidget);

    // The draft holds the started service + chosen option.
    final draft = _containerOf(tester).read(bookingDraftProvider);
    expect(draft.service?.id, 'svc_split_clean');
    expect(draft.option?.id, 'opt_split_2');

    await tester.pumpWidget(const SizedBox());
  });
}
