// Verifies the post-cutover config resolves to sensible defaults when no
// `--dart-define` is passed (as under a plain `flutter test`). The app targets a
// single backend (Supabase); only the project URL/key + push flag remain.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/config/app_config.dart';

void main() {
  group('config defaults (no --dart-define)', () {
    test('resolves to development with push mocked', () {
      expect(config.appEnv, AppEnv.development);
      expect(config.isDev, isTrue);
      expect(config.isProd, isFalse);
      expect(config.push.mode, PushMode.mock);
      expect(config.isMockPush, isTrue);
    });

    test('supabase is unconfigured by default (no SUPABASE_URL / key)', () {
      expect(config.supabaseUrl, isEmpty);
      expect(config.supabaseAnonKey, isEmpty);
      expect(config.isSupabaseConfigured, isFalse);
    });

    test('describe() lists every key and never prints the anon key', () {
      final text = config.describe();
      for (final key in const [
        'appEnv',
        'supabaseUrl',
        'supabaseKey',
        'supabaseReady',
        'push.mode',
      ]) {
        expect(text, contains(key));
      }
      // The key value is only ever reported as present/absent, never printed.
      expect(text, contains('supabaseKey   : (unset)'));
    });
  });

  // The cutover invariant: once Supabase IS configured (URL + key) the app is
  // ready to talk to it. Runs meaningfully under
  // `flutter test --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`;
  // a no-op in the plain suite where Supabase is unset.
  test('configured ⇒ Supabase is ready', () {
    if (config.supabaseUrl.isEmpty) return; // skipped when unconfigured
    expect(config.isSupabaseConfigured, isTrue);
  });
}
