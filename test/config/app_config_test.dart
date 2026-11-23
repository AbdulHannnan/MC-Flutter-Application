// Verifies Module 2 config resolves to the README defaults when no
// `--dart-define` is passed (as under a plain `flutter test`), and that the
// convenience flags agree with the resolved modes.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/config/app_config.dart';

void main() {
  group('config defaults (no --dart-define)', () {
    test('resolves to the README flag table', () {
      expect(config.appEnv, AppEnv.development);
      expect(config.apiBaseUrl, 'http://localhost:5050');
      expect(config.catalog.mode, DataMode.live);
      expect(config.bookings.mode, DataMode.live);
      expect(config.payments.mode, PaymentsMode.mock);
      expect(config.payments.ngeniusEnv, NgeniusEnv.sandbox);
      expect(config.push.mode, PushMode.mock);
    });

    test('convenience flags agree with the resolved modes', () {
      expect(config.isDev, isTrue);
      expect(config.isProd, isFalse);
      expect(config.isMockCatalog, isFalse); // live
      expect(config.isMockBookings, isFalse); // live
      expect(config.isMockPayments, isTrue); // mock
      expect(config.isMockPush, isTrue); // mock
    });

    test('api base url is present', () {
      expect(isApiBaseUrlValid, isTrue);
    });

    test('supabase is unconfigured by default (no --dart-define)', () {
      // With no SUPABASE_URL / SUPABASE_ANON_KEY passed, the app stays on the
      // Express/mock fallbacks and never initialises Supabase.
      expect(config.supabaseUrl, isEmpty);
      expect(config.supabaseAnonKey, isEmpty);
      expect(config.isSupabaseConfigured, isFalse);
    });

    test('describe() lists every key and never prints the anon key', () {
      final text = config.describe();
      for (final key in const [
        'appEnv',
        'apiBaseUrl',
        'supabaseUrl',
        'supabaseKey',
        'supabaseReady',
        'catalog.mode',
        'bookings.mode',
        'payments.mode',
        'ngeniusEnv',
        'push.mode',
      ]) {
        expect(text, contains(key));
      }
      // The key value is only ever reported as present/absent, never printed.
      expect(text, contains('supabaseKey   : (unset)'));
    });
  });
}
