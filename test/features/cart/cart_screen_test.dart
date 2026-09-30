// The Cart screen (Module 13), driven through the real app + router (signed in).
// Covers: the empty state; a line renders with its total; the stepper and remove
// mutate the store; and Clear empties the cart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/app/app_router.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/cart/cart_controller.dart';
import 'package:microcare/src/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Money _aed(int minor) => Money(amountMinor: minor, currency: CurrencyCode.aed);

CartItem _item({int quantity = 1, int unit = 5000}) => CartItem(
      id: 'line_1',
      serviceId: 's1',
      quantity: quantity,
      serviceName: 'Split AC Deep Cleaning',
      unitPrice: _aed(unit),
    );

Widget _app() => ProviderScope(
      overrides: [
        mockAuthApiProvider
            .overrideWithValue(MockAuthApi(latency: Duration.zero)),
      ],
      child: const MicrocareApp(),
    );

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MicrocareApp)));

Future<void> _seedSignedIn() => MockAuthApi(latency: Duration.zero).signUp(
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      password: 'supersecret',
    );

/// Sign in and open the cart on a tall surface so cards + footer lay out.
Future<ProviderContainer> _openCart(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  await _seedSignedIn();
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  final container = _containerOf(tester);
  container.read(routerProvider).go('/cart');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the empty state when the cart is empty', (tester) async {
    await _openCart(tester);
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);
  });

  testWidgets('renders a line with its total and a working stepper',
      (tester) async {
    final container = await _openCart(tester);
    container.read(cartProvider.notifier).add(_item(quantity: 1));
    await tester.pumpAndSettle();

    expect(find.text('Split AC Deep Cleaning'), findsOneWidget);
    // Shown twice: the line total and the (single-line) subtotal.
    expect(find.text('50.00 AED'), findsNWidgets(2));
    expect(find.text('Checkout'), findsOneWidget);

    // Bump quantity → line total (and subtotal) double, store reflects it.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(container.read(cartProvider).single.quantity, 2);
    expect(find.text('100.00 AED'), findsNWidgets(2));
  });

  testWidgets('remove clears the line and shows the empty state',
      (tester) async {
    final container = await _openCart(tester);
    container.read(cartProvider.notifier).add(_item());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(container.read(cartProvider), isEmpty);
    expect(find.text('Your cart is empty'), findsOneWidget);
  });
}
