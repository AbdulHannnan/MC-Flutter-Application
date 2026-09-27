// lib/src/core/network/api_exception.dart
//
// The one error type every API call can throw — the Dart analog of the RN app's
// `ApiError` class (src/lib/api.ts). Catching an [ApiException] lets UI code tell
// *how* a call failed and react accordingly, without inspecting dio internals:
//
//   - [status]    : HTTP status (0 when the request never got a response —
//                   offline, DNS failure, or a timeout).
//   - [data]      : the parsed error body the server sent, if any. Our backend's
//                   central error handler returns `{ error: "..." }` (and
//                   `{ error, details }` for validation — 422); [data] keeps the
//                   whole body so callers can read `details`.
//   - [isTimeout] / [isNetwork] : quick flags so screens can say "Request timed
//                   out" or "You appear to be offline" without branching on
//                   [status].
//
// Feature code never sees a `DioException`; the API client maps every dio failure
// to one of these via [ApiException.fromDioException].

import 'package:dio/dio.dart';

class ApiException implements Exception {
  /// Human-readable message, safe to surface in the UI.
  final String message;

  /// HTTP status code, or 0 when no response was received (timeout / offline).
  final int status;

  /// The parsed error body from the server, if it sent one. Often a map like
  /// `{ error, details }`; kept raw so callers can read machine-readable fields.
  final Object? data;

  /// The request took longer than the configured timeout.
  final bool isTimeout;

  /// The request never reached the server (offline, DNS, connection refused).
  final bool isNetwork;

  const ApiException(
    this.message, {
    this.status = 0,
    this.data,
    this.isTimeout = false,
    this.isNetwork = false,
  });

  /// Map any [DioException] to a predictable [ApiException]. This is the single
  /// place dio's failure taxonomy is translated into the app's, mirroring the
  /// `catch`/`!response.ok` branches in the RN client.
  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      // A slow or absent network otherwise leaves the request hanging forever.
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          'Request timed out. Please try again.',
          isTimeout: true,
        );

      // The server responded with a 4xx/5xx. Prefer a server-supplied message
      // (`{ error }`, then `{ message }`); fall back to a status-based one. The
      // raw body is kept on [data] so callers can read `details` (422).
      case DioExceptionType.badResponse:
        final response = e.response;
        final payload = response?.data;
        final statusCode = response?.statusCode ?? 0;
        final message = _extractMessage(payload) ??
            'Request failed with status $statusCode';
        return ApiException(message, status: statusCode, data: payload);

      // Caller aborted via a CancelToken (e.g. cancel-on-dispose). Not a network
      // failure — flags stay false so callers can ignore it if they chose to cancel.
      case DioExceptionType.cancel:
        return const ApiException('Request was cancelled.');

      // No response was ever received.
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const ApiException(
          'Network request failed. Check your connection.',
          isNetwork: true,
        );
    }
  }

  /// Pull a message out of a server error body, tolerating both our backend's
  /// `{ error }` shape and a generic `{ message }`.
  static String? _extractMessage(Object? payload) {
    if (payload is Map) {
      final error = payload['error'];
      if (error is String && error.isNotEmpty) return error;
      final message = payload['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
  }

  @override
  String toString() => 'ApiException($status): $message';
}
