// Smoke/behaviour tests for the Module 5 UI primitives: they render, apply the
// design tokens, and (for AppButton) honour the disabled/loading contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/theme/theme.dart';
import 'package:microcare/src/core/widgets/widgets.dart';
import 'package:microcare/src/models/models.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('AppText renders its data with the variant style', (tester) async {
    await tester.pumpWidget(_host(
      const AppText('Hello', variant: AppTextVariant.h2),
    ));
    final text = tester.widget<Text>(find.text('Hello'));
    expect(text.style?.fontSize, AppFontSizes.title);
    expect(text.style?.color, AppColors.text);
  });

  testWidgets('AppButton fires onPressed when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      AppButton(label: 'Go', onPressed: () => taps++),
    ));
    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });

  testWidgets('AppButton with null onPressed does not fire', (tester) async {
    await tester.pumpWidget(_host(const AppButton(label: 'Nope')));
    await tester.tap(find.text('Nope'));
    expect(find.text('Nope'), findsOneWidget); // still there, no crash
  });

  testWidgets('AppButton loading shows a spinner and blocks presses',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      AppButton(label: 'Save', loading: true, onPressed: () => taps++),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing); // label replaced by spinner
    await tester.tap(find.byType(CircularProgressIndicator));
    expect(taps, 0);
  });

  testWidgets('StatusPill shows the human label for a status', (tester) async {
    await tester.pumpWidget(_host(
      const StatusPill(status: BookingStatus.confirmed),
    ));
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('AppCard renders its child', (tester) async {
    await tester.pumpWidget(_host(
      const AppCard(child: AppText('Inside')),
    ));
    expect(find.text('Inside'), findsOneWidget);
  });
}
