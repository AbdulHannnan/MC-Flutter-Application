// Smoke test: with no saved session, the app boots through the auth gate to the
// signed-out Login screen. (An empty mock store makes session restore resolve to
// "signed out" with no real platform storage.)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App boots to the Login screen when signed out', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: MicrocareApp()));
    // Let the async session restore resolve (splash → signed out → AuthFlow).
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in to manage your bookings.'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
