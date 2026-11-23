// lib/src/features/technician/data/supabase_technician_api.dart — the technician
// auth path on the SUPABASE `technician` Edge Function. The real replacement for
// the Express `/api/technician/login` + `/me` routes.
//
// The function is deployed verify_jwt=false, so the gateway does NOT require a
// Supabase JWT — our custom technician JWT rides in `Authorization: Bearer` and
// the function's own verifyTechnician reads it. Every call still needs the anon
// `apikey` header as the gateway credential (mirrors the booking website's
// functionsClient). The technician token is a PARALLEL auth: it is resolved from
// the technician token store, NEVER the customer Supabase session.
//
// Routes (sub-paths of the single `technician` function):
//   POST <SUPABASE_URL>/functions/v1/technician/login  (public — body creds)
//   GET  <SUPABASE_URL>/functions/v1/technician/me     (Bearer technician JWT)
// Response shapes are identical to the Express routes, so parsing is the shared
// parseLoginResult / parseMeResult.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'technician.dart';
import 'technician_api.dart';
import 'technician_job.dart';
import 'technician_token_store.dart';

class SupabaseTechnicianApi implements TechnicianApi {
  SupabaseTechnicianApi(this._client);

  final ApiClient _client;

  // The anon key as the gateway credential, sent on every technician call.
  Map<String, String> get _gatewayHeaders => {'apikey': config.supabaseAnonKey};

  @override
  Future<TechnicianLoginResult> login({
    required String username,
    required String password,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/technician/login',
      body: {'username': username, 'password': password},
      headers: _gatewayHeaders,
    );
    return parseLoginResult(data);
  }

  @override
  Future<Technician> me() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/technician/me',
      headers: _gatewayHeaders,
    );
    return parseMeResult(data);
  }

  @override
  Future<List<TechnicianJob>> jobs({String? status}) async {
    final data = await _client.get<List<dynamic>>(
      '/technician/jobs',
      query: jobsQuery(status),
      headers: _gatewayHeaders,
    );
    return parseJobs(data);
  }

  @override
  Future<TechnicianJob> job(String id) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/technician/jobs/$id',
      headers: _gatewayHeaders,
    );
    return TechnicianJob.fromJson(data);
  }

  @override
  Future<TechnicianJob> acknowledgeJob(String id) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/technician/jobs/$id/acknowledge',
      headers: _gatewayHeaders,
    );
    return TechnicianJob.fromJson(data);
  }

  @override
  Future<TechnicianJob> updateJobStatus(String id, JobStatus status) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/technician/jobs/$id/status',
      body: {'jobStatus': status.code},
      headers: _gatewayHeaders,
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
      '/booking-photos/$id/photos',
      body: buildPhotoFormData(kind, files),
      headers: _gatewayHeaders,
    );
    return data
        .map((e) => JobPhoto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<JobPhoto>> jobPhotos(String id) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/booking-photos/$id/photos',
      headers: _gatewayHeaders,
    );
    return parseJobPhotos(data);
  }
}

/// An [ApiClient] for the SUPABASE technician Edge Function: base URL
/// `<SUPABASE_URL>/functions/v1`, with the stored technician JWT attached as
/// `Authorization: Bearer` per request (the login call simply has no token yet).
/// The anon `apikey` is added per request by [SupabaseTechnicianApi].
final supabaseTechnicianApiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.read(technicianTokenStoreProvider);
  final client = ApiClient(baseUrl: '${config.supabaseUrl}/functions/v1')
    ..setAuthTokenProvider(() => store.readToken());
  return client;
});
