// End-to-end widget test of the mock-auth gate: from the signed-out Login screen,
// navigate to Sign up, create an account, land on the signed-in home, and log back
// out. Uses a zero-latency mock backend over an empty in-memory store.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sign up → signed-in home → log out', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAuthApiProvider
              .overrideWithValue(MockAuthApi(latency: Duration.zero)),
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

    // Fill the four fields (in order: full name, email, password, confirm).
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Jane Doe');
    await tester.enterText(fields.at(1), 'jane@example.com');
    await tester.enterText(fields.at(2), 'supersecret');
    await tester.enterText(fields.at(3), 'supersecret');

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // Signed in — the home placeholder greets the user.
    expect(find.text('Module 7 ✓  Mock auth'), findsOneWidget);
    expect(find.text('Signed in as jane@example.com'), findsOneWidget);

    // Log out → back to the signed-out Login screen.
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
