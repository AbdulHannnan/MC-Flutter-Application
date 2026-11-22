// Test support for booting the full app: skip the cold-start welcome splash and
// stub the technician secure-token store.
//
// On a real cold start the router holds the whole app on the animated welcome
// splash until [splashGateProvider] opens (after the animation plays), and it
// also waits for the technician session to restore from flutter_secure_storage —
// a plugin that isn't available in the widget-test binding. Tests that assert
// routing / feature behaviour aren't testing either, so they add these overrides:
//   • [skipWelcomeSplash]      — the welcome gate starts open.
//   • [signedOutTechnician]    — an in-memory, empty token store (no keystore,
//                                resolves instantly to "signed out").

import 'package:microcare/src/app/screens/splash_screen.dart';
import 'package:microcare/src/features/technician/technician.dart';

class _OpenSplashGate extends SplashGate {
  @override
  bool build() => true; // welcome already played
}

/// Drop into a test ProviderScope's `overrides` to bypass the welcome splash.
final skipWelcomeSplash = splashGateProvider.overrideWith(_OpenSplashGate.new);

/// An in-memory [TechnicianTokenStore] with no stored token — the technician
/// session restores instantly to signed-out, and no real keystore is touched.
class InMemoryTechnicianTokenStore implements TechnicianTokenStore {
  InMemoryTechnicianTokenStore({this.token, this.technician});
  String? token;
  Technician? technician;

  @override
  Future<String?> readToken() async => token;
  @override
  Future<Technician?> readTechnician() async => technician;
  @override
  Future<void> save({required String token, required Technician technician}) async {
    this.token = token;
    this.technician = technician;
  }

  @override
  Future<void> clear() async {
    token = null;
    technician = null;
  }
}

/// Drop into a test ProviderScope's `overrides` so the technician session boots
/// signed-out without hitting flutter_secure_storage.
final signedOutTechnician =
    technicianTokenStoreProvider.overrideWithValue(InMemoryTechnicianTokenStore());
