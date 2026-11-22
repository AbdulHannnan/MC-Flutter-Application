// Test support: skip the cold-start welcome splash.
//
// On a real cold start the router holds the whole app on the animated welcome
// splash until [splashGateProvider] opens (after the animation plays). Tests that
// assert routing / feature behaviour aren't testing that animation and shouldn't
// wait it out — add [skipWelcomeSplash] to a ProviderScope's `overrides` and the
// gate starts open, so the app lands straight on its target screen.

import 'package:microcare/src/app/screens/splash_screen.dart';

class _OpenSplashGate extends SplashGate {
  @override
  bool build() => true; // welcome already played
}

/// Drop into a test ProviderScope's `overrides` to bypass the welcome splash.
final skipWelcomeSplash = splashGateProvider.overrideWith(_OpenSplashGate.new);
