// lib/src/features/technician/data/technician_api.dart — the technician HTTP
// layer: an AUTHORIZED ApiClient (sends the stored JWT as a Bearer header on
// every call) plus the typed technician endpoints.
//
// Separate ApiClient instance from the customer `apiClientProvider` so the bearer
// token is attached ONLY to technician requests — the public catalog calls stay
// unauthenticated. The token is resolved fresh per request from secure storage,
// so a login or logout takes effect on the very next call with no rewiring.
//
// Module 1 covers auth (login + me); the job/photo endpoints land in Modules 2–5.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'technician.dart';
import 'technician_token_store.dart';

/// The result of a successful technician login: the JWT + the profile.
class TechnicianLoginResult {
  final String token;
  final Technician technician;
  const TechnicianLoginResult({required this.token, required this.technician});
}

/// Thin typed client over the backend's `/api/technician/*` routes.
class TechnicianApi {
  TechnicianApi(this._client);

  final ApiClient _client;

  /// POST /api/technician/login → { token, technician }. Throws [ApiException]
  /// (401 with a generic message) on bad credentials.
  Future<TechnicianLoginResult> login({
    required String username,
    required String password,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/api/technician/login',
      body: {'username': username, 'password': password},
    );
    return TechnicianLoginResult(
      token: data['token'] as String,
      technician:
          Technician.fromJson(data['technician'] as Map<String, dynamic>),
    );
  }

  /// GET /api/technician/me → the authenticated technician (validates the token).
  Future<Technician> me() async {
    final data =
        await _client.get<Map<String, dynamic>>('/api/technician/me');
    return Technician.fromJson(data['technician'] as Map<String, dynamic>);
  }
}

/// An [ApiClient] that attaches the stored technician JWT as an
/// `Authorization: Bearer` header on every request (resolved fresh from storage).
final technicianApiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.read(technicianTokenStoreProvider);
  final client = ApiClient() // base URL from the app config (no hardcoding)
    ..setAuthTokenProvider(() => store.readToken());
  return client;
});

/// The single [TechnicianApi] the technician feature reads.
final technicianApiProvider = Provider<TechnicianApi>(
  (ref) => TechnicianApi(ref.read(technicianApiClientProvider)),
);
