// lib/src/features/technician/screens/technician_login_screen.dart — the
// TECHNICIAN login form (username + password → real backend JWT).
//
// Separate entry from the customer login: technicians have fixed credentials
// created by the CRM/owner (no signup, no forgot-password here). On success the
// session flips to signed-in and the router reveals the staff area — no explicit
// navigation. Bad credentials come back as a single banner message from the
// backend (a generic "Invalid username or password."). Reuses the app's auth
// design system (AuthShell + AppTextField + AppButton) so it matches Login.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/widgets/auth_shell.dart';
import '../../auth/widgets/form_error_banner.dart';
import '../technician_session.dart';

class TechnicianLoginScreen extends ConsumerStatefulWidget {
  const TechnicianLoginScreen({super.key});

  @override
  ConsumerState<TechnicianLoginScreen> createState() =>
      _TechnicianLoginScreenState();
}

class _TechnicianLoginScreenState
    extends ConsumerState<TechnicianLoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _showPassword = false;
  bool _submitting = false;
  String? _formError;
  String? _usernameError;
  String? _passwordError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _username.text.trim();
    final password = _password.text;
    setState(() {
      _usernameError = username.isEmpty ? 'Username is required.' : null;
      _passwordError = password.isEmpty ? 'Password is required.' : null;
      _formError = null;
    });
    if (_usernameError != null || _passwordError != null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(technicianSessionProvider.notifier).login(
            username: username,
            password: password,
          );
      // Success: the session flips to signed-in and the guard swaps the screen.
    } on ApiException catch (e) {
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
        const AppText('Technician sign in', variant: AppTextVariant.h2),
        const SizedBox(height: AppSpacing.xs),
        const AppText('Log in with the credentials provided to you.',
            color: AppTextColor.muted),
        const SizedBox(height: AppSpacing.xl),

        if (_formError != null) ...[
          FormErrorBanner(message: _formError!),
          const SizedBox(height: AppSpacing.md),
        ],

        AppTextField(
          label: 'Username',
          hintText: 'your username',
          controller: _username,
          errorText: _usernameError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Password',
          hintText: 'Your password',
          controller: _password,
          errorText: _passwordError,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: AuthLink(
            _showPassword ? 'Hide password' : 'Show password',
            onTap: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        AppButton(
          label: 'Sign in',
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
            const AppText('Are you a customer? ', color: AppTextColor.muted),
            AuthLink('Customer login', onTap: () => context.go(AppRoutes.signIn)),
          ],
        ),
      ],
    );
  }
}
