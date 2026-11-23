// Microcare — Flutter rebuild of the React Native (Expo) customer booking app.
//
// Entry point. Wraps the app in a Riverpod `ProviderScope` so any provider (state
// stores, API layers, catalog cache, the router) is reachable from anywhere in the
// tree — the idiomatic Flutter equivalent of the RN app's zustand stores +
// react-query providers mounted at the root.
//
// Module 8 scope: NAVIGATION & ROUTE GUARDS. The app now renders through a
// `MaterialApp.router` driven by [routerProvider] (go_router) — the analog of the
// RN app's expo-router `_layout.tsx`. The router owns the two route sets (auth vs
// protected), the cold-start splash, the auth redirect guard + deep-link bounce,
// and the booking-flow guard seam. See src/app/app_router.dart.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app_router.dart';
import 'src/config/app_config.dart';
import 'src/core/network/supabase_client.dart';
import 'src/core/theme/theme.dart';

Future<void> main() async {
  // Binding must be ready before the async Supabase init below runs ahead of
  // runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Bring up the Supabase client (customer auth / catalog / Edge Functions)
  // before the app renders. A no-op when Supabase isn't configured, so the app
  // still boots on the Express/mock fallbacks — nothing is re-pointed at Supabase
  // in this foundation module.
  final supabaseReady = await initSupabase();

  // Log the resolved config once at startup — a fast way to confirm which
  // backend(s) and flags this build actually loaded.
  if (kDebugMode) {
    debugPrint('[config] resolved:\n${config.describe()}');
    debugPrint('[supabase] initialised: $supabaseReady'
        '${config.isSupabaseConfigured ? '' : ' (not configured — add '
            'SUPABASE_URL + SUPABASE_ANON_KEY to config/dev.json)'}');
  }
  runApp(const ProviderScope(child: MicrocareApp()));
}

/// Root application widget. A single `MaterialApp.router` — the RN app is a
/// stack-based navigator (no tabs, no drawer); go_router provides the stack and the
/// route guards. All screens and the auth boundary live under [routerProvider].
class MicrocareApp extends ConsumerWidget {
  const MicrocareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Microcare',
      debugShowCheckedModeBanner: false,
      // The Module 5 design system, extracted from the RN src/constants/*.
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
