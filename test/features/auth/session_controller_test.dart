// The SessionController: cold-start restore, and the sign-in / sign-out / sign-up
// transitions that drive the app-wide session AsyncValue and its SessionX helpers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/features/auth/mock_auth_api.dart';
import 'package:microcare/src/features/auth/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      mockAuthApiProvider
          .overrideWithValue(MockAuthApi(latency: Duration.zero)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restores to signed-out when no session is saved', () async {
    final container = _container();

    // Initially restoring, then resolves to signed-out (data == null).
    expect(container.read(sessionProvider).isRestoring, isTrue);
    final user = await container.read(sessionProvider.future);
    expect(user, isNull);
    expect(container.read(sessionProvider).isSignedIn, isFalse);
  });

  test('signUp flips the session to signed-in', () async {
    final container = _container();
    await container.read(sessionProvider.future); // finish restore

    await container.read(sessionProvider.notifier).signUp(
          fullName: 'Jane Doe',
          email: 'jane@example.com',
          password: 'supersecret',
        );

    final session = container.read(sessionProvider);
    expect(session.isSignedIn, isTrue);
    expect(session.user?.email, 'jane@example.com');
  });

  test('signIn then signOut toggles the session', () async {
    final container = _container();
    await container.read(sessionProvider.future);

    final notifier = container.read(sessionProvider.notifier);
    await notifier.signUp(
        fullName: 'Jane', email: 'jane@example.com', password: 'supersecret');
    await notifier.signOut();
    expect(container.read(sessionProvider).isSignedIn, isFalse);

    await notifier.signIn(email: 'jane@example.com', password: 'supersecret');
    expect(container.read(sessionProvider).isSignedIn, isTrue);
  });

  test('a wrong-credentials signIn throws and leaves the session unchanged',
      () async {
    final container = _container();
    await container.read(sessionProvider.future);

    await expectLater(
      container.read(sessionProvider.notifier).signIn(
            email: 'nobody@example.com',
            password: 'whatever12',
          ),
      throwsA(isA<AuthError>()),
    );
    expect(container.read(sessionProvider).isSignedIn, isFalse);
  });
}
