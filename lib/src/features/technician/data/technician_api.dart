// lib/src/features/technician/data/technician_api.dart — the technician HTTP
// layer: the typed login + me endpoints, over an AUTHORIZED ApiClient (sends the
// stored technician JWT as a Bearer header on every call).
//
// Separate ApiClient instance from the customer `apiClientProvider` so the bearer
// token is attached ONLY to technician requests. The technician auth is a PARALLEL
// custom JWT (not a Supabase session), the same on both backends:
//   • Express  → `/api/technician/*` on the legacy server.
//   • Supabase → the `technician` Edge Function (`/functions/v1/technician/*`,
//                deployed verify_jwt=false so the custom JWT reaches it), with the
//                anon `apikey` as the gateway credential — see SupabaseTechnicianApi.
// The response shapes are IDENTICAL across both (confirmed from the deployed
// function): login → { token, technician{id,code,name,username,phone} }, me →
// { technician }. So the parsing is shared; only the base URL + paths + headers
// differ, chosen by `TECHNICIAN_BACKEND`.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'supabase_technician_api.dart';
import 'technician.dart';
import 'technician_job.dart';
import 'technician_token_store.dart';

/// The result of a successful technician login: the JWT + the profile.
class TechnicianLoginResult {
  final String token;
  final Technician technician;
  const TechnicianLoginResult({required this.token, required this.technician});
}

/// One image to upload, decoupled from the picker: its bytes, a filename, and a
/// MIME type the backend accepts (image/jpeg|png|webp|heic|heif).
class PhotoUpload {
  final List<int> bytes;
  final String filename;
  final String contentType;
  const PhotoUpload({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });
}

/// Build the multipart body the photo-upload endpoint expects: a `kind` field
/// plus one or more `files`. Shared by both backends.
FormData buildPhotoFormData(PhotoKind kind, List<PhotoUpload> files) {
  return FormData()
    ..fields.add(MapEntry('kind', kind.name)) // 'before' | 'after'
    ..files.addAll(files.map((f) => MapEntry(
          'files',
          MultipartFile.fromBytes(
            f.bytes,
            filename: f.filename,
            contentType: MediaType.parse(f.contentType),
          ),
        )));
}

/// Parse a photos-GET body (`{ bookingId, …, photos:[…] }`) into display photos.
List<JobPhoto> parseJobPhotos(Map<String, dynamic> data) =>
    (data['photos'] as List<dynamic>? ?? const [])
        .map((e) => JobPhoto.fromJson(e as Map<String, dynamic>))
        .toList();

/// The technician auth contract the session layer depends on. Implemented by
/// [ExpressTechnicianApi] and [SupabaseTechnicianApi].
abstract interface class TechnicianApi {
  /// Authenticate with username + password → the JWT + profile. Throws
  /// [ApiException] (401 generic message) on bad credentials.
  Future<TechnicianLoginResult> login({
    required String username,
    required String password,
  });

  /// Validate the stored token and return the authenticated technician.
  Future<Technician> me();

  /// The technician's job queue, soonest first. [status] optionally filters by a
  /// [JobStatus] wire code (e.g. `ASSIGNED`). Scoped server-side to this token.
  Future<List<TechnicianJob>> jobs({String? status});

  /// One owned job's full detail. Throws [ApiException] 404 if it isn't theirs.
  Future<TechnicianJob> job(String id);

  /// Acknowledge an ASSIGNED job (ASSIGNED → ACKNOWLEDGED). Idempotent if already
  /// acknowledged; throws [ApiException] 409 from any other state. Returns the
  /// updated job detail.
  Future<TechnicianJob> acknowledgeJob(String id);

  /// Move a job to [status] (IN_PROGRESS or DONE). The server enforces the
  /// lifecycle (ACKNOWLEDGED→IN_PROGRESS→DONE) and that DONE needs ≥1 before + ≥1
  /// after photo — an invalid move throws [ApiException] 409. Returns the updated
  /// job detail.
  Future<TechnicianJob> updateJobStatus(String id, JobStatus status);

  /// Upload one or more [files] as this job's `before`/`after` photos (additive).
  /// Returns the created photo records. Throws [ApiException] 422 (bad kind / no
  /// files / too many / unsupported type) or 404 (not owned).
  Future<List<JobPhoto>> uploadPhotos(
    String id,
    PhotoKind kind,
    List<PhotoUpload> files,
  );

  /// This job's photos with short-lived viewable URLs (the private objects are
  /// signed on read). Used to display before/after thumbnails.
  Future<List<JobPhoto>> jobPhotos(String id);
}

/// Parse a jobs-list response body (a JSON array) — shared by both backends.
List<TechnicianJob> parseJobs(List<dynamic> data) =>
    data.map((e) => TechnicianJob.fromJson(e as Map<String, dynamic>)).toList();

/// Parse a login response body (`{ token, technician }`) — shared by both backends.
TechnicianLoginResult parseLoginResult(Map<String, dynamic> data) =>
    TechnicianLoginResult(
      token: data['token'] as String,
      technician: Technician.fromJson(data['technician'] as Map<String, dynamic>),
    );

/// Parse a me response body (`{ technician }`) — shared by both backends.
Technician parseMeResult(Map<String, dynamic> data) =>
    Technician.fromJson(data['technician'] as Map<String, dynamic>);

/// Build the optional `?status=` query for the jobs list.
Map<String, dynamic>? jobsQuery(String? status) =>
    (status != null && status.isNotEmpty) ? {'status': status} : null;

/// Express implementation — the legacy `/api/technician/*` routes.
class ExpressTechnicianApi implements TechnicianApi {
  ExpressTechnicianApi(this._client);

  final ApiClient _client;

  @override
  Future<TechnicianLoginResult> login({
    required String username,
    required String password,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/technician/login',
      body: {'username': username, 'password': password},
    );
    return parseLoginResult(data);
  }

  @override
  Future<Technician> me() async {
    final data = await _client.get<Map<String, dynamic>>('/api/technician/me');
    return parseMeResult(data);
  }

  @override
  Future<List<TechnicianJob>> jobs({String? status}) async {
    final data = await _client.get<List<dynamic>>(
      '/api/technician/jobs',
      query: jobsQuery(status),
    );
    return parseJobs(data);
  }

  @override
  Future<TechnicianJob> job(String id) async {
    final data =
        await _client.get<Map<String, dynamic>>('/api/technician/jobs/$id');
    return TechnicianJob.fromJson(data);
  }

  @override
  Future<TechnicianJob> acknowledgeJob(String id) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/api/technician/jobs/$id/acknowledge',
    );
    return TechnicianJob.fromJson(data);
  }

  @override
  Future<TechnicianJob> updateJobStatus(String id, JobStatus status) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/api/technician/jobs/$id/status',
      body: {'jobStatus': status.code},
    );
    return TechnicianJob.fromJson(data);
  }

  @override
  Future<List<JobPhoto>> uploadPhotos(
    String id,
    PhotoKind kind,
    List<PhotoUpload> files,
  ) async {
    final data = await _client.post<List<dynamic>>(
      '/api/bookings/$id/photos',
      body: buildPhotoFormData(kind, files),
    );
    return data
        .map((e) => JobPhoto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<JobPhoto>> jobPhotos(String id) async {
    final data =
        await _client.get<Map<String, dynamic>>('/api/bookings/$id/photos');
    return parseJobPhotos(data);
  }
}

/// An [ApiClient] for the EXPRESS technician routes that attaches the stored
/// technician JWT as an `Authorization: Bearer` header on every request (resolved
/// fresh from storage, so login/logout take effect on the next call).
final technicianApiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.read(technicianTokenStoreProvider);
  final client = ApiClient() // base URL from the app config (no hardcoding)
    ..setAuthTokenProvider(() => store.readToken());
  return client;
});

/// The single [TechnicianApi] the technician feature reads — Supabase when
/// selected + configured, else the Express fallback.
final technicianApiProvider = Provider<TechnicianApi>((ref) {
  if (config.isSupabaseTechnician) {
    return SupabaseTechnicianApi(ref.read(supabaseTechnicianApiClientProvider));
  }
  return ExpressTechnicianApi(ref.read(technicianApiClientProvider));
});
