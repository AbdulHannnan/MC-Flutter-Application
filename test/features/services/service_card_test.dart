// ServiceCard: renders the service's name, "from" price, rating and duration, and
// fires onTap. Wrapped in a bare MaterialApp (no navigation needed).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/services/services.dart';
import 'package:microcare/src/models/models.dart';

Service _service({double? rating, int duration = 60, String? summary}) => Service(
      id: 'svc_1',
      categoryId: 'cat_1',
      name: 'Split AC Deep Cleaning',
      slug: 'split-ac-deep-cleaning',
      summary: summary,
      basePrice: const Money(amountMinor: 9900, currency: CurrencyCode.aed),
      duration: duration,
      rating: rating,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders name, from-price, rating and duration', (tester) async {
    await tester.pumpWidget(_host(ServiceCard(
      service: _service(rating: 4.8, duration: 60, summary: 'Thorough clean.'),
      onTap: () {},
    )));

    expect(find.text('Split AC Deep Cleaning'), findsOneWidget);
    expect(find.text('Thorough clean.'), findsOneWidget);
    expect(find.text('99.00 AED'), findsOneWidget); // Money.format (RN parity)
    expect(find.text('⭐ 4.8'), findsOneWidget);
    expect(find.text('1 hr'), findsOneWidget); // formatDuration(60)
  });

  testWidgets('hides the duration when it is 0 and the badge when no rating',
      (tester) async {
    await tester.pumpWidget(_host(ServiceCard(service: _service(duration: 0))));

    expect(find.textContaining('min'), findsNothing);
    expect(find.textContaining('hr'), findsNothing);
    expect(find.textContaining('⭐'), findsNothing);
  });

  testWidgets('fires onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(
      ServiceCard(service: _service(), onTap: () => tapped = true),
    ));

    await tester.tap(find.byType(ServiceCard));
    expect(tapped, isTrue);
  });
}
