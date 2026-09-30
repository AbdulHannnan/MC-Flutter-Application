// The presentational booking pickers (Module 12): the month Calendar and the
// TimeSlots grid, driven in isolation. Both are props-in/events-out — they own no
// selection state, they just render what they're given and report taps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/booking/widgets/calendar.dart';
import 'package:microcare/src/features/booking/widgets/time_slots.dart';
import 'package:microcare/src/models/models.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('Calendar', () {
    testWidgets('opens on the initial month and pages forward', (tester) async {
      await tester.pumpWidget(_host(const Calendar(
        initialMonth: '2030-06-01',
        minDate: '2000-01-01',
      )));

      expect(find.text('June 2030'), findsOneWidget);
      // ‹ › nav — page to the next month.
      await tester.tap(find.text('›'));
      await tester.pump();
      expect(find.text('July 2030'), findsOneWidget);
    });

    testWidgets('taps a selectable day and reports its ISO date',
        (tester) async {
      String? tapped;
      await tester.pumpWidget(_host(Calendar(
        initialMonth: '2030-06-01',
        minDate: '2000-01-01',
        onSelectDate: (d) => tapped = d,
      )));

      await tester.tap(find.text('15'));
      expect(tapped, '2030-06-15');
    });

    testWidgets('a day before minDate is disabled and does not fire',
        (tester) async {
      String? tapped;
      await tester.pumpWidget(_host(Calendar(
        initialMonth: '2030-06-01',
        minDate: '2030-06-10',
        onSelectDate: (d) => tapped = d,
      )));

      await tester.tap(find.text('5')); // before the 10th → disabled
      expect(tapped, isNull);
    });
  });

  group('TimeSlots', () {
    const available = TimeSlot(
      id: 'slot_a',
      start: '2030-06-15T09:00:00.000',
      end: '2030-06-15T10:00:00.000',
    );
    const taken = TimeSlot(
      id: 'slot_b',
      start: '2030-06-15T10:00:00.000',
      end: '2030-06-15T11:00:00.000',
      isAvailable: false,
    );

    testWidgets('renders each slot as a labelled chip', (tester) async {
      await tester.pumpWidget(_host(const TimeSlots(slots: [available, taken])));
      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
    });

    testWidgets('taps an available slot; a taken slot does not fire',
        (tester) async {
      TimeSlot? picked;
      await tester.pumpWidget(_host(TimeSlots(
        slots: [available, taken],
        onSelectSlot: (s) => picked = s,
      )));

      await tester.tap(find.text('10:00 AM')); // taken → no-op
      expect(picked, isNull);

      await tester.tap(find.text('9:00 AM')); // available
      expect(picked?.id, 'slot_a');
    });
  });
}
