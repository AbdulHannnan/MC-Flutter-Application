// The local mock auth backend, driven against an in-memory shared_preferences
// mock (SharedPreferences.setMockInitialValues). Covers signup/persistence, the
// generic sign-in failure, duplicate-email and unknown-email errors, reset, and
// session restore/sign-out.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

MockAuthApi _api() => MockAuthApi(latency: Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('signUp creates a user, sets a session, and splits the name', () async {
    final api = _api();
    final user = await api.signUp(
      fullName: 'Jane Doe',
      email: 'Jane@Example.com',
      password: 'supersecret',
    );

    expect(user.email, 'jane@example.com'); // normalised to lowercase
    expect(user.firstName, 'Jane');
    expect(user.lastName, 'Doe');
    expect(user.fullName, 'Jane Doe');
    expect(user.imageUrl, isNotEmpty);

    // The session persists — a fresh api instance restores the same user.
    final restored = await _api().getCurrentUser();
    expect(restored?.id, user.id);
  });

  test('signUp rejects a duplicate email', () async {
    final api = _api();
    await api.signUp(
        fullName: 'Jane', email: 'jane@example.com', password: 'supersecret');

    expect(
      () => api.signUp(
          fullName: 'Other', email: 'JANE@example.com', password: 'whatever12'),
      throwsA(isA<AuthError>()),
    );
  });

  test('signIn succeeds with the right password, fails generically otherwise',
      () async {
    final api = _api();
    await api.signUp(
        fullName: 'Jane', email: 'jane@example.com', password: 'supersecret');
    await api.signOut();

    final user =
        await api.signIn(email: 'jane@example.com', password: 'supersecret');
    expect(user.email, 'jane@example.com');

    // Wrong password and unknown email both raise the SAME generic error.
    await expectLater(
      api.signIn(email: 'jane@example.com', password: 'wrong'),
      throwsA(isA<AuthError>().having(
          (e) => e.message, 'message', 'Invalid email or password.')),
    );
    await expectLater(
      api.signIn(email: 'nobody@example.com', password: 'supersecret'),
      throwsA(isA<AuthError>().having(
          (e) => e.message, 'message', 'Invalid email or password.')),
    );
  });

  test('resetPassword changes the password and signs in; unknown email throws',
      () async {
    final api = _api();
    await api.signUp(
        fullName: 'Jane', email: 'jane@example.com', password: 'oldpassword');

    final user = await api.resetPassword(
        email: 'jane@example.com', password: 'newpassword');
    expect(user.email, 'jane@example.com');

    // Old password no longer works; new one does.
    await expectLater(
      api.signIn(email: 'jane@example.com', password: 'oldpassword'),
      throwsA(isA<AuthError>()),
    );
    expect(
      (await api.signIn(email: 'jane@example.com', password: 'newpassword'))
          .email,
      'jane@example.com',
    );

    expect(
      () => api.resetPassword(email: 'ghost@example.com', password: 'whatever12'),
      throwsA(isA<AuthError>()),
    );
  });

  test('signOut clears the session but keeps the user', () async {
    final api = _api();
    await api.signUp(
        fullName: 'Jane', email: 'jane@example.com', password: 'supersecret');

    await api.signOut();
    expect(await api.getCurrentUser(), isNull);

    // The account still exists — can sign back in.
    final user =
        await api.signIn(email: 'jane@example.com', password: 'supersecret');
    expect(user.email, 'jane@example.com');
  });
}
