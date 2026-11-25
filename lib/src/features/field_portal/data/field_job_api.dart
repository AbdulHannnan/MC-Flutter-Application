// lib/src/features/field_portal/data/field_job_api.dart — the Field Job Portal
// SUBMIT path on the `field-jobs` Supabase Edge Function.
//
// TEMPORARY FEATURE (see FIELD_PORTAL_REMOVAL.md). Self-contained, but deliberately
// REUSES the proven technician plumbing rather than duplicating it:
//   • the technician ApiClient (base `<SUPABASE_URL>/functions/v1`, with the stored
//     technician JWT attached as `Authorization: Bearer` per request), and
//   • the shared [PhotoUpload] value + the multipart approach from booking-photos.
// It points them at the NEW `field-jobs` function + `field-job-photos` bucket.
//
// ONE request does create + upload (multipart): the text fields plus `beforePhotos`
// and `afterPhotos` file arrays. The function verifies the technician JWT, recomputes
// the generated number server-side, stores the photos in the private bucket, and
// returns `{ data: <fieldJob> }` (unwrapped by ApiClient). We only need the id +
// generatedNumber back for the success confirmation.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../technician/data/supabase_technician_api.dart';
import '../../technician/data/technician_api.dart' show PhotoUpload;
import '../field_job_form.dart';

/// The server's confirmation of a created field job: its id + the generated number
/// (recomputed server-side; it matches the client preview when all fields are set).
class SubmittedFieldJob {
  final String id;
  final String generatedNumber;
  const SubmittedFieldJob({required this.id, required this.generatedNumber});

  factory SubmittedFieldJob.fromJson(Map<String, dynamic> j) => SubmittedFieldJob(
        id: (j['id'] ?? '').toString(),
        generatedNumber: (j['generatedNumber'] ?? '').toString(),
      );
}

/// Build the multipart body the `field-jobs` POST expects: the text fields plus the
/// `beforePhotos` / `afterPhotos` file arrays (the field names the function reads).
FormData buildFieldJobFormData({
  required FieldMonth month,
  required FieldTeam team,
  required int sequence,
  required String technicianName,
  required List<PhotoUpload> before,
  required List<PhotoUpload> after,
}) {
  final form = FormData();
  form.fields.addAll([
    MapEntry('month', month.number.toString()),
    MapEntry('team', team.letter),
    MapEntry('sequence', sequence.toString()),
    MapEntry('technicianName', technicianName),
  ]);
  void addFiles(String field, List<PhotoUpload> files) {
    form.files.addAll(files.map((f) => MapEntry(
          field,
          MultipartFile.fromBytes(
            f.bytes,
            filename: f.filename,
            contentType: MediaType.parse(f.contentType),
          ),
        )));
  }

  addFiles('beforePhotos', before);
  addFiles('afterPhotos', after);
  return form;
}

/// The field-job submit contract, as a seam so tests inject a fake instead of hitting
/// the network.
abstract interface class FieldJobApi {
  /// Create a field job + upload its before/after photos in one request. Throws
  /// [ApiException] (e.g. 401 no/expired token, 422 bad field) for the screen to
  /// surface. Returns the created job's id + generated number.
  Future<SubmittedFieldJob> submit({
    required FieldMonth month,
    required FieldTeam team,
    required int sequence,
    required String technicianName,
    required List<PhotoUpload> before,
    required List<PhotoUpload> after,
  });
}

class SupabaseFieldJobApi implements FieldJobApi {
  SupabaseFieldJobApi(this._client);

  final ApiClient _client;

  // The anon key as the gateway credential, like every other technician call.
  Map<String, String> get _gatewayHeaders => {'apikey': config.supabaseAnonKey};

  @override
  Future<SubmittedFieldJob> submit({
    required FieldMonth month,
    required FieldTeam team,
    required int sequence,
    required String technicianName,
    required List<PhotoUpload> before,
    required List<PhotoUpload> after,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/field-jobs',
      body: buildFieldJobFormData(
        month: month,
        team: team,
        sequence: sequence,
        technicianName: technicianName,
        before: before,
        after: after,
      ),
      headers: _gatewayHeaders,
    );
    return SubmittedFieldJob.fromJson(data);
  }
}

/// The single [FieldJobApi] the feature reads, reusing the technician ApiClient
/// (which carries the technician JWT). Overridden in tests with a fake.
final fieldJobApiProvider = Provider<FieldJobApi>(
  (ref) => SupabaseFieldJobApi(ref.read(supabaseTechnicianApiClientProvider)),
);
