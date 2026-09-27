// End-to-end widget test of the mock-auth flow through the real router: from the
// signed-out Login screen, navigate to Sign up, create an account, get redirected
// (by the auth guard) to the protected Home, and log back out. The catalog repo is
// mocked (zero latency) so Home's catalog proof doesn't hit the network.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sign up → guard redirects to Home → log out', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
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
      ),
    );
    await tester.pumpAndSettle();

    // Signed out → Login. Go to Sign up.
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    // Fill the four fields (order: full name, email, password, confirm).
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Jane Doe');
    await tester.enterText(fields.at(1), 'jane@example.com');
    await tester.enterText(fields.at(2), 'supersecret');
    await tester.enterText(fields.at(3), 'supersecret');

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // The auth guard redirected the now-signed-in user to Home.
    expect(find.text('Module 8 ✓  Navigation & route guards'), findsOneWidget);
    expect(find.text('Hi Jane 👋'), findsOneWidget);

    // Log out → guard bounces back to the signed-out Login screen.
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    // Unmount so Home's catalog keep-alive Timer is disposed before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
