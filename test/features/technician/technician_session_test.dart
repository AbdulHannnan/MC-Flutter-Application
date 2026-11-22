// The TechnicianSessionController: login persists the token + flips to signed-in;
// bad credentials surface the error and leave the session signed-out; a stored
// token restores the session on build; logout clears it. The backend API is faked
// (no network) and the token store is in-memory (no keystore).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/network/api_client.dart';
import 'package:microcare/src/core/network/api_exception.dart';
import 'package:microcare/src/features/technician/data/technician.dart';
import 'package:microcare/src/features/technician/data/technician_api.dart';
import 'package:microcare/src/features/technician/data/technician_token_store.dart';
import 'package:microcare/src/features/technician/technician_session.dart';

import '../../support/welcome_gate.dart'; // InMemoryTechnicianTokenStore

const _sami = Technician(
  id: 'tech_1',
  code: 'MC0001TEC',
  name: 'Sami Tech',
  username: 'sami',
  phone: null,
);

/// A fake backend API: login succeeds only for the right password.
class _FakeTechApi extends TechnicianApi {
  _FakeTechApi() : super(ApiClient(baseUrl: 'http://test.local'));

  @override
  Future<TechnicianLoginResult> login({
    required String username,
    required String password,
  }) async {
    if (username == 'sami' && password == 'correct-horse') {
      return const TechnicianLoginResult(token: 'jwt.sami', technician: _sami);
    }
    throw const ApiException('Invalid username or password.', status: 401);
  }

  @override
  Future<Technician> me() async => _sami;
}

ProviderContainer _container(InMemoryTechnicianTokenStore store) {
  final c = ProviderContainer(overrides: [
    technicianTokenStoreProvider.overrideWithValue(store),
    technicianApiProvider.overrideWithValue(_FakeTechApi()),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('cold start with no token → signed out', () async {
    final c = _container(InMemoryTechnicianTokenStore());
    expect(await c.read(technicianSessionProvider.future), isNull);
  });

  test('login persists the token and flips to signed-in', () async {
    final store = InMemoryTechnicianTokenStore();
    final c = _container(store);
    await c.read(technicianSessionProvider.future); // settle restore

    final tech = await c.read(technicianSessionProvider.notifier).login(
          username: 'sami',
          password: 'correct-horse',
        );

    expect(tech, _sami);
    expect(c.read(technicianSessionProvider).value, _sami);
    expect(store.token, 'jwt.sami'); // token saved securely
  });

  test('bad credentials throw and leave the session signed-out', () async {
    final c = _container(InMemoryTechnicianTokenStore());
    await c.read(technicianSessionProvider.future);

    await expectLater(
      c.read(technicianSessionProvider.notifier).login(
            username: 'sami',
            password: 'wrong',
          ),
      throwsA(isA<ApiException>()),
    );
    expect(c.read(technicianSessionProvider).value, isNull);
  });

  test('a stored token restores the session on build', () async {
    final store =
        InMemoryTechnicianTokenStore(token: 'jwt.sami', technician: _sami);
    final c = _container(store);
    expect(await c.read(technicianSessionProvider.future), _sami);
  });

  test('logout clears the stored token', () async {
    final store =
        InMemoryTechnicianTokenStore(token: 'jwt.sami', technician: _sami);
    final c = _container(store);
    await c.read(technicianSessionProvider.future);

    await c.read(technicianSessionProvider.notifier).logout();

    expect(c.read(technicianSessionProvider).value, isNull);
    expect(store.token, isNull);
  });
}
