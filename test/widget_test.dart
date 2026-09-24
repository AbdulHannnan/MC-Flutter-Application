// Smoke test for Module 1: the app boots and renders the placeholder home.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';

void main() {
  testWidgets('App boots to the Microcare placeholder screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MicrocareApp()));

    expect(find.text('Microcare'), findsOneWidget);
    expect(find.text('AC servicing & booking — Dubai'), findsOneWidget);
    expect(find.byIcon(Icons.ac_unit), findsOneWidget);
  });
}
