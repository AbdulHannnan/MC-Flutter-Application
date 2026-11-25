// Unit tests for the Field Job Portal's pure number builder (TEMPORARY feature —
// see FIELD_PORTAL_REMOVAL.md). Guards the format the server also recomputes.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/field_portal/field_job_form.dart';

void main() {
  group('buildGeneratedJobNumber', () {
    test('builds MC-<MM>-<Team>-<3-digit seq> when complete', () {
      expect(
        buildGeneratedJobNumber(
          month: FieldMonth.november,
          team: FieldTeam.b,
          sequence: 5,
        ),
        'MC-11-B-005',
      );
    });

    test('zero-pads month and sequence', () {
      expect(
        buildGeneratedJobNumber(
          month: FieldMonth.january,
          team: FieldTeam.a,
          sequence: 42,
        ),
        'MC-01-A-042',
      );
    });

    test('keeps 3 digits for sequences ≥ 100', () {
      expect(
        buildGeneratedJobNumber(
          month: FieldMonth.december,
          team: FieldTeam.e,
          sequence: 1234,
        ),
        'MC-12-E-1234',
      );
    });

    test('shows placeholders for the parts not yet filled', () {
      // mm='--', team='-', seq='---' → "MC-" + "--" + "-" + "-" + "-" + "---".
      expect(buildGeneratedJobNumber(), 'MC---------');
      expect(
        buildGeneratedJobNumber(month: FieldMonth.march),
        'MC-03------',
      );
      expect(
        buildGeneratedJobNumber(month: FieldMonth.march, team: FieldTeam.c),
        'MC-03-C----',
      );
    });

    test('non-positive sequence is treated as not filled', () {
      expect(
        buildGeneratedJobNumber(
          month: FieldMonth.may,
          team: FieldTeam.d,
          sequence: 0,
        ),
        'MC-05-D----',
      );
    });
  });

  group('month + team labels', () {
    test('month label is capitalised', () {
      expect(FieldMonth.november.label, 'November');
      expect(FieldMonth.november.twoDigit, '11');
      expect(FieldMonth.november.number, 11);
    });

    test('team label + letter', () {
      expect(FieldTeam.b.letter, 'B');
      expect(FieldTeam.b.label, 'Team B');
    });
  });

  group('isGeneratedNumberComplete', () {
    test('true only when all three parts present and seq positive', () {
      expect(
        isGeneratedNumberComplete(
          month: FieldMonth.june,
          team: FieldTeam.a,
          sequence: 1,
        ),
        isTrue,
      );
      expect(isGeneratedNumberComplete(month: FieldMonth.june), isFalse);
      expect(
        isGeneratedNumberComplete(
          month: FieldMonth.june,
          team: FieldTeam.a,
          sequence: 0,
        ),
        isFalse,
      );
    });
  });
}
