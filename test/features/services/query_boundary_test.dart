// QueryBoundary: the four-way branch on an AsyncValue — loading, error (+retry),
// empty, and data (with an optional derived-items override).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/services/services.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

QueryBoundary<String> _boundary(
  AsyncValue<List<String>> query, {
  List<String>? items,
  VoidCallback? onRetry,
}) =>
    QueryBoundary<String>(
      query: query,
      items: items,
      emptyLabel: 'Nothing here.',
      onRetry: onRetry,
      builder: (list) => Column(children: [for (final s in list) Text(s)]),
    );

void main() {
  testWidgets('loading shows a spinner', (tester) async {
    await tester.pumpWidget(_host(_boundary(const AsyncLoading())));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error shows a retry that fires onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(_host(_boundary(
      AsyncError(Exception('boom'), StackTrace.empty),
      onRetry: () => retried = true,
    )));

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('empty data shows the empty label', (tester) async {
    await tester.pumpWidget(_host(_boundary(const AsyncData<List<String>>([]))));
    expect(find.text('Nothing here.'), findsOneWidget);
  });

  testWidgets('data renders through the builder', (tester) async {
    await tester.pumpWidget(
        _host(_boundary(const AsyncData<List<String>>(['a', 'b']))));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('items override replaces the data list', (tester) async {
    await tester.pumpWidget(_host(_boundary(
      const AsyncData<List<String>>(['a', 'b', 'c']),
      items: ['only'],
    )));
    expect(find.text('only'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });
}
