// The Home dashboard, driven through the real app + router (signed in). Asserts the
// greeting, the Categories strip and Popular-services list render from the mock
// catalog, and that tapping a service card / the search pill navigates.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/core/widgets/widgets.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/services/services.dart';
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

Future<void> _seedSignedIn() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

void main() {
  testWidgets('renders greeting, categories and popular services',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seedSignedIn();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Hi Jane 👋'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Popular services'), findsOneWidget);
    // Content from the mock seed.
    expect(find.text('AC Cleaning'), findsWidgets); // a category chip
    expect(find.byType(CategoryChip), findsWidgets);
    expect(find.byType(ServiceCard), findsWidgets);
    // Highest-rated service (4.9) leads the popular list.
    expect(find.text('Annual Maintenance Contract'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping a service card opens the service route', (tester) async {
    // A tall surface so the popular list is on-screen (hit-testable) for the tap.
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await _seedSignedIn();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final card = find.byType(ServiceCard).first;
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget); // service detail footer CTA

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping the search pill opens the search route', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seedSignedIn();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search AC services…'));
    await tester.pumpAndSettle();
    expect(find.text('Search services…'), findsOneWidget); // search screen field

    await tester.pumpWidget(const SizedBox());
  });
}
