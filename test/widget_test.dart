// Smoke test: the app boots and renders the placeholder home (now the Module 6
// catalog proof). The catalog repository is overridden with the zero-latency mock
// seed so the boot screen loads instantly with no network — and the tree is
// unmounted at the end so the cache's keep-alive timer doesn't outlive the test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/features/services/services.dart';

void main() {
  testWidgets('App boots to the Microcare placeholder screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    // Let the catalog future resolve.
    await tester.pump();

    expect(find.text('Microcare'), findsOneWidget);
    expect(find.text('AC servicing & booking — Dubai'), findsOneWidget);
    expect(find.byIcon(Icons.ac_unit), findsOneWidget);
    // The catalog proof rendered service rows from the seed.
    expect(find.text('Module 6 ✓  Catalog data layer'), findsOneWidget);

    // Unmount so the cache's keep-alive Timer is disposed before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
