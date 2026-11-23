// The technician jobs portal through the real app: a signed-in technician sees
// their queue on the staff home, and tapping a job opens its detail. The jobs API
// + token store are faked (no network / keystore), the welcome gate is open.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/features/technician/data/technician_api.dart';
import 'package:microcare/src/features/technician/data/technician_job.dart';
import 'package:microcare/src/features/technician/technician.dart';
import 'package:microcare/src/models/money.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/welcome_gate.dart';

const _sami = Technician(
  id: 'tech_1',
  code: 'MC0001TEC',
  name: 'Sami Tech',
  username: 'sami',
  phone: null,
);

const _listJob = TechnicianJob(
  id: 'bk_1',
  reference: 'MC-0001AH',
  jobStatus: JobStatus.assigned,
  scheduledDate: '2026-09-01T10:00:00.000',
  scheduledTime: '10:00',
  address: 'Marina Gate 1',
  service: JobServiceRef(id: 'svc_1', name: 'Split AC Deep Cleaning'),
);

const _detailJob = TechnicianJob(
  id: 'bk_1',
  reference: 'MC-0001AH',
  jobStatus: JobStatus.assigned,
  scheduledDate: '2026-09-01T10:00:00.000',
  scheduledTime: '10:00',
  address: 'Marina Gate 1',
  contactName: 'Jane Doe',
  contactPhone: '0501234567',
  service: JobServiceRef(id: 'svc_1', name: 'Split AC Deep Cleaning'),
  serviceOption: JobOptionRef(id: 'opt_1', label: '1 unit'),
  total: Money(amountMinor: 13500, currency: CurrencyCode.aed),
  notes: 'Ring the bell twice',
);

class _FakeTechApi implements TechnicianApi {
  @override
  Future<TechnicianLoginResult> login({
    required String username,
    required String password,
  }) async =>
      const TechnicianLoginResult(token: 'jwt', technician: _sami);
  @override
  Future<Technician> me() async => _sami;
  @override
  Future<List<TechnicianJob>> jobs({String? status}) async => [_listJob];
  @override
  Future<TechnicianJob> job(String id) async => _detailJob;
  @override
  Future<TechnicianJob> acknowledgeJob(String id) async => _detailJob;
  @override
  Future<TechnicianJob> updateJobStatus(String id, JobStatus s) async =>
      _detailJob;
  @override
  Future<List<JobPhoto>> jobPhotos(String id) async => const [];
  @override
  Future<List<JobPhoto>> uploadPhotos(
          String id, PhotoKind kind, List<PhotoUpload> files) async =>
      const [];
}

Widget _app() => ProviderScope(
      overrides: [
        skipWelcomeSplash,
        technicianTokenStoreProvider.overrideWithValue(
          InMemoryTechnicianTokenStore(token: 'jwt', technician: _sami),
        ),
        technicianApiProvider.overrideWithValue(_FakeTechApi()),
      ],
      child: const MicrocareApp(),
    );

void main() {
  testWidgets('staff home lists assigned jobs; tapping opens detail',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // The queue shows the job card.
    expect(find.text('1 job assigned to you.'), findsOneWidget);
    expect(find.text('Split AC Deep Cleaning'), findsOneWidget);
    expect(find.text('Ref MC-0001AH'), findsOneWidget);
    expect(find.text('Assigned'), findsWidgets); // status pill

    // Tap the card → the job detail screen.
    await tester.tap(find.text('Split AC Deep Cleaning'));
    await tester.pumpAndSettle();

    expect(find.text('Job detail'), findsOneWidget); // app bar
    expect(find.text('Jane Doe'), findsOneWidget); // customer section
    expect(find.text('1 unit'), findsOneWidget); // option
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('135.00 AED'), findsOneWidget); // server total

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('acknowledge → start advances the job through the detail actions',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _StatefulTechApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skipWelcomeSplash,
          technicianTokenStoreProvider.overrideWithValue(
            InMemoryTechnicianTokenStore(token: 'jwt', technician: _sami),
          ),
          technicianApiProvider.overrideWithValue(api),
        ],
        child: const MicrocareApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Open the (ASSIGNED) job's detail.
    await tester.tap(find.text('Split AC Deep Cleaning'));
    await tester.pumpAndSettle();
    expect(find.text('Acknowledge job'), findsOneWidget);

    // Acknowledge → status becomes Acknowledged and the action becomes "Start job".
    await tester.tap(find.text('Acknowledge job'));
    await tester.pumpAndSettle();
    expect(api.status, JobStatus.acknowledged);
    expect(find.text('Start job'), findsOneWidget);
    expect(find.text('Acknowledge job'), findsNothing);

    // Start → IN_PROGRESS; the finish action appears, gated on photos (none yet).
    await tester.tap(find.text('Start job'));
    await tester.pumpAndSettle();
    expect(api.status, JobStatus.inProgress);
    expect(find.text('Mark as done'), findsOneWidget);
    expect(find.textContaining('before and one after'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mark as done is enabled once before+after photos exist, then completes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _StatefulTechApi(
      status: JobStatus.inProgress,
      photos: const [
        JobPhoto(id: 'p1', kind: PhotoKind.before, url: 'k1', signedUrl: 'https://x/1.jpg'),
        JobPhoto(id: 'p2', kind: PhotoKind.after, url: 'k2', signedUrl: 'https://x/2.jpg'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skipWelcomeSplash,
          technicianTokenStoreProvider.overrideWithValue(
            InMemoryTechnicianTokenStore(token: 'jwt', technician: _sami),
          ),
          technicianApiProvider.overrideWithValue(api),
        ],
        child: const MicrocareApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Split AC Deep Cleaning'));
    await tester.pumpAndSettle();

    // Both photo kinds present → no gate hint, and Mark as done completes the job.
    expect(find.textContaining('before and one after'), findsNothing);
    await tester.tap(find.text('Mark as done'));
    await tester.pumpAndSettle();
    expect(api.status, JobStatus.done);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty queue shows the empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skipWelcomeSplash,
          technicianTokenStoreProvider.overrideWithValue(
            InMemoryTechnicianTokenStore(token: 'jwt', technician: _sami),
          ),
          technicianApiProvider.overrideWithValue(_EmptyTechApi()),
        ],
        child: const MicrocareApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing to do right now'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _EmptyTechApi extends _FakeTechApi {
  @override
  Future<List<TechnicianJob>> jobs({String? status}) async => const [];
}

/// A fake whose single job advances through the lifecycle as actions are called,
/// and whose photo set can be seeded (for the mark-done gate).
class _StatefulTechApi implements TechnicianApi {
  _StatefulTechApi({this.status = JobStatus.assigned, this.photos = const []});

  JobStatus status;
  List<JobPhoto> photos;

  TechnicianJob get _job => TechnicianJob(
        id: 'bk_1',
        reference: 'MC-0001AH',
        jobStatus: status,
        contactName: 'Jane Doe',
        service: const JobServiceRef(id: 'svc_1', name: 'Split AC Deep Cleaning'),
      );

  @override
  Future<TechnicianLoginResult> login({
    required String username,
    required String password,
  }) async =>
      const TechnicianLoginResult(token: 'jwt', technician: _sami);
  @override
  Future<Technician> me() async => _sami;
  @override
  Future<List<TechnicianJob>> jobs({String? status}) async => [_job];
  @override
  Future<TechnicianJob> job(String id) async => _job;
  @override
  Future<TechnicianJob> acknowledgeJob(String id) async {
    status = JobStatus.acknowledged;
    return _job;
  }

  @override
  Future<TechnicianJob> updateJobStatus(String id, JobStatus s) async {
    status = s;
    return _job;
  }

  @override
  Future<List<JobPhoto>> jobPhotos(String id) async => photos;
  @override
  Future<List<JobPhoto>> uploadPhotos(
          String id, PhotoKind kind, List<PhotoUpload> files) async =>
      photos;
}
