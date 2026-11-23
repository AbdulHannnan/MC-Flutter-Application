// TechnicianJob.fromJson for both response shapes: a LIST row (core fields only,
// detail fields absent) and a DETAIL row (notes/quantity/total/option/addons/
// photos present). Field names + nesting mirror the Edge Function's SELECTs.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/technician/data/technician_job.dart';
import 'package:microcare/src/models/money.dart';

void main() {
  group('JobStatus.fromCode', () {
    test('maps wire codes, defaults unknown to unassigned', () {
      expect(JobStatus.fromCode('ASSIGNED'), JobStatus.assigned);
      expect(JobStatus.fromCode('IN_PROGRESS'), JobStatus.inProgress);
      expect(JobStatus.fromCode('DONE'), JobStatus.done);
      expect(JobStatus.fromCode(null), JobStatus.unassigned);
      expect(JobStatus.fromCode('WEIRD'), JobStatus.unassigned);
      // round-trips through code
      expect(JobStatus.inProgress.code, 'IN_PROGRESS');
    });
  });

  test('parses a list row (detail fields absent → null/empty)', () {
    final job = TechnicianJob.fromJson({
      'id': 'bk_1',
      'reference': 'MC-0001AH',
      'status': 'COMPLETED',
      'jobStatus': 'ASSIGNED',
      'propertyType': 'Apartment',
      'address': 'Marina Gate 1',
      'mapUrl': 'https://www.google.com/maps?q=25.07,55.13',
      'scheduledDate': '2026-09-01T10:00:00.000',
      'scheduledTime': '10:00',
      'contactName': 'Jane Doe',
      'contactPhone': '0501234567',
      'assignedAt': '2026-08-30T09:00:00.000Z',
      'service': {'id': 'svc_1', 'name': 'Split AC Deep Cleaning'},
    });

    expect(job.id, 'bk_1');
    expect(job.reference, 'MC-0001AH');
    expect(job.jobStatus, JobStatus.assigned);
    expect(job.service?.name, 'Split AC Deep Cleaning');
    expect(job.serviceName, 'Split AC Deep Cleaning');
    expect(job.scheduledTime, '10:00');
    // Detail-only fields are absent on a list row.
    expect(job.total, isNull);
    expect(job.serviceOption, isNull);
    expect(job.addons, isEmpty);
    expect(job.photos, isEmpty);
    expect(job.notes, isNull);
  });

  test('parses a detail row with option, addons, total, notes, photos', () {
    final job = TechnicianJob.fromJson({
      'id': 'bk_1',
      'reference': 'MC-0001AH',
      'jobStatus': 'IN_PROGRESS',
      'service': {'id': 'svc_1', 'name': 'Split AC Deep Cleaning'},
      'notes': 'Ring the bell twice',
      'quantity': 2,
      'total': '135.00',
      'serviceOption': {'id': 'opt_1', 'label': '1 unit'},
      'addons': [
        {
          'id': 'ba_1',
          'quantity': 1,
          'lineTotal': '20.00',
          'addon': {'id': 'ad_gas', 'name': 'Gas top-up'},
        },
      ],
      'photos': [
        {
          'id': 'ph_1',
          'kind': 'before',
          'url': '/uploads/booking-photos/x.jpg',
          'createdAt': '2026-09-01T10:05:00.000Z',
        },
        {'id': 'ph_2', 'kind': 'after', 'url': '/uploads/booking-photos/y.jpg'},
      ],
    });

    expect(job.jobStatus, JobStatus.inProgress);
    expect(job.quantity, 2);
    expect(job.total, const Money(amountMinor: 13500, currency: CurrencyCode.aed));
    expect(job.serviceOption?.label, '1 unit');

    expect(job.addons, hasLength(1));
    expect(job.addons.first.addonName, 'Gas top-up');
    expect(job.addons.first.lineTotal,
        const Money(amountMinor: 2000, currency: CurrencyCode.aed));

    expect(job.photos, hasLength(2));
    expect(job.photos[0].kind, PhotoKind.before);
    expect(job.photos[1].kind, PhotoKind.after);
  });
}
