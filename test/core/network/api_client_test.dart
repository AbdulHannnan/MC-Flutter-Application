// Tests the HTTP client's behaviour without a real network, by injecting a Dio
// whose adapter returns canned responses. Covers: the `{ data }` success-envelope
// unwrap, un-enveloped/empty passthrough, query building (null-stripping), server
// error parsing (`{ error }` / 422 `{ error, details }`), and the dio→ApiException
// mapping for timeouts and network failures.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/core/network/api_exception.dart';

/// A fake dio adapter: routes each request to a supplied handler that returns a
/// canned [ResponseBody] (or throws to simulate a transport failure).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  /// The last request the client actually sent — inspected by tests.
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ApiClient _clientWith(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(dio: dio, baseUrl: 'http://localhost:5050');
}

void main() {
  group('success envelope', () {
    test('unwraps { data: ... } to the inner value', () async {
      final adapter = _FakeAdapter((_) => _json({
            'data': [
              {'id': 's1'},
              {'id': 's2'},
            ],
          }));
      final client = _clientWith(adapter);

      final result = await client.get<List<dynamic>>('/api/services');

      expect(result, hasLength(2));
      expect((result.first as Map)['id'], 's1');
    });

    test('passes an un-enveloped body through unchanged', () async {
      final adapter = _FakeAdapter((_) => _json({'ok': true}));
      final client = _clientWith(adapter);

      final result = await client.get<Map<String, dynamic>>('/health');

      expect(result['ok'], true);
    });

    test('a 204 / empty body yields null', () async {
      final adapter = _FakeAdapter(
        (_) => ResponseBody.fromString('', 204),
      );
      final client = _clientWith(adapter);

      final result = await client.delete<dynamic>('/api/thing/1');

      expect(result, isNull);
    });
  });

  group('requests', () {
    test('POST sends the JSON body and drops null query params', () async {
      final adapter = _FakeAdapter((_) => _json({'data': {'id': 'b1'}}));
      final client = _clientWith(adapter);

      await client.post<Map<String, dynamic>>(
        '/api/bookings/draft',
        body: {'source': 'app'},
        query: {'keep': 'yes', 'drop': null},
      );

      final sent = adapter.lastRequest!;
      expect(sent.method, 'POST');
      expect(sent.data, {'source': 'app'});
      expect(sent.queryParameters, {'keep': 'yes'});
      expect(sent.queryParameters.containsKey('drop'), isFalse);
    });
  });

  group('error parsing', () {
    test('reads the server { error } message and status', () async {
      final adapter = _FakeAdapter(
        (_) => _json({'error': 'Service not found'}, status: 404),
      );
      final client = _clientWith(adapter);

      expect(
        () => client.get<dynamic>('/api/services/nope'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.message, 'message', 'Service not found')
              .having((e) => e.isTimeout, 'isTimeout', false)
              .having((e) => e.isNetwork, 'isNetwork', false),
        ),
      );
    });

    test('keeps the raw body (with details) on a 422', () async {
      final adapter = _FakeAdapter(
        (_) => _json(
          {
            'error': 'Validation failed',
            'details': [
              {'path': 'email', 'message': 'required'}
            ],
          },
          status: 422,
        ),
      );
      final client = _clientWith(adapter);

      try {
        await client.post<dynamic>('/api/bookings/draft', body: {});
        fail('expected an ApiException');
      } on ApiException catch (e) {
        expect(e.status, 422);
        expect(e.message, 'Validation failed');
        expect((e.data as Map)['details'], isA<List<dynamic>>());
      }
    });
  });

  group('dio failure mapping', () {
    RequestOptions options() => RequestOptions(path: '/x');

    test('timeouts map to isTimeout', () {
      final e = ApiException.fromDioException(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      expect(e.isTimeout, isTrue);
      expect(e.isNetwork, isFalse);
      expect(e.status, 0);
    });

    test('connection errors map to isNetwork', () {
      final e = ApiException.fromDioException(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(e.isNetwork, isTrue);
      expect(e.isTimeout, isFalse);
    });

    test('cancellation is neither timeout nor network', () {
      final e = ApiException.fromDioException(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.cancel,
        ),
      );
      expect(e.isTimeout, isFalse);
      expect(e.isNetwork, isFalse);
    });
  });
}
