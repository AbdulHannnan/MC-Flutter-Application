// The Supabase technician auth path. A fake Dio adapter (no network) asserts the
// request hits the `technician` Edge Function sub-paths with the gateway `apikey`
// header and, when authed, the stored technician JWT as `Authorization: Bearer`;
// and that the {token, technician} / {technician} envelopes parse into our types.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/core/network/api_exception.dart';
import 'package:microcare/src/features/technician/data/supabase_technician_api.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? _,
      Future<void>? _) async {
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

SupabaseTechnicianApi _api(_FakeAdapter adapter, {String? token}) {
  final dio = Dio()..httpClientAdapter = adapter;
  final client =
      ApiClient(dio: dio, baseUrl: 'https://proj.supabase.co/functions/v1')
        ..setAuthTokenProvider(() async => token);
  return SupabaseTechnicianApi(client);
}

const _tech = {
  'id': 'tech_1',
  'code': 'MC0001TEC',
  'name': 'Sami Tech',
  'username': 'sami',
  'phone': null,
};

void main() {
  test('login POSTs to /functions/v1/technician/login with the apikey header', () async {
    final adapter = _FakeAdapter((o) =>
        _json({'data': {'token': 'jwt.sami', 'technician': _tech}}));
    final result = await _api(adapter).login(
      username: 'sami',
      password: 'correct-horse',
    );

    final req = adapter.lastRequest!;
    expect(req.method, 'POST');
    expect(req.uri.toString(),
        'https://proj.supabase.co/functions/v1/technician/login');
    expect(req.headers.containsKey('apikey'), isTrue); // gateway credential
    expect(jsonDecode(jsonEncode(req.data))['username'], 'sami');

    expect(result.token, 'jwt.sami');
    expect(result.technician.id, 'tech_1');
    expect(result.technician.code, 'MC0001TEC');
  });

  test('me GETs /technician/me with apikey + the stored technician JWT bearer', () async {
    final adapter = _FakeAdapter((o) => _json({'data': {'technician': _tech}}));
    final tech = await _api(adapter, token: 'jwt.sami').me();

    final req = adapter.lastRequest!;
    expect(req.method, 'GET');
    expect(req.uri.toString(),
        'https://proj.supabase.co/functions/v1/technician/me');
    expect(req.headers.containsKey('apikey'), isTrue);
    expect(req.headers['Authorization'], 'Bearer jwt.sami'); // custom technician JWT
    expect(tech.username, 'sami');
  });

  test('bad credentials surface as an ApiException (401)', () async {
    final adapter = _FakeAdapter(
        (o) => _json({'error': 'Invalid username or password.'}, status: 401));
    await expectLater(
      _api(adapter).login(username: 'sami', password: 'wrong'),
      throwsA(isA<ApiException>()),
    );
  });

  test('jobs GETs /technician/jobs with apikey + bearer, parses the list', () async {
    final adapter = _FakeAdapter((o) => _json({
          'data': [
            {
              'id': 'bk_1',
              'reference': 'MC-0001AH',
              'jobStatus': 'ASSIGNED',
              'service': {'id': 'svc_1', 'name': 'Split AC'},
            },
          ],
        }));
    final jobs = await _api(adapter, token: 'jwt.sami').jobs();

    final req = adapter.lastRequest!;
    expect(req.method, 'GET');
    expect(req.uri.path, '/functions/v1/technician/jobs');
    expect(req.headers.containsKey('apikey'), isTrue);
    expect(req.headers['Authorization'], 'Bearer jwt.sami');
    expect(jobs, hasLength(1));
    expect(jobs.first.reference, 'MC-0001AH');
  });

  test('jobs passes an optional ?status= filter', () async {
    final adapter = _FakeAdapter((o) => _json({'data': []}));
    await _api(adapter, token: 'jwt.sami').jobs(status: 'ASSIGNED');
    expect(adapter.lastRequest!.uri.queryParameters['status'], 'ASSIGNED');
  });

  test('job GETs /technician/jobs/:id and parses the detail', () async {
    final adapter = _FakeAdapter((o) => _json({
          'data': {
            'id': 'bk_1',
            'jobStatus': 'ACKNOWLEDGED',
            'total': '135.00',
            'service': {'id': 'svc_1', 'name': 'Split AC'},
          },
        }));
    final job = await _api(adapter, token: 'jwt.sami').job('bk_1');

    expect(adapter.lastRequest!.uri.path, '/functions/v1/technician/jobs/bk_1');
    expect(job.id, 'bk_1');
    expect(job.total!.amountMinor, 13500);
  });
}
