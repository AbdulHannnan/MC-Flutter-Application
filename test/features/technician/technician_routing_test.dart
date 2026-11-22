// The role-aware router guard:
//   • a TECHNICIAN account lands on the technician area, not the customer app;
//   • a technician is kept OUT of customer routes (a deep link bounces back);
//   • a CUSTOMER is kept OUT of the technician area.
// Uses zero-latency mock auth + a mock catalog repo so screens render without a
// network, and skips the cold-start welcome splash.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/app/app_router.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/auth/auth.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:microcare/src/features/technician/screens/technician_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/welcome_gate.dart';

Widget _app() => ProviderScope(
      overrides: [
        skipWelcomeSplash,
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

GoRouter _routerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MicrocareApp)))
        .read(routerProvider);

/// Seed a signed-in account of the given [role] in the (shared) mock store.
Future<void> _seedSignedIn(UserRole role) =>
    MockAuthApi(latency: Duration.zero).signUp(
      fullName: role == UserRole.technician ? 'Sami Tech' : 'Jane Doe',
      email: role == UserRole.technician ? 'sami@microcare.ae' : 'jane@example.com',
      password: 'supersecret',
      role: role,
    );

void main() {
  testWidgets('a technician lands on the technician area, not the customer app',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seedSignedIn(UserRole.technician);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(TechnicianHomeScreen), findsOneWidget);
    expect(find.text('Your work area'), findsOneWidget);
    expect(find.text('Hi Sami 👋'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a technician deep-linking into the customer app bounces back',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seedSignedIn(UserRole.technician);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    _routerOf(tester).go('/cart');
    await tester.pumpAndSettle();

    // Still in the technician area; the customer cart never renders.
    expect(find.byType(TechnicianHomeScreen), findsOneWidget);
    expect(find.text('Your cart'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a customer cannot reach the technician area', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seedSignedIn(UserRole.customer);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Hi Jane 👋'), findsOneWidget); // customer Home

    _routerOf(tester).go('/technician');
    await tester.pumpAndSettle();

    // Bounced back to the customer Home; the staff area never renders.
    expect(find.byType(TechnicianHomeScreen), findsNothing);
    expect(find.text('Hi Jane 👋'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
