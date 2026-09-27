// lib/src/features/auth/widgets/auth_shell.dart — the shared frame for the auth
// screens. Analog of the RN `<Screen scroll>` + centred `KeyboardAvoidingView`
// wrapper the three auth screens each used.
//
// A scrollable, keyboard-safe, vertically-centred column with a comfortable max
// width so the forms don't stretch edge-to-edge on web/tablet. Content only —
// each screen supplies its header, fields and actions.

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// A small tappable inline link styled from the type ramp — the "Sign up",
/// "Forgot password?", "Show password" affordances shared by the auth screens.
class AuthLink extends StatelessWidget {
  final String text;
  final AppTextColor color;
  final VoidCallback onTap;
  const AuthLink(this.text,
      {super.key, this.color = AppTextColor.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AppText(text, variant: AppTextVariant.caption, color: color),
    );
  }
}

class AuthShell extends StatelessWidget {
  final List<Widget> children;
  const AuthShell({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
