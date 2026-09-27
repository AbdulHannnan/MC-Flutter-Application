// lib/src/features/auth/screens/login_screen.dart — the login form UI + logic.
// Dart port of the RN `LoginScreen`.
//
// Validates on submit, calls the SessionController against the mock backend, and on
// success the session flips to signedIn — the app gate (boot screen today, real
// route guard in Module 8) reveals the protected app, so there's no explicit
// navigation here. Wrong credentials come back as a single generic banner message.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_validation.dart';
import '../mock_auth_api.dart';
import '../session_controller.dart';
import '../widgets/auth_shell.dart';
import '../widgets/form_error_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _showPassword = false;
  bool _submitting = false;
  String? _formError;
  LoginErrors _errors = const LoginErrors();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final errors = validateLogin(email: _email.text, password: _password.text);
    setState(() {
      _errors = errors;
      _formError = null;
    });
    if (errors.hasErrors) return;

    setState(() => _submitting = true);
    try {
      await ref.read(sessionProvider.notifier).signIn(
            email: _email.text,
            password: _password.text,
          );
      // Success: the session flips to signedIn and the gate swaps the screen.
    } on AuthError catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      children: [
        const AppText('Welcome back', variant: AppTextVariant.h2),
        const SizedBox(height: AppSpacing.xs),
        const AppText('Log in to manage your bookings.',
            color: AppTextColor.muted),
        const SizedBox(height: AppSpacing.xl),

        if (_formError != null) ...[
          FormErrorBanner(message: _formError!),
          const SizedBox(height: AppSpacing.md),
        ],

        AppTextField(
          label: 'Email',
          hintText: 'you@example.com',
          controller: _email,
          errorText: _errors.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Password',
          hintText: 'Your password',
          controller: _password,
          errorText: _errors.password,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: AppSpacing.sm),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AuthLink(
              _showPassword ? 'Hide password' : 'Show password',
              onTap: () => setState(() => _showPassword = !_showPassword),
            ),
            AuthLink(
              'Forgot password?',
              color: AppTextColor.muted,
              onTap: () => context.push(AppRoutes.forgotPassword),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: 'Log in',
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: _submitting,
          onPressed: _handleLogin,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const AppText("Don't have an account? ",
                color: AppTextColor.muted),
            AuthLink('Sign up', onTap: () => context.go(AppRoutes.signUp)),
          ],
        ),
      ],
    );
  }
}
