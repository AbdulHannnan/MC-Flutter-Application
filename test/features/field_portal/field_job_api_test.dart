// Unit tests for the Field Job Portal submit payload (TEMPORARY feature — see
// FIELD_PORTAL_REMOVAL.md). Guards the exact multipart contract the `field-jobs`
// function reads: text fields month/team/sequence/technicianName + the beforePhotos
// / afterPhotos file arrays. If these drift, the real submit silently breaks.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/field_portal/data/field_job_api.dart';
import 'package:microcare/src/features/field_portal/field_job_form.dart';
import 'package:microcare/src/features/technician/data/technician_api.dart'
    show PhotoUpload;

PhotoUpload _img(String name) =>
    PhotoUpload(bytes: const [1, 2, 3], filename: name, contentType: 'image/jpeg');

void main() {
  group('buildFieldJobFormData', () {
    final form = buildFieldJobFormData(
      month: FieldMonth.november,
      team: FieldTeam.b,
      sequence: 5,
      technicianName: 'Sami Tech',
      before: [_img('b1.jpg'), _img('b2.jpg')],
      after: [_img('a1.jpg')],
    );

    test('sends month as 1-based number, team letter, sequence, name', () {
      final fields = {for (final e in form.fields) e.key: e.value};
      expect(fields['month'], '11');
      expect(fields['team'], 'B');
      expect(fields['sequence'], '5');
      expect(fields['technicianName'], 'Sami Tech');
      // Never a prices/userId leak — only the four expected text fields.
      expect(fields.keys.toSet(),
          {'month', 'team', 'sequence', 'technicianName'});
    });

    test('files go under beforePhotos / afterPhotos with the right counts', () {
      final byField = <String, int>{};
      for (final e in form.files) {
        byField[e.key] = (byField[e.key] ?? 0) + 1;
      }
      expect(byField['beforePhotos'], 2);
      expect(byField['afterPhotos'], 1);
      expect(byField.keys.toSet(), {'beforePhotos', 'afterPhotos'});
    });

    test('no file entries when both photo lists are empty', () {
      final empty = buildFieldJobFormData(
        month: FieldMonth.january,
        team: FieldTeam.a,
        sequence: 1,
        technicianName: 'T',
        before: const [],
        after: const [],
      );
      expect(empty.files, isEmpty);
    });
  });

  group('SubmittedFieldJob.fromJson', () {
    test('reads id + generatedNumber', () {
      final s = SubmittedFieldJob.fromJson(
          {'id': 'uuid-1', 'generatedNumber': 'MC-11-B-005'});
      expect(s.id, 'uuid-1');
      expect(s.generatedNumber, 'MC-11-B-005');
    });

    test('tolerates missing fields', () {
      final s = SubmittedFieldJob.fromJson(const {});
      expect(s.id, '');
      expect(s.generatedNumber, '');
    });
  });
}
