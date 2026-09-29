// The router's auth guard + stack navigation:
//   • signed OUT: a deep link to a protected route bounces to /sign-in.
//   • signed IN:  visiting an auth route bounces to Home; a protected route pushes
//                 and pops back; a booking step with no draft bounces home.
// Uses zero-latency mock auth + a mock catalog repo so Home renders without a
// network. Each test unmounts at the end so Home's catalog keep-alive Timer (held
// by the ProviderScope's container) is disposed before the pending-timer check.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/app/app_router.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:microcare/src/features/services/screens/categories_screen.dart';
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

GoRouter _routerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MicrocareApp)))
        .read(routerProvider);

/// Seed a signed-in session by creating an account in the (shared) mock store.
Future<void> _seedSignedIn() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

void main() {
  testWidgets('signed-out deep link to a protected route bounces to login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget); // landed on login

    _routerOf(tester).go('/cart');
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget); // bounced back to login
    expect(find.text('Your cart'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signed-in visit to an auth route bounces home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seedSignedIn();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Hi Jane 👋'), findsOneWidget); // restored to Home

    _routerOf(tester).go('/sign-in');
    await tester.pumpAndSettle();
    expect(find.text('Hi Jane 👋'), findsOneWidget); // bounced back home
    expect(find.text('Welcome back'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pushes a protected route and pops back to Home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seedSignedIn();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // "See all" pushes the categories route.
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Hi Jane 👋'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a booking step with no draft bounces home (guard pattern)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seedSignedIn();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    _routerOf(tester).go('/booking/location');
    await tester.pumpAndSettle();
    expect(find.text('Hi Jane 👋'), findsOneWidget); // bounced by the draft guard

    await tester.pumpWidget(const SizedBox());
  });
}
