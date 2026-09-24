// Microcare — Flutter rebuild of the React Native (Expo) customer booking app.
//
// Entry point. Wraps the app in a Riverpod `ProviderScope` so any provider
// (state stores, API layers, catalog cache) is reachable from anywhere in the
// tree — the idiomatic Flutter equivalent of the RN app's zustand stores +
// react-query providers mounted at the root.
//
// Module 1 scope: this only boots to a placeholder screen to prove the project
// builds and runs in Chrome. Theming (Module 5), config (Module 2), the HTTP
// client (Module 3), models (Module 4), and real screens land in later modules.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
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
              'Module 1 ✓  Project scaffolded',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
