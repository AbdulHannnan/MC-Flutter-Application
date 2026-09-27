// lib/src/core/network/api_client.dart
//
// The app's single HTTP client — the Dart/dio port of the RN `src/lib/api.ts`.
//
// WHY THIS EXISTS:
// Every screen that talks to the backend needs the same boring things: prepend
// the base URL, send/receive JSON, attach an auth token, give up if the network
// hangs, unwrap the `{ data }` success envelope, and turn a failed response into
// a predictable [ApiException] instead of a raw dio surprise. Doing that inline
// in each feature would mean copy-pasted calls with slightly different error
// handling. Instead features read [apiClientProvider] and call `get`/`post`, and
// this file owns the plumbing. Swap the transport, change how errors look, or add
// logging in ONE place.
//
// WHAT THIS IS NOT: it is not data caching. Deciding *when* to refetch, holding
// server data, and keeping the UI in sync is the catalog/data layer's job
// (react-query's equivalent, Module 6). This layer performs one request and hands
// back the decoded JSON (or throws).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import 'api_exception.dart';

/// An async function that yields the current bearer token, or `null` if none.
typedef AuthTokenProvider = Future<String?> Function();

/// The default per-request timeout (rule §5: "15s HTTP timeout"). Applied to
/// both establishing the connection and receiving the response.
const Duration kApiTimeout = Duration(seconds: 15);

/// Thin, typed wrapper over a [Dio] instance. Construct with defaults for the
/// app, or inject a [Dio] / [baseUrl] in tests.
class ApiClient {
  final Dio _dio;

  // Token state lives on the client (not in a Riverpod store) so this low-level
  // layer has no dependency on app state — the auth layer pushes a token source
  // down, and the client asks for the latest token when it needs one. Both are
  // UNUSED for now: the local mock auth backend has nothing to authorize against
  // (README rule #3), but the seam is in place for a real backend later.
  AuthTokenProvider? _tokenProvider;
  String? _authToken;

  ApiClient({Dio? dio, String? baseUrl}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl ?? config.apiBaseUrl
      ..connectTimeout = kApiTimeout
      ..receiveTimeout = kApiTimeout
      ..responseType = ResponseType.json
      ..headers[Headers.acceptHeader] = Headers.jsonContentType;

    // Resolve a token fresh on EVERY request (suits short-lived tokens) and, if
    // present, attach `Authorization: Bearer <token>`.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _resolveToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  // ── Auth token ─────────────────────────────────────────────────────────────

  /// Set (or clear, with `null`) a single static bearer token (fallback path).
  void setAuthToken(String? token) => _authToken = token;

  /// Register (or clear, with `null`) a provider that yields a fresh token per
  /// request. Takes precedence over any static token.
  void setAuthTokenProvider(AuthTokenProvider? provider) =>
      _tokenProvider = provider;

  // Prefer the live provider, then the static token. A provider that throws or
  // returns null yields an unauthenticated request rather than a crash.
  Future<String?> _resolveToken() async {
    final provider = _tokenProvider;
    if (provider != null) {
      try {
        return await provider();
      } catch (_) {
        return null;
      }
    }
    return _authToken;
  }

  // ── Verb helpers ─────────────────────────────────────────────────────────────
  //
  // Read verbs take options; write verbs take a body then options. Generic <T>
  // is the shape you EXPECT back on success (after the envelope is unwrapped) —
  // at this layer that is usually decoded JSON (a Map/List); typed models parse
  // at the feature boundary (Module 4+).
  //
  //   final json = await api.get<Map<String, dynamic>>('/api/services');
  //   await api.post('/api/bookings/draft', body: draft);

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
    CancelToken? cancelToken,
  }) =>
      _request<T>('GET', path,
          query: query,
          headers: headers,
          timeout: timeout,
          cancelToken: cancelToken);

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
    CancelToken? cancelToken,
  }) =>
      _request<T>('POST', path,
          body: body,
          query: query,
          headers: headers,
          timeout: timeout,
          cancelToken: cancelToken);

  Future<T> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
    CancelToken? cancelToken,
  }) =>
      _request<T>('PUT', path,
          body: body,
          query: query,
          headers: headers,
          timeout: timeout,
          cancelToken: cancelToken);

  Future<T> patch<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
    CancelToken? cancelToken,
  }) =>
      _request<T>('PATCH', path,
          body: body,
          query: query,
          headers: headers,
          timeout: timeout,
          cancelToken: cancelToken);

  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
    CancelToken? cancelToken,
  }) =>
      _request<T>('DELETE', path,
          body: body,
          query: query,
          headers: headers,
          timeout: timeout,
          cancelToken: cancelToken);

  // ── Core request ───────────────────────────────────────────────────────────

  Future<T> _request<T>(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: _stripNulls(query),
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          // A per-request override; when null, the base 15s applies.
          receiveTimeout: timeout,
        ),
      );
      return _unwrapEnvelope<T>(response.data);
    } on DioException catch (e) {
      // Never leak a raw DioException past this layer — features catch only
      // [ApiException].
      throw ApiException.fromDioException(e);
    }
  }

  /// SUCCESS ENVELOPE: the backend wraps every success payload as `{ data: ... }`
  /// (spec §5). Unwrap it here, once, so features get the inner value —
  /// `get<List>('/api/services')` yields the array, not `{ data: array }`.
  /// An empty body (204 / DELETE) normalises to `null` — dio surfaces it as an
  /// empty string, so we collapse that to `null` to match the RN client. Other
  /// un-enveloped responses (health checks) pass through unchanged.
  static T _unwrapEnvelope<T>(dynamic payload) {
    if (payload is String && payload.isEmpty) return null as T;
    if (payload is Map && payload.containsKey('data')) {
      return payload['data'] as T;
    }
    return payload as T;
  }

  /// Drop `null` query entries so callers can build params conditionally without
  /// `if` noise (mirrors the RN client). Returns null when nothing remains, so
  /// dio appends no `?`.
  static Map<String, dynamic>? _stripNulls(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out.isEmpty ? null : out;
  }
}

/// The single [ApiClient] the whole app reads. Feature code depends on this
/// provider so the client can be overridden with a fake in tests — the idiomatic
/// Flutter replacement for the RN module-level `api` singleton.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
