// lib/src/app/screens/splash_screen.dart — the cold-start splash.
//
// Shown only while the saved session is being restored (the router redirects every
// route here until `sessionProvider` resolves). A returning user therefore never
// flashes the login screen before being bounced to Home. Deliberately minimal — a
// branded splash is a later polish concern.

import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ac_unit, size: 56, color: AppColors.primary),
            SizedBox(height: AppSpacing.lg),
            CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
