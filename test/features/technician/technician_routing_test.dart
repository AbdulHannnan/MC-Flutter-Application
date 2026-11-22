// The parallel-auth router guard for the TECHNICIAN session (real backend JWT):
//   • a signed-in technician lands on the staff area, not the customer app, and
//     deep-linking into the customer app bounces back;
//   • a customer cannot reach the technician area;
//   • when nobody is signed in, the technician login is reachable and the staff
//     area bounces to the customer login.
// The technician token store is faked in-memory so no keystore/network is touched;
// a seeded token + cached profile makes the session restore to "signed in".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/app/app_router.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/services/catalog_repository.dart';
import 'package:microcare/src/features/technician/screens/technician_home_screen.dart';
import 'package:microcare/src/features/technician/screens/technician_login_screen.dart';
import 'package:microcare/src/features/technician/technician.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/welcome_gate.dart';

/// In-memory technician token store — no platform keystore in tests.
class _FakeTechStore implements TechnicianTokenStore {
  _FakeTechStore({this.token, this.technician});
  String? token;
  Technician? technician;

  @override
  Future<String?> readToken() async => token;
  @override
  Future<Technician?> readTechnician() async => technician;
  @override
  Future<void> save({required String token, required Technician technician}) async {
    this.token = token;
    this.technician = technician;
  }

  @override
  Future<void> clear() async {
    token = null;
    technician = null;
  }
}

const _sami = Technician(
  id: 'tech_1',
  code: 'MC0001TEC',
  name: 'Sami Tech',
  username: 'sami',
  phone: null,
);

Widget _app({TechnicianTokenStore? techStore}) => ProviderScope(
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
        // Always stub the keystore — an empty fake = signed-out technician.
        technicianTokenStoreProvider
            .overrideWithValue(techStore ?? _FakeTechStore()),
      ],
      child: const MicrocareApp(),
    );

GoRouter _routerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MicrocareApp)))
        .read(routerProvider);

Future<void> _seedCustomer() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

void main() {
  testWidgets('a signed-in technician lands on the staff area', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      _app(techStore: _FakeTechStore(token: 'jwt.abc', technician: _sami)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TechnicianHomeScreen), findsOneWidget);
    expect(find.text('Your work area'), findsOneWidget);
    expect(find.text('Hi Sami 👋'), findsOneWidget);

    // Deep-linking into the customer app bounces back to the staff area.
    _routerOf(tester).go('/cart');
    await tester.pumpAndSettle();
    expect(find.byType(TechnicianHomeScreen), findsOneWidget);
    expect(find.text('Your cart'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a customer cannot reach the technician area', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seedCustomer();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Hi Jane 👋'), findsOneWidget); // customer Home

    _routerOf(tester).go('/technician');
    await tester.pumpAndSettle();
    expect(find.byType(TechnicianHomeScreen), findsNothing);
    expect(find.text('Hi Jane 👋'), findsOneWidget); // bounced back

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('signed out: technician login reachable, staff area bounces to login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget); // customer login

    _routerOf(tester).go('/technician/login');
    await tester.pumpAndSettle();
    expect(find.byType(TechnicianLoginScreen), findsOneWidget);

    // The staff area itself is not reachable signed-out — bounces to customer login.
    _routerOf(tester).go('/technician');
    await tester.pumpAndSettle();
    expect(find.byType(TechnicianHomeScreen), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
