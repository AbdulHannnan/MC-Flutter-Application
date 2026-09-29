// Module 10 browse screens, driven through the real app + router (signed in) with
// the mock catalog (5 categories / 13 services):
//   • Categories screen lists every category row.
//   • Tapping a category row pushes that category's services.
//   • Category Services screen titles itself with the category name + lists it.
//   • Search filters by debounced text and by category chip, with a result count.
// Each test unmounts at the end so Home's catalog keep-alive Timer is disposed
// before the pending-timer check.

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
import 'package:microcare/src/features/services/screens/category_services_screen.dart';
import 'package:microcare/src/features/services/widgets/service_card.dart';
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

Future<void> _seedSignedIn() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

/// Sign in and land on Home, ready to navigate. Uses a tall surface so the
/// (lazily built) list items further down a screen are laid out and hit-testable.
Future<void> _pumpSignedIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  await _seedSignedIn();
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Categories screen lists every category', (tester) async {
    await _pumpSignedIn(tester);

    _routerOf(tester).go('/categories');
    await tester.pumpAndSettle();

    expect(find.byType(CategoriesScreen), findsOneWidget);
    // All five mock categories render as rows.
    expect(find.text('AC Cleaning'), findsOneWidget);
    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.text('AC Installation'), findsOneWidget);
    expect(find.text('AC Maintenance'), findsOneWidget);
    expect(find.text('Duct & Air Quality'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping a category row opens its services', (tester) async {
    await _pumpSignedIn(tester);

    _routerOf(tester).go('/categories');
    await tester.pumpAndSettle();

    await tester.tap(find.text('AC Cleaning'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryServicesScreen), findsOneWidget);
    // The three services in cat_ac_cleaning.
    expect(find.text('Split AC Deep Cleaning'), findsOneWidget);
    expect(find.text('Window AC Cleaning'), findsOneWidget);
    expect(find.text('Central / Ducted AC Cleaning'), findsOneWidget);
    // A service from another category is not listed here.
    expect(find.text('Compressor Repair'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Category Services titles itself and lists that category',
      (tester) async {
    await _pumpSignedIn(tester);

    _routerOf(tester).go('/category/cat_ac_repair');
    await tester.pumpAndSettle();

    // AppBar title = category name.
    expect(find.text('AC Repair'), findsOneWidget);
    expect(find.text('Compressor Repair'), findsOneWidget);
    expect(find.byType(ServiceCard), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Search filters by debounced text', (tester) async {
    await _pumpSignedIn(tester);

    _routerOf(tester).go('/search');
    await tester.pumpAndSettle();

    // With an empty box everything is listed (browse-everything).
    expect(find.text('Split AC Deep Cleaning'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'compressor');
    // pumpAndSettle doesn't wait on a bare Timer, so advance past the 300ms
    // debounce explicitly, then settle the refetch.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Compressor Repair'), findsOneWidget);
    expect(find.text('Split AC Deep Cleaning'), findsNothing);
    expect(find.textContaining('result'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Search category chip narrows results with a count',
      (tester) async {
    await _pumpSignedIn(tester);

    _routerOf(tester).go('/search');
    await tester.pumpAndSettle();

    // Tap the "AC Cleaning" filter chip → the 3 cleaning services.
    await tester.tap(find.text('AC Cleaning'));
    await tester.pumpAndSettle();

    expect(find.text('3 results'), findsOneWidget);
    expect(find.text('Split AC Deep Cleaning'), findsOneWidget);
    expect(find.text('Compressor Repair'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
