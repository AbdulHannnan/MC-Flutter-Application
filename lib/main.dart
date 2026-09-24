// Microcare — Flutter rebuild of the React Native (Expo) customer booking app.
//
// Entry point. Wraps the app in a Riverpod `ProviderScope` so any provider
// (state stores, API layers, catalog cache) is reachable from anywhere in the
// tree — the idiomatic Flutter equivalent of the RN app's zustand stores +
// react-query providers mounted at the root.
//
// Module 2 scope: typed config (API base URL + the four mock/live flags) is now
// loaded from `--dart-define-from-file` and surfaced on the boot screen to prove
// the running build reads it. Theming (Module 5), the HTTP client (Module 3),
// models (Module 4), and real screens land in later modules.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/config/app_config.dart';

void main() {
  // Log the resolved config once at startup — a fast way to confirm which
  // API URL and flags this build actually loaded.
  if (kDebugMode) {
    debugPrint('[config] resolved:\n${config.describe()}');
    if (!isApiBaseUrlValid) {
      debugPrint('[config] WARNING: API_BASE_URL is empty. '
          'Pass --dart-define-from-file=config/dev.json');
    }
  }
  runApp(const ProviderScope(child: MicrocareApp()));
}

/// Root application widget. A single `MaterialApp` — the RN app is a
/// stack-based navigator (no tabs, no drawer); the real routing arrives in
/// Module 8. For now it just shows the placeholder home.
class MicrocareApp extends StatelessWidget {
  const MicrocareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microcare',
      debugShowCheckedModeBanner: false,
      // Placeholder theme; the real design system (colours, typography,
      // spacing extracted from the RN src/constants/*) is Module 5.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A84FF)),
        useMaterial3: true,
      ),
      home: const _PlaceholderHomeScreen(),
    );
  }
}

/// Temporary landing screen for Module 1. Replaced by the real Home /
/// dashboard in Module 9.
class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.ac_unit,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Microcare',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('AC servicing & booking — Dubai'),
            const SizedBox(height: 24),
            const Text(
              'Module 2 ✓  Config & environment',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Proof that the build read its config. Removed once real screens land.
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Loaded config',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    config.describe(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
