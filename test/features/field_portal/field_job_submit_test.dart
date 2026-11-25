// The Field Job Portal through the real app (TEMPORARY feature — see
// FIELD_PORTAL_REMOVAL.md): a signed-in technician opens the portal from the staff
// home, fills the form, submits, and sees the generated job number. The field-jobs
// API + technician token store/api are faked (no network / keystore).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/main.dart';
import 'package:microcare/src/features/field_portal/field_portal.dart';
import 'package:microcare/src/features/technician/data/technician_api.dart';
import 'package:microcare/src/features/technician/data/technician_job.dart';
import 'package:microcare/src/features/technician/technician.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/welcome_gate.dart';

const _sami = Technician(
  id: 'tech_1',
  code: 'MC0001TEC',
  name: 'Sami Tech',
  username: 'sami',
  phone: null,
);

/// Minimal technician API so the staff home (job queue) renders with no network.
class _EmptyTechApi implements TechnicianApi {
  @override
  Future<TechnicianLoginResult> login({
    required String username,
    required String password,
  }) async =>
      const TechnicianLoginResult(token: 'jwt', technician: _sami);
  @override
  Future<Technician> me() async => _sami;
  @override
  Future<List<TechnicianJob>> jobs({String? status}) async => const [];
  @override
  Future<TechnicianJob> job(String id) async => throw UnimplementedError();
  @override
  Future<TechnicianJob> acknowledgeJob(String id) async =>
      throw UnimplementedError();
  @override
  Future<TechnicianJob> updateJobStatus(String id, JobStatus s) async =>
      throw UnimplementedError();
  @override
  Future<List<JobPhoto>> jobPhotos(String id) async => const [];
  @override
  Future<List<JobPhoto>> uploadPhotos(
          String id, PhotoKind kind, List<PhotoUpload> files) async =>
      const [];
}

/// Records the submitted args and echoes the generated number the server would
/// compute from them (so asserting the confirmation proves the right values flowed).
class _FakeFieldJobApi implements FieldJobApi {
  FieldMonth? month;
  FieldTeam? team;
  int? sequence;
  String? technicianName;
  int beforeCount = 0;
  int afterCount = 0;

  @override
  Future<SubmittedFieldJob> submit({
    required FieldMonth month,
    required FieldTeam team,
    required int sequence,
    required String technicianName,
    required List<PhotoUpload> before,
    required List<PhotoUpload> after,
  }) async {
    this.month = month;
    this.team = team;
    this.sequence = sequence;
    this.technicianName = technicianName;
    beforeCount = before.length;
    afterCount = after.length;
    return SubmittedFieldJob(
      id: 'uuid-1',
      generatedNumber: buildGeneratedJobNumber(
          month: month, team: team, sequence: sequence),
    );
  }
}

Widget _app(FieldJobApi fieldApi) => ProviderScope(
      overrides: [
        skipWelcomeSplash,
        technicianTokenStoreProvider.overrideWithValue(
          InMemoryTechnicianTokenStore(token: 'jwt', technician: _sami),
        ),
        technicianApiProvider.overrideWithValue(_EmptyTechApi()),
        fieldJobApiProvider.overrideWithValue(fieldApi),
      ],
      child: const MicrocareApp(),
    );

/// Give the test a tall surface so the whole form (incl. the submit button at the
/// bottom of the lazy ListView) is laid out and tappable.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openPortal(WidgetTester tester) async {
  await tester.pumpAndSettle();
  // Staff home → tap the Field Job Portal entry in the app bar.
  await tester.tap(find.byIcon(Icons.assignment_outlined));
  await tester.pumpAndSettle();
  expect(find.text('Field Job Portal'), findsOneWidget);
}

void main() {
  testWidgets('fills the form and submits → confirmation shows the generated number',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _tallSurface(tester);
    final api = _FakeFieldJobApi();

    await tester.pumpWidget(_app(api));
    await _openPortal(tester);

    // Technician name is pre-filled from the session.
    expect(find.text('Sami Tech'), findsOneWidget);

    // Pick Month = November.
    await tester.tap(find.byType(DropdownButtonFormField<FieldMonth>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('November').last);
    await tester.pumpAndSettle();

    // Pick Team = Team B.
    await tester.tap(find.byType(DropdownButtonFormField<FieldTeam>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team B').last);
    await tester.pumpAndSettle();

    // Enter Job Number = 5 and watch the live generated number.
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('field_job_sequence')),
        matching: find.byType(TextField),
      ),
      '5',
    );
    await tester.pumpAndSettle();
    expect(find.text('MC-11-B-005'), findsOneWidget); // live preview

    // Submit.
    await tester.tap(find.text('Submit field job'));
    await tester.pumpAndSettle();

    // The screen swaps to the confirmation.
    expect(find.text('Field job submitted'), findsOneWidget);
    expect(find.text('MC-11-B-005'), findsOneWidget);

    // And the right values flowed to the API.
    expect(api.month, FieldMonth.november);
    expect(api.team, FieldTeam.b);
    expect(api.sequence, 5);
    expect(api.technicianName, 'Sami Tech');
    expect(api.beforeCount, 0);
    expect(api.afterCount, 0);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('submitting with missing fields shows per-field errors, no API call',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _tallSurface(tester);
    final api = _FakeFieldJobApi();

    await tester.pumpWidget(_app(api));
    await _openPortal(tester);

    await tester.tap(find.text('Submit field job'));
    await tester.pumpAndSettle();

    expect(find.text('Select a month.'), findsOneWidget);
    expect(find.text('Select a team.'), findsOneWidget);
    expect(find.text('Enter a job number (1 or more).'), findsOneWidget);
    // Never reached the API (name was pre-filled, but the rest are missing).
    expect(api.sequence, isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
